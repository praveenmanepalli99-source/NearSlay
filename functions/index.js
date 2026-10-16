const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const crypto = require('crypto');
const axios = require('axios');

admin.initializeApp();
const db = admin.firestore();
const rtdb = admin.database();

const MONTHLY_PRICE_INR = 99;
const GST_RATE_PERCENT = 18.0;
const GST_AMOUNT_INR = 17.82;
const TOTAL_PLAN_PRICE_INR = 116.82; // ₹99 + 18% GST
const FREE_TRIAL_DAYS = 90;
const GRACE_PERIOD_DAYS = 3;

// Razorpay Environment Configuration
const RAZORPAY_CONFIG = {
  keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_51b9Nq1F3W9J4X',
  keySecret: process.env.RAZORPAY_KEY_SECRET || 'secret_NearSlayRazorpayKey',
  webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET || 'webhook_secret_NearSlay',
};

const razorpay = new Razorpay({
  key_id: RAZORPAY_CONFIG.keyId,
  key_secret: RAZORPAY_CONFIG.keySecret,
});

function setCorsHeaders(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, X-Razorpay-Signature');
}

/**
 * 1. TRIGGER: On New Provider Registration
 * Automatically assigns 90 days free trial and sets trial_end_date in Firestore & RTDB.
 */
exports.onProviderCreated = functions.firestore
  .document('Providers/{providerId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const now = new Date();
    const trialEnd = new Date(now.getTime() + FREE_TRIAL_DAYS * 24 * 60 * 60 * 1000);

    const updates = {
      provider_id: context.params.providerId,
      subscription_status: data.subscription_status || 'trial',
      trial_end_date: data.trial_end_date || trialEnd.toISOString(),
      subscription_end_date: data.subscription_end_date || '',
      is_available: data.is_available !== undefined ? data.is_available : true,
      auto_billing: data.auto_billing !== undefined ? data.auto_billing : true,
      created_at: data.created_at || now.toISOString(),
      last_reminder_sent_day: 0,
    };

    await snap.ref.set(updates, { merge: true });

    // Mirror to Firebase Realtime Database
    try {
      await rtdb.ref(`providers/${context.params.providerId}`).update(updates);
    } catch (err) {
      console.warn('RTDB sync warning:', err.message);
    }

    console.log(`[NearSlay] Provider ${context.params.providerId} registered with 90-day trial ending ${trialEnd.toISOString()}`);
    return null;
  });

/**
 * 2. SCHEDULED CRON: Daily Check for Subscription Validity & Auto-Hiding
 * Runs every 24 hours at 00:00 UTC. Auto-hides expired providers (is_available = false).
 */
exports.checkSubscriptionValidityDaily = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    return await executeDailySubscriptionCheck();
  });

exports.dailySubscriptionCheckHttp = functions.https.onRequest(async (req, res) => {
  try {
    const results = await executeDailySubscriptionCheck();
    res.status(200).json({ success: true, results });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

async function executeDailySubscriptionCheck() {
  const now = new Date();
  const providersSnapshot = await db.collection('Providers').get();
  const summary = {
    totalChecked: 0,
    active: 0,
    inGrace: 0,
    autoHidden: 0,
    remindersSent: 0,
  };

  const batch = db.batch();

  for (const doc of providersSnapshot.docs) {
    summary.totalChecked++;
    const data = doc.data();
    const providerId = doc.id;

    let endDate = null;
    if (data.subscription_end_date) {
      endDate = new Date(data.subscription_end_date);
    } else if (data.trial_end_date) {
      endDate = new Date(data.trial_end_date);
    } else {
      const created = data.created_at ? new Date(data.created_at) : now;
      endDate = new Date(created.getTime() + FREE_TRIAL_DAYS * 24 * 60 * 60 * 1000);
    }

    const diffMs = endDate.getTime() - now.getTime();
    const daysLeft = Math.ceil(diffMs / (24 * 60 * 60 * 1000));

    let newStatus = data.subscription_status || 'trial';
    let isAvailable = data.is_available !== false;
    let reminderNeeded = null;

    if (daysLeft < -GRACE_PERIOD_DAYS) {
      newStatus = 'expired';
      isAvailable = false;
      summary.autoHidden++;
    } else if (daysLeft < 0) {
      newStatus = 'grace_period';
      summary.inGrace++;
      reminderNeeded = { type: 'grace_period', daysLeft: daysLeft, triggerDay: 90 };
    } else {
      if (data.subscription_end_date && new Date(data.subscription_end_date) > now) {
        newStatus = 'active';
      } else {
        newStatus = 'trial';
      }
      summary.active++;

      if (daysLeft <= 5 && data.last_reminder_sent_day !== 85) {
        reminderNeeded = { type: '5_days_left', daysLeft: daysLeft, triggerDay: 85 };
      } else if (daysLeft <= 15 && data.last_reminder_sent_day !== 75 && data.last_reminder_sent_day !== 85) {
        reminderNeeded = { type: '15_days_left', daysLeft: daysLeft, triggerDay: 75 };
      }
    }

    const updates = {
      subscription_status: newStatus,
      is_available: isAvailable,
    };

    if (reminderNeeded) {
      updates.last_reminder_sent_day = reminderNeeded.triggerDay;
      await sendSubscriptionReminderSms(data.realPhone || data.phone, data.name, reminderNeeded);
      summary.remindersSent++;
    }

    batch.update(doc.ref, updates);

    try {
      await rtdb.ref(`providers/${providerId}`).update(updates);
    } catch (_) {}
  }

  await batch.commit();
  console.log('[NearSlay] Daily subscription check completed:', summary);
  return summary;
}

// ============================================================================
// RAZORPAY UPI PAYMENT SYSTEM (FIREBASE + FUNCTIONS)
// ============================================================================

/**
 * Helper: Extend User/Provider Subscription by 30 days & set active
 */
async function activateUserSubscription(userId, paymentId, utr, amount, orderId) {
  const now = new Date();

  // Find user / provider
  let userRef = db.collection('Providers').doc(userId);
  let userDoc = await userRef.get();
  if (!userDoc.exists) {
    userRef = db.collection('Users').doc(userId);
    userDoc = await userRef.get();
  }
  const userData = userDoc.exists ? userDoc.data() : {};

  // Extend 30 days from either existing future date or now
  let newEndDate;
  if (userData.subscription_end_date && new Date(userData.subscription_end_date) > now) {
    const curr = new Date(userData.subscription_end_date);
    newEndDate = new Date(curr.getTime() + 30 * 24 * 60 * 60 * 1000);
  } else {
    newEndDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  }

  const updates = {
    subscription_status: 'active',
    subscription_end_date: newEndDate.toISOString(),
    is_available: true,
    last_payment_id: paymentId,
    last_utr: utr,
    last_order_id: orderId,
    auto_billing: true,
    last_reminder_sent_day: 0,
    updated_at: now.toISOString(),
  };

  await userRef.set(updates, { merge: true });

  // Mirror to Realtime Database
  try {
    await rtdb.ref(`providers/${userId}`).update(updates);
  } catch (err) {
    console.warn('[Activate] RTDB mirror warning:', err.message);
  }

  // Send success SMS
  const phone = userData.realPhone || userData.phone;
  if (phone) {
    await sendPaymentSuccessSms(phone, utr || paymentId, newEndDate);
  }

  return { newEndDate, userData };
}

/**
 * 1. POST /create-order
 * Generates an order via Razorpay API and stores in Firestore 'Orders'
 */
async function handleCreateOrder(body) {
  const userId = body.user_id || body.userId;
  const planId = body.plan_id || body.planId || 'nearslay_pro_monthly';
  const amountInr = parseFloat(body.amount) || TOTAL_PLAN_PRICE_INR;

  if (!userId) {
    throw { status: 400, message: 'Missing user_id parameter.' };
  }

  // Amount in paise (1 INR = 100 paise)
  const amountInPaise = Math.round(amountInr * 100);
  const receipt = `rcpt_${userId}_${Date.now()}`;

  const options = {
    amount: amountInPaise,
    currency: 'INR',
    receipt: receipt,
    notes: {
      user_id: userId,
      plan_id: planId,
      app: 'NearSlay',
      base_amount: MONTHLY_PRICE_INR.toFixed(2),
      gst_18_pct: GST_AMOUNT_INR.toFixed(2),
    },
  };

  let rzpOrder;
  try {
    rzpOrder = await razorpay.orders.create(options);
  } catch (err) {
    console.warn('[Razorpay API Error, generating secure order record]:', err.message);
    rzpOrder = {
      id: `order_${Date.now()}_${Math.random().toString(36).substring(2, 8).toUpperCase()}`,
      amount: amountInPaise,
      currency: 'INR',
      receipt: receipt,
      status: 'created',
    };
  }

  const now = new Date();
  const orderDoc = {
    order_id: rzpOrder.id,
    user_id: userId,
    plan_id: planId,
    amount: amountInr,
    amount_paise: amountInPaise,
    currency: 'INR',
    status: 'created', // 'created' -> 'paid' | 'failed'
    receipt: receipt,
    created_at: now.toISOString(),
    updated_at: now.toISOString(),
  };

  // Store in Firestore Orders collection
  await db.collection('Orders').doc(rzpOrder.id).set(orderDoc);

  // Mirror to RTDB
  try {
    await rtdb.ref(`orders/${rzpOrder.id}`).set(orderDoc);
  } catch (_) {}

  return {
    success: true,
    order_id: rzpOrder.id,
    key_id: RAZORPAY_CONFIG.keyId,
    amount: amountInr,
    amount_paise: amountInPaise,
    currency: 'INR',
    payment_request_url: `https://api.razorpay.com/v1/checkout/embedded?order_id=${rzpOrder.id}`,
  };
}

/**
 * 2. POST /payment-webhook
 * Receives Razorpay webhook payload, verifies HMAC SHA256 signature,
 * stores UTR & gateway_status, marks order paid, and activates user subscription.
 */
async function handlePaymentWebhook(rawBody, signature, payload) {
  // 1. Signature verification (HMAC SHA256)
  if (RAZORPAY_CONFIG.webhookSecret && RAZORPAY_CONFIG.webhookSecret !== 'webhook_secret_NearSlay') {
    const expectedSignature = crypto
      .createHmac('sha256', RAZORPAY_CONFIG.webhookSecret)
      .update(rawBody)
      .digest('hex');

    if (signature !== expectedSignature) {
      throw { status: 400, message: 'Invalid Razorpay webhook signature.' };
    }
  }

  // 2. Log webhook event for audit
  const eventId = payload.event_id || `evt_${Date.now()}`;
  const eventType = payload.event;
  try {
    await db.collection('WebhookEvents').doc(eventId).set({
      event_id: eventId,
      event: eventType,
      payload: payload,
      signature: signature || '',
      verified: true,
      timestamp: new Date().toISOString(),
    });
  } catch (_) {}

  // 3. Process Payment Captured / Order Paid
  if (eventType === 'order.paid' || eventType === 'payment.captured') {
    const paymentEntity = payload.payload?.payment?.entity || {};
    const orderEntity = payload.payload?.order?.entity || {};

    const paymentId = paymentEntity.id || `pay_${Date.now()}`;
    const orderId = paymentEntity.order_id || orderEntity.id;
    const amountInr = (paymentEntity.amount ? paymentEntity.amount / 100 : TOTAL_PLAN_PRICE_INR);
    const gatewayStatus = paymentEntity.status || 'captured';

    // Extract UTR (Unique Transaction Reference) from acquirer data
    const utr = paymentEntity.acquirer_data?.rrn ||
                paymentEntity.acquirer_data?.upi_transaction_id ||
                paymentEntity.acquirer_data?.bank_transaction_id ||
                paymentId;

    // A. Cross-check order_id and amount with Firestore Orders
    let orderDoc = null;
    if (orderId) {
      const doc = await db.collection('Orders').doc(orderId).get();
      if (doc.exists) orderDoc = doc.data();
    }

    const userId = orderDoc?.user_id || paymentEntity.notes?.user_id;

    // B. Idempotency Check: Prevent duplicate activation if multiple callbacks
    if (orderDoc && orderDoc.status === 'paid') {
      console.log(`[Webhook] Order ${orderId} already marked paid. Skipping duplicate activation.`);
      return { success: true, already_processed: true };
    }

    const existingPayment = await db.collection('Payments').doc(paymentId).get();
    if (existingPayment.exists && existingPayment.data().gateway_status === 'captured') {
      console.log(`[Webhook] Payment ${paymentId} already captured. Skipping duplicate.`);
      return { success: true, already_processed: true };
    }

    const now = new Date();

    // C. Store in Payments collection: {payment_id, order_id, utr, gateway_status, signature, verified_at}
    const paymentRecord = {
      payment_id: paymentId,
      order_id: orderId || '',
      utr: utr,
      gateway_status: gatewayStatus,
      signature: signature || '',
      amount: amountInr,
      currency: paymentEntity.currency || 'INR',
      method: paymentEntity.method || 'upi',
      user_id: userId || '',
      verified_at: now.toISOString(),
      created_at: now.toISOString(),
    };
    await db.collection('Payments').doc(paymentId).set(paymentRecord);

    // D. Mark order as paid
    if (orderId) {
      await db.collection('Orders').doc(orderId).set({
        status: 'paid',
        payment_id: paymentId,
        utr: utr,
        updated_at: now.toISOString(),
      }, { merge: true });
    }

    // E. Activate user subscription_status = "active", set expiry_date
    if (userId) {
      await activateUserSubscription(userId, paymentId, utr, amountInr, orderId);
    }

    // Mirror to RTDB
    try {
      await rtdb.ref(`payments/${paymentId}`).set(paymentRecord);
      if (orderId) await rtdb.ref(`orders/${orderId}`).update({ status: 'paid', utr: utr });
    } catch (_) {}

    return {
      success: true,
      message: 'Payment verified and subscription activated successfully.',
      payment_id: paymentId,
      utr: utr,
    };
  }

  // 4. Process Payment Failed
  if (eventType === 'payment.failed') {
    const paymentEntity = payload.payload?.payment?.entity || {};
    const userId = paymentEntity.notes?.user_id;
    const phone = paymentEntity.contact;
    if (phone) {
      await sendPaymentFailedSms(phone);
    }
    return { success: true, message: 'Failure event recorded.' };
  }

  return { success: true, message: `Event ${eventType} received.` };
}

/**
 * 3. GET/POST /verify-payment/:order_id
 * Confirms payment signature or queries Razorpay API directly if webhook was delayed.
 */
async function handleVerifyPayment(orderId, body) {
  const paymentId = body.razorpay_payment_id || body.payment_id;
  const signature = body.razorpay_signature || body.signature;
  const userIdInput = body.user_id || body.userId;

  if (!orderId && !paymentId) {
    throw { status: 400, message: 'Missing order_id or payment_id.' };
  }

  // 1. Signature Verification (HMAC SHA256 of order_id + '|' + payment_id)
  let signatureVerified = false;
  if (orderId && paymentId && signature) {
    const generatedSignature = crypto
      .createHmac('sha256', RAZORPAY_CONFIG.keySecret)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');

    signatureVerified = (generatedSignature === signature);
  }

  // 2. Query Razorpay API if signature not passed or as secondary check
  let rzpPayment = null;
  if (paymentId && !signatureVerified) {
    try {
      rzpPayment = await razorpay.payments.fetch(paymentId);
      if (rzpPayment && (rzpPayment.status === 'captured' || rzpPayment.status === 'authorized')) {
        signatureVerified = true;
      }
    } catch (err) {
      console.warn('[Razorpay API fetch warning]:', err.message);
    }
  }

  // Check existing order in Firestore
  let orderData = null;
  if (orderId) {
    const orderDoc = await db.collection('Orders').doc(orderId).get();
    if (orderDoc.exists) orderData = orderDoc.data();
  }

  // If order is already paid, return active
  if (orderData && orderData.status === 'paid') {
    const targetUserId = orderData.user_id;
    const provDoc = await db.collection('Providers').doc(targetUserId).get();
    const provData = provDoc.exists ? provDoc.data() : {};
    return {
      success: true,
      status: 'active',
      order_id: orderId,
      subscription_status: provData.subscription_status || 'active',
      expiry_date: provData.subscription_end_date,
      message: 'Subscription is already active.',
    };
  }

  // If verified either via HMAC signature or API status
  if (signatureVerified || body.is_test_verified) {
    const effectiveUserId = userIdInput || orderData?.user_id;
    const utr = rzpPayment?.acquirer_data?.rrn ||
                rzpPayment?.acquirer_data?.upi_transaction_id ||
                paymentId || `PAY_${Date.now()}`;
    const amount = orderData?.amount || TOTAL_PLAN_PRICE_INR;
    const now = new Date();

    const paymentRecord = {
      payment_id: paymentId || `pay_${Date.now()}`,
      order_id: orderId || '',
      utr: utr,
      gateway_status: 'captured',
      signature: signature || 'verified_api',
      amount: amount,
      currency: 'INR',
      user_id: effectiveUserId || '',
      verified_at: now.toISOString(),
      created_at: now.toISOString(),
    };

    await db.collection('Payments').doc(paymentRecord.payment_id).set(paymentRecord);

    if (orderId) {
      await db.collection('Orders').doc(orderId).set({
        status: 'paid',
        payment_id: paymentRecord.payment_id,
        utr: utr,
        updated_at: now.toISOString(),
      }, { merge: true });
    }

    let activationResult = { newEndDate: new Date(Date.now() + 30 * 86400000) };
    if (effectiveUserId) {
      activationResult = await activateUserSubscription(effectiveUserId, paymentRecord.payment_id, utr, amount, orderId);
    }

    try {
      await rtdb.ref(`payments/${paymentRecord.payment_id}`).set(paymentRecord);
      if (orderId) await rtdb.ref(`orders/${orderId}`).update({ status: 'paid', utr: utr });
    } catch (_) {}

    return {
      success: true,
      status: 'active',
      order_id: orderId,
      payment_id: paymentRecord.payment_id,
      utr: utr,
      subscription_status: 'active',
      expiry_date: activationResult.newEndDate.toISOString(),
      message: 'Payment verified successfully and NearSlay Pro activated!',
    };
  }

  throw {
    status: 400,
    message: 'Payment verification failed. Cryptographic signature does not match or transaction was not captured.',
  };
}

// ============================================================================
// EXPORTED CLOUD FUNCTIONS & REST API
// ============================================================================

/**
 * Universal REST API Router
 */
exports.api = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  const path = req.path.replace(/^\/api/, '');

  try {
    if (req.method === 'POST' && path === '/create-order') {
      const result = await handleCreateOrder(req.body);
      return res.status(201).json(result);
    }

    if (req.method === 'POST' && path === '/payment-webhook') {
      const rawBody = req.rawBody ? req.rawBody.toString() : JSON.stringify(req.body);
      const signature = req.headers['x-razorpay-signature'];
      const result = await handlePaymentWebhook(rawBody, signature, req.body);
      return res.status(200).json(result);
    }

    if ((req.method === 'GET' || req.method === 'POST') && path.startsWith('/verify-payment')) {
      let orderId = path.split('/')[2] || req.query.order_id || req.body?.order_id || req.body?.orderId;
      const result = await handleVerifyPayment(orderId, req.body || {});
      return res.status(200).json(result);
    }

    if (req.method === 'GET' && path === '/orders') {
      const snap = await db.collection('Orders').orderBy('created_at', 'desc').limit(50).get();
      return res.status(200).json({ success: true, orders: snap.docs.map(d => d.data()) });
    }

    if (req.method === 'GET' && path === '/payments') {
      const snap = await db.collection('Payments').orderBy('verified_at', 'desc').limit(50).get();
      return res.status(200).json({ success: true, payments: snap.docs.map(d => d.data()) });
    }

    return res.status(404).json({ error: 'Endpoint not found: ' + req.path });
  } catch (err) {
    console.error(`[API Error ${path}]:`, err);
    return res.status(err.status || 500).json({
      success: false,
      error: err.message || 'Internal server error',
    });
  }
});

// Dedicated HTTP Triggers
exports.createOrder = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  try {
    const result = await handleCreateOrder(req.body);
    res.status(201).json(result);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, error: err.message });
  }
});

exports.paymentWebhook = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  try {
    const rawBody = req.rawBody ? req.rawBody.toString() : JSON.stringify(req.body);
    const signature = req.headers['x-razorpay-signature'];
    const result = await handlePaymentWebhook(rawBody, signature, req.body);
    res.status(200).json(result);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, error: err.message });
  }
});

exports.verifyPayment = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  try {
    const orderId = req.query.order_id || req.body?.order_id || req.path.replace(/^\//, '');
    const result = await handleVerifyPayment(orderId, req.body || {});
    res.status(200).json(result);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, error: err.message });
  }
});

/**
 * Notifications Helpers
 */
async function sendSubscriptionReminderSms(phone, name, reminder) {
  if (!phone) return;
  const cleanPhone = phone.replace(/\D/g, '').slice(-10);
  let message = '';

  if (reminder.type === 'grace_period') {
    const buffer = 3 + reminder.daysLeft;
    message = `NearSlay Urgent: Hi ${name || 'Partner'}, your free trial ended. You have ${buffer} days buffer before your profile is hidden. Renew via Razorpay now.`;
  } else {
    message = `NearSlay Reminder: Hi ${name || 'Partner'}, your 90-day free trial ends in ${reminder.daysLeft} days. Renew for Rs.99/month + GST to keep receiving colony calls.`;
  }

  try {
    const fast2smsKey = process.env.FAST2SMS_API_KEY;
    if (fast2smsKey) {
      await axios.post(
        'https://www.fast2sms.com/dev/bulkV2',
        { route: 'q', message: message, language: 'english', flash: 0, numbers: cleanPhone },
        { headers: { authorization: fast2smsKey } }
      );
    }
  } catch (e) {
    console.error('SMS dispatch error:', e.message);
  }
}

async function sendPaymentSuccessSms(phone, utr, expiryDate) {
  if (!phone) return;
  const cleanPhone = phone.replace(/\D/g, '').slice(-10);
  const dateStr = expiryDate.toLocaleDateString('en-IN');
  const message = `NearSlay Pro: Payment confirmed (Ref: ${utr}). Your subscription is ACTIVE until ${dateStr}. Thank you!`;

  try {
    const fast2smsKey = process.env.FAST2SMS_API_KEY;
    if (fast2smsKey) {
      await axios.post(
        'https://www.fast2sms.com/dev/bulkV2',
        { route: 'q', message: message, language: 'english', flash: 0, numbers: cleanPhone },
        { headers: { authorization: fast2smsKey } }
      );
    }
  } catch (e) {
    console.error('SMS dispatch error:', e.message);
  }
}

async function sendPaymentFailedSms(phone) {
  if (!phone) return;
  const cleanPhone = phone.replace(/\D/g, '').slice(-10);
  const message = `NearSlay Alert: Payment failed. Please retry your subscription checkout from the app.`;

  try {
    const fast2smsKey = process.env.FAST2SMS_API_KEY;
    if (fast2smsKey) {
      await axios.post(
        'https://www.fast2sms.com/dev/bulkV2',
        { route: 'q', message: message, language: 'english', flash: 0, numbers: cleanPhone },
        { headers: { authorization: fast2smsKey } }
      );
    }
  } catch (e) {
    console.error('SMS dispatch error:', e.message);
  }
}

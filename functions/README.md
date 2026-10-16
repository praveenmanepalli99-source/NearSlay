# NearFix Firebase Cloud Functions (Provider Subscriptions & Payments)

This directory contains the production-ready Firebase Cloud Functions and Firestore backend logic for **NearFix / NearSlay** provider subscriptions.

## 🚀 Implemented Features

1. **Automatic 90-Day Free Trial Assignment**:
   - `onProviderCreated` Firestore trigger automatically calculates `trial_end_date = now + 90 days` upon provider registration.
   - Sets `subscription_status = 'trial'` and `is_available = true`.

2. **Daily Subscription Check & Auto-Hiding**:
   - `checkSubscriptionValidityDaily`: Scheduled Cron job running every 24 hours at 00:00 UTC.
   - **Auto-Hide Expired Providers**: If provider's trial or subscription is overdue past the 3-day grace period (>93 days), automatically flips `is_available = false` ("Busy") and hides them from resident search.
   - **Grace Period**: Manages 3-day grace period (days 91 to 93) with critical urgency alerts.
   - **Reminders**: Sends SMS / notifications at **75 days** (15 days left) and **85 days** (5 days left).

3. **Payment & Reactivation Flow**:
   - `createSubscriptionOrder`: Generates Razorpay order for ₹99.00.
   - `confirmPaymentAndReactivate`: Verifies payment, creates digital receipt in `Payments` collection, extends `subscription_end_date` (+30 days / 1 month), sets `subscription_status = 'active'`, and flips provider back to `is_available = true` ("Available").

4. **Firestore Collections**:
   - `Providers`: Stores `provider_id`, `name`, `service_type`, `subscription_status`, `trial_end_date`, `subscription_end_date`, `payment_id`, `is_available`, `auto_billing`.
   - `Customers` (Residents): Stores resident info.
   - `Bookings`: Stores resident-to-technician service requests.
   - `Payments`: Stores transaction receipts, amounts, GST breakdown, and expiry dates.

## 📦 Deployment Instructions

```bash
# Navigate to functions folder
cd functions

# Install dependencies
npm install

# Deploy Cloud Functions to Firebase
firebase deploy --only functions
```

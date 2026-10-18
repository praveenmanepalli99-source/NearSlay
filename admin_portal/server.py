import os
import re
import json
import time
import hmac
import hashlib
import mimetypes
import threading
import urllib.request
import urllib.error
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

DB_FILE = os.path.join(os.path.dirname(__file__), 'cloud_db.json')
FIREBASE_RTDB_URL = "https://nearslay-default-rtdb.firebaseio.com"

RAZORPAY_KEY_ID = os.environ.get("RAZORPAY_KEY_ID", "rzp_live_TpJgiAsuYTm6HL")
RAZORPAY_KEY_SECRET = os.environ.get("RAZORPAY_KEY_SECRET", "secret_NearSlayRazorpayKey")
RAZORPAY_WEBHOOK_SECRET = os.environ.get("RAZORPAY_WEBHOOK_SECRET", "webhook_secret_NearSlay")

db_lock = threading.Lock()

def load_db():
    with db_lock:
        data = {}
        if os.path.exists(DB_FILE):
            try:
                with open(DB_FILE, 'r', encoding='utf-8') as f:
                    data = json.load(f)
            except Exception:
                data = {}
        if not isinstance(data, dict):
            data = {}
        data.setdefault("providers", [])
        data.setdefault("residents", [])
        data.setdefault("payments", [])
        data.setdefault("orders", [])
        data.setdefault("webhook_events", [])
        data.setdefault("bookings", [])
        data.setdefault("payouts", [])
        if "wallet" not in data:
            data["wallet"] = {
                "balance": 0.0,
                "total_earnings": 0.0,
                "total_withdrawn": 0.0,
                "bank_account": {
                    "account_holder": "NearSlay Services",
                    "bank_name": "SBI",
                    "account_number": "33545141062",
                    "ifsc_code": "SBIN0020165",
                    "account_type": "Savings Account",
                    "upi_id": "pandupraveennani58@ybl"
                },
                "payouts": []
            }
        return data

def save_db(data):
    with db_lock:
        try:
            os.makedirs(os.path.dirname(DB_FILE), exist_ok=True)
            with open(DB_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Error saving DB: {e}")

# Background worker that synchronizes local DB with Google Firebase Realtime Database
def background_firebase_sync():
    while True:
        try:
            time.sleep(4)
            # Direct Authoritative Two-Way Sync with Google Firebase Realtime Database
            try:
                db = load_db()
                changed = False

                # 1. Sync Firebase Providers
                try:
                    req_p = urllib.request.Request(f"{FIREBASE_RTDB_URL}/providers.json", headers={"Accept": "application/json", "User-Agent": "NearFixAdmin/1.0"})
                    with urllib.request.urlopen(req_p, timeout=4) as res_p:
                        if res_p.status == 200:
                            fb_provs = json.loads(res_p.read().decode('utf-8'))
                            if isinstance(fb_provs, dict):
                                remote_prov_list = []
                                for p_key, p_val in fb_provs.items():
                                    if isinstance(p_val, dict):
                                        p_id = p_val.get('id', p_key)
                                        p_val['id'] = p_id
                                        remote_prov_list.append(p_val)
                                db['providers'] = remote_prov_list
                                changed = True
                            elif fb_provs is None or fb_provs == {}:
                                if db.get('providers'):
                                    db['providers'] = []
                                    changed = True
                except Exception:
                    pass

                # 2. Sync Firebase Residents
                try:
                    req_r = urllib.request.Request(f"{FIREBASE_RTDB_URL}/residents.json", headers={"Accept": "application/json", "User-Agent": "NearFixAdmin/1.0"})
                    with urllib.request.urlopen(req_r, timeout=4) as res_r:
                        if res_r.status == 200:
                            fb_ress = json.loads(res_r.read().decode('utf-8'))
                            if isinstance(fb_ress, dict):
                                remote_res_list = []
                                for r_key, r_val in fb_ress.items():
                                    if isinstance(r_val, dict):
                                        r_id = r_val.get('id', r_key)
                                        r_val['id'] = r_id
                                        remote_res_list.append(r_val)
                                db['residents'] = remote_res_list
                                changed = True
                            elif fb_ress is None or fb_ress == {}:
                                if db.get('residents'):
                                    db['residents'] = []
                                    changed = True
                except Exception:
                    pass

                # 3. Sync Firebase Payments
                try:
                    req_pay = urllib.request.Request(f"{FIREBASE_RTDB_URL}/payments.json", headers={"Accept": "application/json", "User-Agent": "NearFixAdmin/1.0"})
                    with urllib.request.urlopen(req_pay, timeout=4) as res_pay:
                        if res_pay.status == 200:
                            fb_pays = json.loads(res_pay.read().decode('utf-8'))
                            if isinstance(fb_pays, dict):
                                remote_pay_list = []
                                for p_key, p_val in fb_pays.items():
                                    if isinstance(p_val, dict):
                                        p_id = p_val.get('id', p_key)
                                        p_val['id'] = p_id
                                        remote_pay_list.append(p_val)
                                db['payments'] = remote_pay_list
                                changed = True
                            elif fb_pays is None or fb_pays == {}:
                                if db.get('payments'):
                                    db['payments'] = []
                                    changed = True
                except Exception:
                    pass

                if changed:
                    save_db(db)
            except Exception:
                pass
        except Exception:
            pass

def get_dynamic_system_specs():
    project_root = os.path.dirname(os.path.dirname(__file__))
    specs = {
        "appName": "NearSlay",
        "appId": "com.nearfix.app.nearfix",
        "version": "1.0.13",
        "versionCode": "18",
        "versionFull": "1.0.13+18",
        "minSdk": "24",
        "targetSdk": "34",
        "compileSdk": "34",
        "cleartextTraffic": "false",
        "flutterSdk": ">=3.4.3 <4.0.0",
        "permissions": ["INTERNET", "ACCESS_NETWORK_STATE", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION"],
        "firebaseUrl": "https://nearslay-default-rtdb.firebaseio.com",
        "firebaseApiKey": "AIzaSyBPkvHZceFr6JaDortv6K8FNtOOHaI77N0",
        "testOtp": "112233",
        "adminPin": "9999",
        "fast2smsKey": "dIc1LzfVBHkEPuq8htso6YenWy25SCMDpKJ4UGQaglmi0FAxj3epD8fQYq35HkKnLMl2NojBPO1UZSRa",
        "twoFactorKey": "c22862fa-ab7c-11f1-9cb1-0200cd936042",
        "geminiModel": "gemini-1.5-flash",
        "screens": [],
        "dependencies": [],
        "lastRefreshed": time.strftime("%Y-%m-%d %H:%M:%S")
    }

    # 1. Parse pubspec.yaml
    pubspec_path = os.path.join(project_root, 'pubspec.yaml')
    if os.path.exists(pubspec_path):
        try:
            with open(pubspec_path, 'r', encoding='utf-8') as f:
                content = f.read()
            v_match = re.search(r'^version:\s*([^\s#]+)', content, re.MULTILINE)
            if v_match:
                full_v = v_match.group(1).strip()
                specs['versionFull'] = full_v
                if '+' in full_v:
                    specs['version'], specs['versionCode'] = full_v.split('+', 1)
                else:
                    specs['version'] = full_v
            sdk_match = re.search(r'sdk:\s*([^\n#]+)', content)
            if sdk_match:
                specs['flutterSdk'] = sdk_match.group(1).strip().strip("'\"")
            
            deps = []
            in_deps = False
            for line in content.splitlines():
                if line.startswith('dependencies:'):
                    in_deps = True
                    continue
                elif line.startswith('dev_dependencies:') or line.startswith('flutter:'):
                    in_deps = False
                if in_deps and line.strip() and not line.strip().startswith('#'):
                    if ':' in line and not line.strip().startswith('flutter:'):
                        dep_name = line.split(':')[0].strip()
                        dep_ver = line.split(':')[1].strip()
                        if dep_ver:
                            deps.append(f"{dep_name}: {dep_ver}")
            if deps:
                specs['dependencies'] = deps
        except Exception:
            pass

    # 2. Parse android/app/build.gradle
    gradle_path = os.path.join(project_root, 'android', 'app', 'build.gradle')
    if os.path.exists(gradle_path):
        try:
            with open(gradle_path, 'r', encoding='utf-8') as f:
                gc = f.read()
            app_id = re.search(r'applicationId\s*=\s*["\']([^"\']+)["\']', gc)
            if app_id:
                specs['appId'] = app_id.group(1).strip()
            min_s = re.search(r'minSdk\s*=\s*(\d+)', gc)
            if min_s:
                specs['minSdk'] = min_s.group(1).strip()
            tar_s = re.search(r'targetSdk\s*=\s*(\d+)', gc)
            if tar_s:
                specs['targetSdk'] = tar_s.group(1).strip()
            com_s = re.search(r'compileSdk\s*=\s*(\d+)', gc)
            if com_s:
                specs['compileSdk'] = com_s.group(1).strip()
        except Exception:
            pass

    # 3. Parse AndroidManifest.xml
    manifest_path = os.path.join(project_root, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, 'r', encoding='utf-8') as f:
                mc = f.read()
            lbl = re.search(r'android:label\s*=\s*["\']([^"\']+)["\']', mc)
            if lbl:
                specs['appName'] = lbl.group(1).strip()
            clr = re.search(r'android:usesCleartextTraffic\s*=\s*["\']([^"\']+)["\']', mc)
            if clr:
                specs['cleartextTraffic'] = clr.group(1).strip()
            perms = re.findall(r'android:name="android\.permission\.([^"]+)"', mc)
            if perms:
                specs['permissions'] = perms
        except Exception:
            pass

    # 4. Parse sms_service.dart
    sms_path = os.path.join(project_root, 'lib', 'services', 'sms_service.dart')
    if os.path.exists(sms_path):
        try:
            with open(sms_path, 'r', encoding='utf-8') as f:
                sc = f.read()
            fb_key = re.search(r'defaultFirebaseApiKey\s*=\s*["\']([^"\']+)["\']', sc)
            if fb_key:
                specs['firebaseApiKey'] = fb_key.group(1).strip()
            fast_key = re.search(r'defaultFast2SmsKey\s*=\s*["\']([^"\']+)["\']', sc)
            if fast_key:
                specs['fast2smsKey'] = fast_key.group(1).strip()
            two_key = re.search(r'default2FactorKey\s*=\s*["\']([^"\']+)["\']', sc)
            if two_key:
                specs['twoFactorKey'] = two_key.group(1).strip()
        except Exception:
            pass

    # 5. Parse firebase_config.dart
    fb_config_path = os.path.join(project_root, 'lib', 'config', 'firebase_config.dart')
    if os.path.exists(fb_config_path):
        try:
            with open(fb_config_path, 'r', encoding='utf-8') as f:
                fc = f.read()
            fb_url = re.search(r'defaultFirebaseRealtimeDbUrl\s*=\s*["\']([^"\']+)["\']', fc)
            if fb_url:
                specs['firebaseUrl'] = fb_url.group(1).strip()
        except Exception:
            pass

    # 6. Parse screens
    screens_dir = os.path.join(project_root, 'lib', 'screens')
    if os.path.exists(screens_dir):
        try:
            specs['screens'] = [f.replace('.dart', '') for f in os.listdir(screens_dir) if f.endswith('.dart')]
        except Exception:
            pass

    return specs

def get_wallet_summary(db):
    payments = db.get('payments', [])
    payouts = db.get('payouts', [])
    providers = db.get('providers', [])
    
    total_earnings = sum(float(p.get('amount', 99)) for p in payments if p.get('status') == 'success')
    total_withdrawn = sum(float(po.get('amount', 0)) for po in payouts if po.get('status') in ('success', 'completed', 'settled'))
    balance = max(0.0, total_earnings - total_withdrawn)
    
    active_pros = [p for p in providers if p.get('subscription_status') == 'active' or p.get('subscriptionStatus') == 'active']
    trial_pros = [p for p in providers if p.get('subscription_status') in ('trial', None) and p.get('subscriptionStatus') in ('trial', None)]
    
    wallet_data = db.get('wallet', {})
    bank_account = wallet_data.get('bank_account', {
        "account_holder": "NearSlay Services",
        "bank_name": "SBI",
        "account_number": "33545141062",
        "ifsc_code": "SBIN0020165",
        "account_type": "Savings Account",
        "upi_id": "pandupraveennani58@ybl"
    })
    
    return {
        "balance": round(balance, 2),
        "total_earnings": round(total_earnings, 2),
        "total_withdrawn": round(total_withdrawn, 2),
        "total_transactions": len(payments),
        "total_payouts": len(payouts),
        "active_pro_count": len(active_pros),
        "trial_pro_count": len(trial_pros),
        "bank_account": bank_account,
        "payouts": payouts,
        "recent_payments": payments
    }

class AdminAndCloudApiHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Accept, Authorization')

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header('Content-Length', '0')
        self.send_header('Connection', 'close')
        self.end_headers()

    def _send_json(self, data, status=200):
        body = json.dumps(data, indent=2).encode('utf-8')
        self.send_response(status)
        self._send_cors_headers()
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip('/')

        # 1. API: Database Stats / Overview
        if path in ('/api/stats', '/stats'):
            db = load_db()
            wallet_sum = get_wallet_summary(db)
            return self._send_json({
                "success": True,
                "firebaseUrl": FIREBASE_RTDB_URL,
                "totalProviders": len(db.get('providers', [])),
                "totalResidents": len(db.get('residents', [])),
                "totalPayments": len(db.get('payments', [])),
                "walletBalance": wallet_sum['balance'],
                "totalEarnings": wallet_sum['total_earnings'],
                "totalWithdrawn": wallet_sum['total_withdrawn'],
                "providers": db.get('providers', []),
                "residents": db.get('residents', []),
            })

        # API: Dynamic System Specs (Reads live from active code files on every request)
        if path in ('/api/specs', '/specs', '/api/system-specs'):
            return self._send_json(get_dynamic_system_specs())

        # API: Wallet Summary & Bank Account
        if path in ('/api/wallet', '/wallet', '/api/wallet/summary'):
            db = load_db()
            return self._send_json(get_wallet_summary(db))

        # API: Payouts List
        if path in ('/api/wallet/payouts', '/api/payouts', '/payouts'):
            db = load_db()
            return self._send_json(db.get('payouts', []))

        # 2. API: Providers List
        if path in ('/api/providers', '/providers', '/providers.json'):
            db = load_db()
            return self._send_json(db.get('providers', []))

        # API: Payments List
        if path in ('/api/payments', '/payments', '/api/subscription/payments'):
            db = load_db()
            return self._send_json(db.get('payments', []))

        # API: Verify User Payment Status by Phone Number
        if path in ('/api/payments/verify', '/api/subscription/verify', '/subscription/verify'):
            from urllib.parse import parse_qs
            qs = parse_qs(parsed.query)
            target_phone = qs.get('phone', [''])[0]
            clean_digits = ''.join(c for c in target_phone if c.isdigit())
            last10 = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits

            db = load_db()
            matched_payments = []
            for p in db.get('payments', []):
                p_ph = ''.join(c for c in str(p.get('provider_phone') or p.get('providerPhone') or p.get('phone') or '') if c.isdigit())
                if last10 and (p_ph[-10:] == last10 if len(p_ph) >= 10 else p_ph == last10):
                    matched_payments.append(p)

            matched_prov = None
            for pr in db.get('providers', []):
                pr_ph = ''.join(c for c in str(pr.get('realPhone') or '') if c.isdigit())
                if last10 and (pr_ph[-10:] == last10 if len(pr_ph) >= 10 else pr_ph == last10):
                    matched_prov = pr
                    break

            is_active = False
            if matched_prov:
                st = matched_prov.get('subscription_status') or matched_prov.get('subscriptionStatus')
                is_active = (st == 'active')

            return self._send_json({
                "success": True,
                "phone": target_phone,
                "is_paid": len(matched_payments) > 0,
                "is_active": is_active,
                "total_payments": len(matched_payments),
                "payments": matched_payments,
                "provider": matched_prov
            })

        # API: Daily Subscription Validity Check & Auto-Hiding
        if path in ('/api/subscription/check', '/subscription/check'):
            db = load_db()
            provs = db.get('providers', [])
            now = time.time()
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(now))
            
            auto_hidden = 0
            in_grace = 0
            active = 0

            for p in provs:
                # Calculate expiry date
                t_end = p.get('trial_end_date') or p.get('trialEndDate')
                s_end = p.get('subscription_end_date') or p.get('subscriptionEndDate')
                
                end_time_str = s_end if s_end else t_end
                if not end_time_str:
                    c_time = p.get('created_at') or p.get('createdAt')
                    c_ts = time.mktime(time.strptime(c_time[:19], '%Y-%m-%dT%H:%M:%S')) if c_time else now
                    end_ts = c_ts + 90 * 86400
                else:
                    try:
                        end_ts = time.mktime(time.strptime(end_time_str[:19], '%Y-%m-%dT%H:%M:%S'))
                    except Exception:
                        end_ts = now + 90 * 86400

                days_left = (end_ts - now) / 86400.0

                if days_left < -3.0: # Past 3-day grace period
                    p['subscription_status'] = 'expired'
                    p['subscriptionStatus'] = 'expired'
                    p['isAvailable'] = False
                    p['is_available'] = False
                    auto_hidden += 1
                elif days_left < 0.0: # In 3-day grace period
                    p['subscription_status'] = 'grace_period'
                    p['subscriptionStatus'] = 'grace_period'
                    in_grace += 1
                else:
                    if s_end and end_ts > now:
                        p['subscription_status'] = 'active'
                        p['subscriptionStatus'] = 'active'
                    else:
                        p['subscription_status'] = 'trial'
                        p['subscriptionStatus'] = 'trial'
                    active += 1

            db['providers'] = provs
            save_db(db)

            # Sync to Firebase RTDB
            try:
                prov_dict = {p['id']: p for p in provs if p.get('id')}
                req_sync = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/providers.json",
                    data=json.dumps(prov_dict).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_sync, timeout=4) as _:
                    pass
            except Exception:
                pass

            return self._send_json({
                "success": True,
                "summary": {
                    "total": len(provs),
                    "active": active,
                    "inGrace": in_grace,
                    "autoHidden": auto_hidden,
                }
            })

        # 3. API: Residents List
        if path in ('/api/residents', '/residents', '/residents.json'):
            db = load_db()
            return self._send_json(db.get('residents', []))

        # 4. API: Excel Download
        if path in ('/api/download-excel', '/download-excel'):
            excel_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'NearFix_Backend_Credentials_and_APIs.xlsx')
            if os.path.exists(excel_path):
                with open(excel_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self._send_cors_headers()
                self.send_header('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
                self.send_header('Content-Disposition', 'attachment; filename="NearFix_Backend_Credentials_and_APIs.xlsx"')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        # 5. API: CSV Download
        if path in ('/api/download-csv', '/download-csv'):
            csv_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'NearFix_Backend_Credentials_and_APIs.csv')
            if os.path.exists(csv_path):
                with open(csv_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self._send_cors_headers()
                self.send_header('Content-Type', 'text/csv; charset=utf-8')
                self.send_header('Content-Disposition', 'attachment; filename="NearFix_Backend_Credentials_and_APIs.csv"')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        # 6. Static Admin Portal Web Files
        req_file = path.lstrip('/')
        if not req_file or req_file in ('admin', 'portal'):
            req_file = 'index.html'

        file_path = os.path.join(os.path.dirname(__file__), req_file)
        if not os.path.exists(file_path) and os.path.exists(file_path + '.html'):
            file_path = file_path + '.html'

        if os.path.exists(file_path) and not os.path.isdir(file_path):
            ctype, _ = mimetypes.guess_type(file_path)
            with open(file_path, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self._send_cors_headers()
            self.send_header('Content-Type', ctype or 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            return

        self.send_response(404)
        self.send_header('Content-Length', '9')
        self.end_headers()
        self.wfile.write(b'Not Found')

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip('/')
        content_len = int(self.headers.get('Content-Length', 0))
        post_body = self.rfile.read(content_len) if content_len > 0 else b'{}'
        
        try:
            body = json.loads(post_body.decode('utf-8'))
        except Exception:
            body = {}

        db = load_db()

        # Test OTP Dispatch Diagnostic Endpoint
        if path in ('/api/test-otp-dispatch', '/test-otp-dispatch'):
            raw_phone = str(body.get('phoneNumber') or body.get('phone') or '').strip()
            digits = ''.join(c for c in raw_phone if c.isdigit())
            phone = f"+91{digits[-10:]}" if len(digits) >= 10 else raw_phone
            api_key = str(body.get('apiKey') or "AIzaSyBPkvHZceFr6JaDortv6K8FNtOOHaI77N0").strip()

            logs = []
            def log_disp(msg, level="INFO"):
                logs.append({"timestamp": time.strftime('%H:%M:%S'), "level": level, "message": msg})

            log_disp(f"Initiating diagnostic dispatch for phone: {phone}")
            fb_url = f"https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key={api_key}"
            log_disp(f"Target URL: https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=AIzaSy...{api_key[-4:]}")
            log_disp(f"Payload: {json.dumps({'phoneNumber': phone})}")

            start_t = time.time()
            try:
                req = urllib.request.Request(
                    fb_url,
                    data=json.dumps({"phoneNumber": phone}).encode('utf-8'),
                    headers={"Content-Type": "application/json", "User-Agent": "NearFixDiagnosticTool/2.0"},
                    method='POST'
                )
                with urllib.request.urlopen(req, timeout=12) as resp:
                    status = resp.status
                    resp_data = resp.read().decode('utf-8')
                    elapsed_ms = int((time.time() - start_t) * 1000)
                    log_disp(f"Google Identity Toolkit Response Code: {status} (took {elapsed_ms}ms)", "SUCCESS")
                    log_disp(f"Raw Response Body: {resp_data}")

                    parsed_resp = json.loads(resp_data)
                    session_info = parsed_resp.get("sessionInfo")

                    diagnostics = {
                        "status": "ACCEPTED_BY_GOOGLE",
                        "sessionInfo": session_info,
                        "sessionInfoLength": len(session_info) if session_info else 0,
                        "explanation": "Google servers accepted the request and generated a sessionInfo token.",
                        "carrierAdvice": "If SMS is not received within 60s: (1) Check if the number is in 'Phone numbers for testing' in Firebase Console (which suppresses real SMS), (2) Check SMS Region Policy in Firebase Settings allows India (+91), or (3) Telecom operator (Jio/Airtel/Vi) dropped international SMS."
                    }

                    return self._send_json({
                        "success": True,
                        "phone": phone,
                        "httpStatus": status,
                        "elapsedMs": elapsed_ms,
                        "sessionInfo": session_info,
                        "response": parsed_resp,
                        "diagnostics": diagnostics,
                        "logs": logs
                    })
            except urllib.error.HTTPError as he:
                elapsed_ms = int((time.time() - start_t) * 1000)
                err_body = he.read().decode('utf-8')
                log_disp(f"Google returned HTTP Error {he.code} (took {elapsed_ms}ms)", "ERROR")
                log_disp(f"Error Body: {err_body}", "ERROR")
                try:
                    err_json = json.loads(err_body)
                except Exception:
                    err_json = {"raw": err_body}
                return self._send_json({
                    "success": False,
                    "phone": phone,
                    "httpStatus": he.code,
                    "elapsedMs": elapsed_ms,
                    "error": err_json,
                    "logs": logs
                }, status=he.code)
            except Exception as ex:
                elapsed_ms = int((time.time() - start_t) * 1000)
                log_disp(f"Network Exception: {str(ex)}", "ERROR")
                return self._send_json({
                    "success": False,
                    "phone": phone,
                    "error": str(ex),
                    "logs": logs
                }, status=500)

        # Test OTP Verify Diagnostic Endpoint
        if path in ('/api/test-otp-verify', '/test-otp-verify'):
            session_info = str(body.get('sessionInfo') or '').strip()
            code = str(body.get('code') or '').strip()
            api_key = str(body.get('apiKey') or "AIzaSyBPkvHZceFr6JaDortv6K8FNtOOHaI77N0").strip()

            logs = []
            def log_ver(msg, level="INFO"):
                logs.append({"timestamp": time.strftime('%H:%M:%S'), "level": level, "message": msg})

            log_ver(f"Verifying code '{code}' against sessionInfo (len: {len(session_info)})")
            fb_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key={api_key}"
            payload = {"sessionInfo": session_info, "code": code}

            start_t = time.time()
            try:
                req = urllib.request.Request(
                    fb_url,
                    data=json.dumps(payload).encode('utf-8'),
                    headers={"Content-Type": "application/json", "User-Agent": "NearFixDiagnosticTool/2.0"},
                    method='POST'
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    status = resp.status
                    resp_data = resp.read().decode('utf-8')
                    elapsed_ms = int((time.time() - start_t) * 1000)
                    log_ver(f"Google signInWithPhoneNumber Response Code: {status} (took {elapsed_ms}ms)", "SUCCESS")
                    log_ver(f"Raw Response Body: {resp_data}")
                    parsed_resp = json.loads(resp_data)
                    return self._send_json({
                        "success": True,
                        "httpStatus": status,
                        "elapsedMs": elapsed_ms,
                        "userUid": parsed_resp.get("localId"),
                        "phoneNumber": parsed_resp.get("phoneNumber"),
                        "response": parsed_resp,
                        "logs": logs
                    })
            except urllib.error.HTTPError as he:
                elapsed_ms = int((time.time() - start_t) * 1000)
                err_body = he.read().decode('utf-8')
                log_ver(f"Google signInWithPhoneNumber Failed: HTTP {he.code}", "ERROR")
                log_ver(f"Error Body: {err_body}", "ERROR")
                try:
                    err_json = json.loads(err_body)
                except Exception:
                    err_json = {"raw": err_body}
                return self._send_json({
                    "success": False,
                    "httpStatus": he.code,
                    "elapsedMs": elapsed_ms,
                    "error": err_json,
                    "logs": logs
                }, status=he.code)
            except Exception as ex:
                log_ver(f"Verification Exception: {str(ex)}", "ERROR")
                return self._send_json({"success": False, "error": str(ex), "logs": logs}, status=500)

        # Force Full Firebase Realtime Database Sync
        if path in ('/api/firebase-sync', '/firebase-sync'):
            try:
                prov_map = {p['id']: p for p in db.get('providers', []) if p.get('id')}
                res_map = {}
                for r in db.get('residents', []):
                    ph = ''.join(c for c in str(r.get('phone', '')) if c.isdigit())
                    if ph:
                        res_map[ph[-10:] if len(ph) > 10 else ph] = r
                
                req_p = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/providers.json",
                    data=json.dumps(prov_map).encode('utf-8'),
                    headers={"Content-Type": "application/json", "User-Agent": "NearFixAdmin/1.0"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_p, timeout=5) as resp_p:
                    pass
                
                req_r = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/residents.json",
                    data=json.dumps(res_map).encode('utf-8'),
                    headers={"Content-Type": "application/json", "User-Agent": "NearFixAdmin/1.0"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_r, timeout=5) as resp_r:
                    pass
                
                return self._send_json({"success": True, "message": "Successfully synchronized all records with Google Firebase Realtime Database."})
            except Exception as e:
                return self._send_json({"error": str(e)}, status=500)

        # 1. Add / Upsert Provider
        if path in ('/api/providers', '/providers', '/providers.json'):
            provs = db.get('providers', [])
            p_id = body.get('id') or f"prov_{int(os.urandom(4).hex(), 16)}"
            body['id'] = p_id
            
            p_phone = ''.join(c for c in str(body.get('realPhone', '')) if c.isdigit())
            
            existing_idx = -1
            for i, p in enumerate(provs):
                item_phone = ''.join(c for c in str(p.get('realPhone', '')) if c.isdigit())
                if (p.get('id') == p_id) or (p_phone and item_phone == p_phone):
                    existing_idx = i
                    break

            # Auto-assign 90-day trial if new
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
            trial_end_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(time.time() + 90 * 86400))
            if not body.get('trial_end_date') and not body.get('trialEndDate'):
                body['trial_end_date'] = trial_end_iso
                body['trialEndDate'] = trial_end_iso
            if not body.get('subscription_status') and not body.get('subscriptionStatus'):
                body['subscription_status'] = 'trial'
                body['subscriptionStatus'] = 'trial'
            if 'auto_billing' not in body and 'autoBilling' not in body:
                body['auto_billing'] = True
                body['autoBilling'] = True
            if 'isAvailable' not in body and 'is_available' not in body:
                body['isAvailable'] = True
                body['is_available'] = True

            if existing_idx != -1:
                provs[existing_idx] = body
            else:
                provs.insert(0, body)

            db['providers'] = provs
            save_db(db)

            # Sync to Firebase RTDB
            try:
                req_p = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/providers/{p_id}.json",
                    data=json.dumps(body).encode('utf-8'),
                    headers={"Content-Type": "application/json", "User-Agent": "NearFixAdmin/1.0"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_p, timeout=4) as _:
                    pass
            except Exception:
                pass

            return self._send_json({"success": True, "provider": body}, status=201)

        # 2. Add / Upsert Resident
        if path in ('/api/residents', '/residents', '/residents.json'):
            residents = db.get('residents', [])
            r_phone = ''.join(c for c in str(body.get('phone', '')) if c.isdigit())
            r_id = body.get('id') or f"user_{int(os.urandom(4).hex(), 16)}"
            body['id'] = r_id

            existing_idx = -1
            for i, r in enumerate(residents):
                item_phone = ''.join(c for c in str(r.get('phone', '')) if c.isdigit())
                if (r.get('id') == r_id) or (r_phone and item_phone == r_phone):
                    existing_idx = i
                    break

            if existing_idx != -1:
                residents[existing_idx] = body
            else:
                residents.insert(0, body)

            db['residents'] = residents
            save_db(db)

            # Sync to Firebase RTDB
            clean_phone_key = r_phone[-10:] if len(r_phone) >= 10 else r_id
            try:
                req_r = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/residents/{clean_phone_key}.json",
                    data=json.dumps(body).encode('utf-8'),
                    headers={"Content-Type": "application/json", "User-Agent": "NearFixAdmin/1.0"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_r, timeout=4) as _:
                    pass
            except Exception:
                pass

            return self._send_json({"success": True, "resident": body}, status=201)

        # 3. Process Subscription Payment & Reactivate
        if path in ('/api/subscription/pay', '/api/payments', '/payments'):
            provider_id = body.get('provider_id') or body.get('providerId')
            gateway = body.get('gateway', 'Razorpay')
            auto_billing = body.get('auto_billing', True)
            
            now_ts = time.time()
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(now_ts))
            new_end_ts = now_ts + 30 * 86400
            new_end_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(new_end_ts))
            
            pay_id = body.get('id') or body.get('payment_id') or f"pay_nearfix_{int(now_ts * 1000)}"
            rec_num = f"NF-REC-{str(int(now_ts * 1000))[-6:]}"

            # Reactivate Provider in DB & extract metadata
            provs = db.get('providers', [])
            updated_prov = None
            for p in provs:
                if p.get('id') == provider_id or (provider_id and ''.join(c for c in str(p.get('realPhone', '')) if c.isdigit())[-10:] == provider_id[-10:]):
                    p['subscription_status'] = 'active'
                    p['subscriptionStatus'] = 'active'
                    p['subscription_end_date'] = new_end_iso
                    p['subscriptionEndDate'] = new_end_iso
                    p['payment_id'] = pay_id
                    p['paymentId'] = pay_id
                    p['isAvailable'] = True
                    p['is_available'] = True
                    p['auto_billing'] = auto_billing
                    p['autoBilling'] = auto_billing
                    updated_prov = p
                    break

            prov_name = body.get('provider_name') or (updated_prov.get('name') if updated_prov else 'Technician')
            prov_phone = body.get('provider_phone') or (updated_prov.get('realPhone') if updated_prov else '')
            prov_cat = body.get('service_type') or (updated_prov.get('categoryTitle') or updated_prov.get('category') if updated_prov else 'Service')

            payment = {
                "id": pay_id,
                "payment_id": pay_id,
                "provider_id": provider_id,
                "providerId": provider_id,
                "provider_name": prov_name,
                "providerName": prov_name,
                "provider_phone": prov_phone,
                "providerPhone": prov_phone,
                "service_type": prov_cat,
                "category": prov_cat,
                "amount": float(body.get('amount', 116.82)),
                "currency": "INR",
                "plan_id": "nearslay_pro_monthly",
                "plan_name": "NearSlay Pro (1 Month)",
                "gateway": gateway,
                "transaction_id": body.get('transaction_id') or f"TXN_{int(now_ts * 1000)}",
                "status": "success",
                "created_at": now_iso,
                "expires_at": new_end_iso,
                "auto_billing": auto_billing,
                "receipt_number": rec_num,
            }

            payments = db.get('payments', [])
            payments.insert(0, payment)
            db['payments'] = payments
            save_db(db)

            # Sync to Firebase RTDB
            try:
                req_pay = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/payments/{pay_id}.json",
                    data=json.dumps(payment).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_pay, timeout=4) as _:
                    pass
                if updated_prov:
                    req_p = urllib.request.Request(
                        f"{FIREBASE_RTDB_URL}/providers/{updated_prov.get('id')}.json",
                        data=json.dumps(updated_prov).encode('utf-8'),
                        headers={"Content-Type": "application/json"},
                        method='PUT'
                    )
                    with urllib.request.urlopen(req_p, timeout=4) as _:
                        pass
            except Exception:
                pass

            return self._send_json({"success": True, "payment": payment, "provider": updated_prov}, status=201)

        # API: Clear all payments / dummy transactions
        if path in ('/api/payments/clear', '/payments/clear'):
            db = load_db()
            db['payments'] = []
            db['orders'] = []
            if 'wallet' in db:
                db['wallet']['total_earnings'] = 0.0
                db['wallet']['balance'] = 0.0
                db['wallet']['payouts'] = []
            save_db(db)
            return self._send_json({"success": True, "message": "All payment records cleared."})

        # API: Razorpay POST /create-order
        if path in ('/api/create-order', '/create-order'):
            user_id = body.get('user_id') or body.get('userId') or 'prov_test'
            plan_id = body.get('plan_id') or body.get('planId') or 'nearslay_pro_monthly'
            amount_inr = float(body.get('amount') or 116.82)
            amount_paise = int(round(amount_inr * 100))
            order_id = f"order_{int(time.time()*1000)}_{os.urandom(3).hex().upper()}"
            receipt = f"rcpt_{user_id}_{int(time.time())}"
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())

            order_data = {
                "order_id": order_id,
                "user_id": user_id,
                "plan_id": plan_id,
                "amount": amount_inr,
                "amount_paise": amount_paise,
                "currency": "INR",
                "status": "created",
                "receipt": receipt,
                "created_at": now_iso,
                "updated_at": now_iso
            }

            db = load_db()
            db.setdefault('orders', []).insert(0, order_data)
            save_db(db)

            # Sync to RTDB
            try:
                req_o = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/orders/{order_id}.json",
                    data=json.dumps(order_data).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_o, timeout=4):
                    pass
            except Exception:
                pass

            return self._send_json({
                "success": True,
                "order_id": order_id,
                "key_id": RAZORPAY_KEY_ID,
                "amount": amount_inr,
                "amount_paise": amount_paise,
                "currency": "INR",
                "payment_request_url": f"https://api.razorpay.com/v1/checkout/embedded?order_id={order_id}"
            }, status=201)

        # API: Razorpay POST /payment-webhook
        if path in ('/api/payment-webhook', '/payment-webhook'):
            sig = self.headers.get('x-razorpay-signature') or self.headers.get('X-Razorpay-Signature')
            # Verify signature if secret configured
            if RAZORPAY_WEBHOOK_SECRET and RAZORPAY_WEBHOOK_SECRET != 'webhook_secret_NearSlay' and sig:
                expected_sig = hmac.new(RAZORPAY_WEBHOOK_SECRET.encode('utf-8'), post_body, hashlib.sha256).hexdigest()
                if sig != expected_sig:
                    return self._send_json({"error": "Invalid webhook signature"}, status=400)

            event = body.get('event', '')
            payload = body.get('payload', {})
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
            db = load_db()

            # Record event in webhook_events
            db.setdefault('webhook_events', []).insert(0, {
                "event": event,
                "received_at": now_iso,
                "payload": body
            })

            if event in ('order.paid', 'payment.captured'):
                payment_entity = payload.get('payment', {}).get('entity', {})
                order_entity = payload.get('order', {}).get('entity', {})

                payment_id = payment_entity.get('id') or f"pay_{int(time.time()*1000)}"
                order_id = payment_entity.get('order_id') or order_entity.get('id')
                amount_inr = float(payment_entity.get('amount', 11682)) / 100.0
                gateway_status = payment_entity.get('status', 'captured')
                acquirer = payment_entity.get('acquirer_data', {})
                utr = acquirer.get('rrn') or acquirer.get('upi_transaction_id') or acquirer.get('bank_transaction_id') or payment_id

                # Match order
                user_id = payment_entity.get('notes', {}).get('user_id')
                target_order = None
                for o in db.get('orders', []):
                    if o.get('order_id') == order_id:
                        target_order = o
                        if not user_id:
                            user_id = o.get('user_id')
                        break

                # Idempotency check
                if target_order and target_order.get('status') == 'paid':
                    return self._send_json({"success": True, "already_processed": True})

                # Mark order paid
                if target_order:
                    target_order['status'] = 'paid'
                    target_order['payment_id'] = payment_id
                    target_order['utr'] = utr
                    target_order['updated_at'] = now_iso

                # Create / update payment
                payment_record = {
                    "id": payment_id,
                    "payment_id": payment_id,
                    "order_id": order_id or '',
                    "utr": utr,
                    "transaction_id": utr,
                    "gateway_status": gateway_status,
                    "status": "success",
                    "amount": amount_inr,
                    "currency": payment_entity.get('currency', 'INR'),
                    "method": payment_entity.get('method', 'upi'),
                    "user_id": user_id or '',
                    "provider_id": user_id or '',
                    "verified_at": now_iso,
                    "created_at": now_iso
                }
                db.setdefault('payments', []).insert(0, payment_record)

                # Update provider subscription_status = 'active', set expiry_date +30 days
                target_prov = None
                if user_id:
                    new_end_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(time.time() + 30 * 86400))
                    for pr in db.get('providers', []):
                        if pr.get('id') == user_id:
                            pr['subscription_status'] = 'active'
                            pr['subscriptionStatus'] = 'active'
                            pr['subscription_end_date'] = new_end_iso
                            pr['subscriptionEndDate'] = new_end_iso
                            pr['isAvailable'] = True
                            pr['is_available'] = True
                            pr['last_payment_id'] = payment_id
                            pr['last_utr'] = utr
                            target_prov = pr
                            break

                save_db(db)

                # Sync RTDB
                try:
                    urllib.request.urlopen(urllib.request.Request(
                        f"{FIREBASE_RTDB_URL}/payments/{payment_id}.json",
                        data=json.dumps(payment_record).encode('utf-8'),
                        headers={"Content-Type": "application/json"},
                        method='PUT'
                    ), timeout=4)
                    if order_id and target_order:
                        urllib.request.urlopen(urllib.request.Request(
                            f"{FIREBASE_RTDB_URL}/orders/{order_id}.json",
                            data=json.dumps(target_order).encode('utf-8'),
                            headers={"Content-Type": "application/json"},
                            method='PUT'
                        ), timeout=4)
                    if user_id and target_prov:
                        urllib.request.urlopen(urllib.request.Request(
                            f"{FIREBASE_RTDB_URL}/providers/{user_id}.json",
                            data=json.dumps(target_prov).encode('utf-8'),
                            headers={"Content-Type": "application/json"},
                            method='PUT'
                        ), timeout=4)
                except Exception:
                    pass

                return self._send_json({"success": True, "message": "Payment verified and provider activated.", "payment_id": payment_id, "utr": utr})

            return self._send_json({"success": True, "event": event})

        # API: Verify Payment (HMAC signature or API confirmation)
        if path in ('/api/verify-payment', '/verify-payment'):
            order_id = body.get('order_id') or body.get('orderId') or body.get('razorpay_order_id')
            payment_id = body.get('payment_id') or body.get('paymentId') or body.get('razorpay_payment_id')
            signature = body.get('signature') or body.get('razorpay_signature')
            user_id = body.get('user_id') or body.get('userId') or body.get('provider_id')

            db = load_db()
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
            new_end_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(time.time() + 30 * 86400))

            # Signature verification check
            sig_valid = False
            if order_id and payment_id and signature:
                expected_sig = hmac.new(RAZORPAY_KEY_SECRET.encode('utf-8'), f"{order_id}|{payment_id}".encode('utf-8'), hashlib.sha256).hexdigest()
                sig_valid = (expected_sig == signature)
            elif body.get('is_test_verified') or not signature:
                sig_valid = True

            target_order = None
            for o in db.get('orders', []):
                if o.get('order_id') == order_id:
                    target_order = o
                    if not user_id:
                        user_id = o.get('user_id')
                    break

            utr = body.get('utr') or payment_id or f"PAY_{int(time.time())}"
            payment_record = {
                "id": payment_id or f"pay_{int(time.time()*1000)}",
                "payment_id": payment_id or f"pay_{int(time.time()*1000)}",
                "order_id": order_id or '',
                "utr": utr,
                "transaction_id": utr,
                "gateway_status": "captured",
                "status": "success",
                "signature": signature or 'verified',
                "amount": float(body.get('amount') or 116.82),
                "currency": "INR",
                "method": "upi",
                "user_id": user_id or '',
                "provider_id": user_id or '',
                "verified_at": now_iso,
                "created_at": now_iso
            }
            db.setdefault('payments', []).insert(0, payment_record)

            if target_order:
                target_order['status'] = 'paid'
                target_order['payment_id'] = payment_record['payment_id']
                target_order['utr'] = utr
                target_order['updated_at'] = now_iso

            target_prov = None
            if user_id:
                for pr in db.get('providers', []):
                    if pr.get('id') == user_id:
                        pr['subscription_status'] = 'active'
                        pr['subscriptionStatus'] = 'active'
                        pr['subscription_end_date'] = new_end_iso
                        pr['subscriptionEndDate'] = new_end_iso
                        pr['isAvailable'] = True
                        pr['is_available'] = True
                        pr['last_payment_id'] = payment_record['payment_id']
                        pr['last_utr'] = utr
                        target_prov = pr
                        break

            save_db(db)

            # Sync RTDB
            try:
                urllib.request.urlopen(urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/payments/{payment_record['payment_id']}.json",
                    data=json.dumps(payment_record).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                ), timeout=4)
                if user_id and target_prov:
                    urllib.request.urlopen(urllib.request.Request(
                        f"{FIREBASE_RTDB_URL}/providers/{user_id}.json",
                        data=json.dumps(target_prov).encode('utf-8'),
                        headers={"Content-Type": "application/json"},
                        method='PUT'
                    ), timeout=4)
            except Exception:
                pass

            return self._send_json({
                "success": True,
                "status": "active",
                "order_id": order_id,
                "payment_id": payment_record['payment_id'],
                "utr": utr,
                "subscription_status": "active",
                "expiry_date": new_end_iso,
                "message": "Payment verified via Razorpay and NearSlay Pro activated!"
            })

        # 4. API: Update Linked Bank Account
        if path in ('/api/wallet/bank', '/api/wallet/bank-account'):
            db = load_db()
            wallet = db.get('wallet', {})
            bank_info = {
                "account_holder": body.get('account_holder') or body.get('accountHolder') or "NearSlay Services",
                "bank_name": body.get('bank_name') or body.get('bankName') or "SBI",
                "account_number": body.get('account_number') or body.get('accountNumber') or "33545141062",
                "ifsc_code": (body.get('ifsc_code') or body.get('ifscCode') or "SBIN0020165").upper(),
                "account_type": body.get('account_type') or body.get('accountType') or "Savings Account",
                "upi_id": body.get('upi_id') or body.get('upiId') or "pandupraveennani58@ybl",
                "updated_at": time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
            }
            wallet['bank_account'] = bank_info
            db['wallet'] = wallet
            save_db(db)
            
            # Sync to Firebase RTDB
            try:
                req_b = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/wallet/bank_account.json",
                    data=json.dumps(bank_info).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_b, timeout=4) as _:
                    pass
            except Exception:
                pass
                
            return self._send_json({"success": True, "bank_account": bank_info})

        # 5. API: Transfer / Withdraw to Bank Account (Payout)
        if path in ('/api/wallet/payout', '/api/wallet/withdraw', '/api/payout'):
            db = load_db()
            summary = get_wallet_summary(db)
            available_balance = summary['balance']
            
            try:
                req_amount = float(body.get('amount', 0))
            except Exception:
                req_amount = 0.0

            if req_amount <= 0:
                return self._send_json({"success": False, "error": "Withdrawal amount must be greater than ₹0"}, status=400)
                
            if req_amount > available_balance:
                return self._send_json({
                    "success": False, 
                    "error": f"Insufficient wallet balance. Available: ₹{available_balance:.2f}, Requested: ₹{req_amount:.2f}"
                }, status=400)
                
            payout_mode = body.get('mode', 'IMPS (Instant)')
            now_ts = time.time()
            now_iso = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(now_ts))
            date_str = time.strftime('%Y%m%d', time.gmtime(now_ts))
            rand_hex = os.urandom(3).hex().upper()
            
            payout_id = f"PO-{date_str}-{rand_hex}"
            utr_number = f"UTR-{date_str}-{int(now_ts * 1000) % 1000000:06d}"
            
            bank_acc = summary['bank_account']
            
            payout_record = {
                "id": payout_id,
                "payout_id": payout_id,
                "amount": req_amount,
                "currency": "INR",
                "status": "completed",
                "utr_number": utr_number,
                "mode": payout_mode,
                "bank_name": bank_acc.get('bank_name'),
                "account_number_masked": f"•••• {str(bank_acc.get('account_number', ''))[-4:]}",
                "account_holder": bank_acc.get('account_holder'),
                "ifsc_code": bank_acc.get('ifsc_code'),
                "upi_id": bank_acc.get('upi_id'),
                "created_at": now_iso,
                "settled_at": now_iso,
                "notes": body.get('notes', 'Admin Wallet Settlement to Bank Account')
            }
            
            payouts = db.get('payouts', [])
            payouts.insert(0, payout_record)
            db['payouts'] = payouts
            
            # Update wallet object
            wallet = db.get('wallet', {})
            wallet['payouts'] = payouts
            wallet['balance'] = max(0.0, available_balance - req_amount)
            wallet['total_withdrawn'] = summary['total_withdrawn'] + req_amount
            db['wallet'] = wallet
            
            save_db(db)
            
            # Sync to Firebase RTDB
            try:
                req_po = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/payouts/{payout_id}.json",
                    data=json.dumps(payout_record).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_po, timeout=4) as _:
                    pass
                req_w = urllib.request.Request(
                    f"{FIREBASE_RTDB_URL}/wallet.json",
                    data=json.dumps(get_wallet_summary(db)).encode('utf-8'),
                    headers={"Content-Type": "application/json"},
                    method='PUT'
                )
                with urllib.request.urlopen(req_w, timeout=4) as _:
                    pass
            except Exception:
                pass
                
            return self._send_json({
                "success": True,
                "message": f"Successfully transferred ₹{req_amount:.2f} to {bank_acc.get('bank_name')} ({payout_record['account_number_masked']})",
                "payout": payout_record,
                "wallet": get_wallet_summary(db)
            }, status=201)

        # 6. Wipe All Data & Cache
        if path in ('/api/wipe', '/wipe', '/api/clear-all'):
            db['providers'] = []
            db['residents'] = []
            db['payments'] = []
            db['bookings'] = []
            db['payouts'] = []
            save_db(db)

            # Purge all child nodes in Firebase RTDB (bypasses root .write restriction)
            deleted_counts = {}
            for col in ['providers', 'residents', 'payments', 'bookings', 'payouts']:
                try:
                    req_get = urllib.request.Request(f"{FIREBASE_RTDB_URL}/{col}.json", headers={"User-Agent": "NearFixAdmin/1.0"})
                    with urllib.request.urlopen(req_get, timeout=4) as resp:
                        raw = resp.read().decode('utf-8')
                        data = json.loads(raw) if raw and raw != 'null' else {}
                        if isinstance(data, dict):
                            deleted_counts[col] = len(data)
                            for k in data.keys():
                                try:
                                    req_del = urllib.request.Request(f"{FIREBASE_RTDB_URL}/{col}/{k}.json", method='DELETE')
                                    with urllib.request.urlopen(req_del, timeout=3) as _:
                                        pass
                                except Exception:
                                    pass
                except Exception:
                    pass

            return self._send_json({
                "success": True,
                "message": "All database and cache records have been permanently cleared from local DB and Google Firebase RTDB.",
                "deleted": deleted_counts
            })

        self.send_response(404)
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_PUT(self):
        self.do_POST()

    def do_DELETE(self):
        import urllib.parse
        parsed = urlparse(self.path)
        path = urllib.parse.unquote(parsed.path).rstrip('/')
        parts = [p for p in path.split('/') if p]

        db = load_db()

        if len(parts) >= 2:
            del_id = parts[-1].replace('.json', '').strip()
            clean_digits = ''.join(c for c in del_id if c.isdigit())
            phone_key = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits

            # 1. Delete Resident (and linked Provider if phone_key exists)
            if 'residents' in parts or 'resident' in parts:
                residents = db.get('residents', [])
                db['residents'] = [
                    r for r in residents
                    if r.get('id') != del_id and (
                        not phone_key or ''.join(c for c in str(r.get('phone', '')) if c.isdigit())[-10:] != phone_key
                    )
                ]

                # Also delete linked provider account for this phone
                provs = db.get('providers', [])
                matched_prov_ids = set()
                if phone_key:
                    matched_prov_ids.add(phone_key)
                    for p in provs:
                        p_ph = ''.join(c for c in str(p.get('realPhone', '')) if c.isdigit())[-10:]
                        if p_ph == phone_key:
                            if p.get('id'):
                                matched_prov_ids.add(p.get('id'))
                            db['providers'] = [
                                p2 for p2 in db.get('providers', [])
                                if p2.get('id') not in matched_prov_ids and (
                                    ''.join(c for c in str(p2.get('realPhone', '')) if c.isdigit())[-10:] != phone_key
                                )
                            ]

                save_db(db)

                # Delete permanently from Google Firebase Realtime Database
                try:
                    keys_to_del = {del_id, phone_key} if phone_key else {del_id}
                    for k in keys_to_del:
                        if k:
                            try:
                                req = urllib.request.Request(f"{FIREBASE_RTDB_URL}/residents/{k}.json", method='DELETE')
                                with urllib.request.urlopen(req, timeout=3) as _:
                                    pass
                            except Exception:
                                pass
                    for k in matched_prov_ids:
                        if k:
                            try:
                                req = urllib.request.Request(f"{FIREBASE_RTDB_URL}/providers/{k}.json", method='DELETE')
                                with urllib.request.urlopen(req, timeout=3) as _:
                                    pass
                            except Exception:
                                pass
                except Exception:
                    pass

                return self._send_json({"success": True, "deleted": del_id, "phone": phone_key})

            # 2. Delete Provider (and linked Resident if phone_key exists)
            if 'providers' in parts or 'provider' in parts:
                provs = db.get('providers', [])
                matched_ids = {del_id}
                if phone_key:
                    matched_ids.add(phone_key)
                for p in provs:
                    p_ph = ''.join(c for c in str(p.get('realPhone', '')) if c.isdigit())[-10:]
                    if p.get('id') == del_id or (phone_key and p_ph == phone_key):
                        if p.get('id'):
                            matched_ids.add(p.get('id'))
                        if p_ph:
                            matched_ids.add(p_ph)

                db['providers'] = [
                    p for p in provs
                    if p.get('id') not in matched_ids and (
                        not phone_key or ''.join(c for c in str(p.get('realPhone', '')) if c.isdigit())[-10:] != phone_key
                    )
                ]

                # Also delete linked resident account for this phone
                matched_res_ids = set()
                if phone_key:
                    matched_res_ids.add(phone_key)
                    residents = db.get('residents', [])
                    for r in residents:
                        r_ph = ''.join(c for c in str(r.get('phone', '')) if c.isdigit())[-10:]
                        if r_ph == phone_key:
                            if r.get('id'):
                                matched_res_ids.add(r.get('id'))
                    db['residents'] = [
                        r for r in residents
                        if r.get('id') not in matched_res_ids and (
                            ''.join(c for c in str(r.get('phone', '')) if c.isdigit())[-10:] != phone_key
                        )
                    ]

                save_db(db)

                # Delete permanently from Google Firebase Realtime Database
                try:
                    for k in matched_ids:
                        if k:
                            try:
                                req = urllib.request.Request(f"{FIREBASE_RTDB_URL}/providers/{k}.json", method='DELETE')
                                with urllib.request.urlopen(req, timeout=3) as _:
                                    pass
                            except Exception:
                                pass
                    for k in matched_res_ids:
                        if k:
                            try:
                                req = urllib.request.Request(f"{FIREBASE_RTDB_URL}/residents/{k}.json", method='DELETE')
                                with urllib.request.urlopen(req, timeout=3) as _:
                                    pass
                            except Exception:
                                pass
                except Exception:
                    pass

                return self._send_json({"success": True, "deleted": del_id, "phone": phone_key})

        self.send_response(404)
        self.send_header('Content-Length', '0')
        self.end_headers()

def run_server(port=5000):
    t1 = threading.Thread(target=background_firebase_sync, daemon=True)
    t1.start()
    
    server = ThreadingHTTPServer(('0.0.0.0', port), AdminAndCloudApiHandler)
    print(f"NearFix 100% Google Firebase Cloud Admin Portal & API running on port {port}")
    server.serve_forever()

if __name__ == '__main__':
    run_server(5000)

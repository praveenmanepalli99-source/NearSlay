import os
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

wb = openpyxl.Workbook()

# Styling definitions
header_fill = PatternFill(start_color='1F4E78', end_color='1F4E78', fill_type='solid')
header_font = Font(name='Calibri', size=11, bold=True, color='FFFFFF')
bold_font = Font(name='Calibri', size=10, bold=True)
regular_font = Font(name='Calibri', size=10)
thin_border = Border(
    left=Side(style='thin', color='D9D9D9'),
    right=Side(style='thin', color='D9D9D9'),
    top=Side(style='thin', color='D9D9D9'),
    bottom=Side(style='thin', color='D9D9D9')
)

# ----------------- Sheet 1: Backend & Cloud Databases -----------------
ws1 = wb.active
ws1.title = 'Cloud_DB_and_APIs'

headers1 = ['Category', 'Component / Service', 'Endpoint URL / Resource', 'Protocol / Format', 'File Reference in Code', 'Dashboard / Management Portal', 'Description']
ws1.append(headers1)

data1 = [
    [
        'Production Database',
        'Firebase Realtime Database',
        'https://nearfix-default-rtdb.firebaseio.com',
        'HTTPS REST JSON (/providers.json, /residents.json)',
        'lib/config/firebase_config.dart',
        'https://console.firebase.google.com',
        'Primary production database. Free tier gives 1GB storage & 10GB/month bandwidth. Auto-scales with Google Cloud.'
    ],
    [
        'Production Gateway',
        'Active Cloudflare HTTPS Tunnel',
        'https://dinner-presented-flooring-flight.trycloudflare.com/api',
        'HTTPS REST API (/api/providers, /api/residents)',
        'lib/config/firebase_config.dart',
        'https://dash.cloudflare.com',
        'High-speed global HTTPS gateway connecting the Flutter app to backend servers across 4G/5G mobile carriers and Wi-Fi.'
    ],
    [
        'Fallback Database',
        'CrudCrud REST DB',
        'https://crudcrud.com/api/ef6f54350240430e86a05c8af3b6498f',
        'HTTPS REST JSON',
        'lib/config/firebase_config.dart',
        'https://crudcrud.com',
        'Secondary backup cloud endpoint for rapid storage fallback.'
    ],
    [
        'Local Admin Server',
        'Localhost Python Server',
        'http://localhost:5000/api',
        'HTTP REST JSON',
        'admin_portal/server.py',
        'http://localhost:5000',
        'Local developer backend and admin portal server running on port 5000.'
    ],
    [
        'Local JSON Database',
        'Local Database File',
        'admin_portal/cloud_db.json',
        'JSON File',
        'admin_portal/cloud_db.json',
        'Local Filesystem',
        'Persistent file storing technician directory (Palvancha, Bengaluru, Hyderabad), residents, and ratings.'
    ]
]

for row in data1:
    ws1.append(row)

# ----------------- Sheet 2: API Keys & Gateways -----------------
ws2 = wb.create_sheet(title='API_Keys_and_SMS')

headers2 = ['Service', 'Type', 'Key / Credential Value', 'Portal / Purchase Link', 'Configured File', 'Notes & Pricing']
ws2.append(headers2)

data2 = [
    [
        'Firebase Phone Auth',
        'Google Telecom SMS Gateway',
        '10,000 Free SMS / Month (Identity Toolkit API)',
        'https://console.firebase.google.com',
        'lib/services/sms_service.dart',
        'Primary recommended authentication gateway. Provides 10,000 free real carrier SMS verifications every month globally with zero cost.'
    ],
    [
        'Master Test OTP',
        'Bypass OTP',
        '112233',
        'Built into Flutter Application',
        'lib/state/nearfix_state.dart',
        'Works instantly for any mobile number without consuming SMS credits or incurring gateway costs.'
    ],
    [
        'Fast2SMS',
        'Indian SMS Gateway API Key',
        'dIc1LzfVBHkEPuq8htso6YenWy25SCMDpKJ4UGQaglmi0FAxj3epD8fQYq35HkKnLMl2NojBPO1UZSRa',
        'https://www.fast2sms.com',
        'lib/services/sms_service.dart',
        'Primary Indian SMS gateway fallback for direct OTP dispatch to +91 numbers.'
    ],
    [
        '2Factor.in',
        'Backup SMS / Voice OTP',
        'c22862fa-ab7c-11f1-9cb1-0200cd936042',
        'https://2factor.in',
        'lib/services/sms_service.dart',
        'Secondary backup Indian SMS delivery gateway.'
    ],
    [
        'Google Gemini AI',
        'AI Assistant API Key',
        'gemini-1.5-flash (In-App Configurable)',
        'https://aistudio.google.com',
        'lib/services/gemini_service.dart',
        'Powers Colony AI Smart Issue Diagnostics. Free tier provides 15 Requests Per Minute and 1,500 free requests per day.'
    ]
]

for row in data2:
    ws2.append(row)

# ----------------- Sheet 3: Android & Play Store Config -----------------
ws3 = wb.create_sheet(title='Android_PlayStore_Config')

headers3 = ['Setting / Parameter', 'Configured Value', 'File Location', 'Google Play Store Note']
ws3.append(headers3)

data3 = [
    [
        'Package Name / Application ID',
        'com.nearfix.app.nearfix',
        'android/app/build.gradle',
        'Unique package ID for Google Play Console listing.'
    ],
    [
        'App Version & Build',
        '1.0.0+1 (Version 1.0.0, Build 1)',
        'pubspec.yaml',
        'Increment build number for each subsequent Play Store release.'
    ],
    [
        'Min Android SDK',
        'API 21 (Android 5.0 Lollipop)',
        'android/app/build.gradle',
        'Compatible with 99.5%+ of all active Android devices worldwide.'
    ],
    [
        'Target Android SDK',
        'API 34 / 35 (Android 14 / 15)',
        'android/app/build.gradle',
        'Complies with latest Google Play Store API level requirements.'
    ],
    [
        'Network Security Policy',
        'android:usesCleartextTraffic="false" (Strict HTTPS)',
        'android/app/src/main/AndroidManifest.xml',
        'Mandatory security policy for Google Play Store compliance.'
    ],
    [
        'Keystore Signing Template',
        'android/key.properties.example',
        'android/key.properties.example',
        'Template for upload-keystore.jks signing passwords.'
    ],
    [
        'Production Bundle Command',
        'flutter build appbundle --release',
        'Terminal',
        'Builds app-release.aab for Google Play Console release.'
    ]
]

for row in data3:
    ws3.append(row)

# ----------------- Sheet 4: Scaling & Cloud Hosting Options -----------------
ws4 = wb.create_sheet(title='Scaling_and_Hosting_Guide')

headers4 = ['Hosting Option', 'Estimated Monthly Cost', 'Free Tier Quota', 'Scaling Limit', 'Setup URL / Instructions']
ws4.append(headers4)

data4 = [
    [
        'Firebase Realtime Database (Google Cloud)',
        'Free up to 1GB / $25 per 50GB',
        '1 GB stored data, 10 GB/month download, 100 simultaneous connections',
        '100,000+ simultaneous connections, multi-gigabyte capacity',
        'https://console.firebase.google.com -> Create RTDB -> Set rules -> Paste URL in NearFix App'
    ],
    [
        'Render.com (Python Server Hosting)',
        'Free Tier / $7 per month (Starter)',
        '750 free instance hours per month',
        'Auto-scaling web services with custom domains & SSL',
        'https://render.com -> New Web Service -> Connect Git repo -> Deploy admin_portal/server.py'
    ],
    [
        'Railway.app (Container / Backend)',
        '$5 per month usage credit',
        '$5/month free credit',
        'Scales CPU & Memory automatically on demand',
        'https://railway.app -> Deploy server.py'
    ],
    [
        'Fast2SMS Gateway Re-charge',
        '₹100 for ~500 SMS / ₹0.20 per SMS',
        'Free test credits upon signup',
        'Millions of SMS/day bulk DLT/Quick SMS',
        'https://www.fast2sms.com/dashboard/billing -> Add Wallet Balance'
    ],
    [
        'Google Gemini AI (Google AI Studio)',
        'Free Tier / Pay-as-you-go ($0.075 per 1M tokens)',
        '15 RPM (Requests per minute) free forever',
        '1,000+ RPM on paid tier (cents per month for colony app)',
        'https://aistudio.google.com/app/apikey -> Create Key'
    ]
]

for row in data4:
    ws4.append(row)

# Apply formatting across all sheets
for ws in wb.worksheets:
    ws.views.sheetView[0].showGridLines = True
    
    # Format header row
    for col_idx in range(1, ws.max_column + 1):
        cell = ws.cell(row=1, column=col_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
    ws.row_dimensions[1].height = 28
    
    # Format data rows
    for row_idx in range(2, ws.max_row + 1):
        ws.row_dimensions[row_idx].height = 22
        for col_idx in range(1, ws.max_column + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.font = regular_font
            cell.border = thin_border
            cell.alignment = Alignment(vertical='center', wrap_text=True)
            if col_idx == 1:
                cell.font = bold_font
    
    # Auto-adjust column widths
    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            val_str = str(cell.value or '')
            if len(val_str) > max_len:
                max_len = len(val_str)
        ws.column_dimensions[col_letter].width = min(max(max_len + 4, 14), 50)

# Save Excel files in workspace, admin portal, and artifact directory
wb.save('NearFix_Backend_Credentials_and_APIs.xlsx')
os.makedirs('admin_portal', exist_ok=True)
wb.save('admin_portal/NearFix_Backend_Credentials_and_APIs.xlsx')
artifact_path = r'C:\Users\user\.gemini\antigravity-ide\brain\cb5afe2d-ece2-4900-8bb3-358922b3f720\NearFix_Backend_Credentials_and_APIs.xlsx'
try:
    wb.save(artifact_path)
except Exception:
    pass

print('Excel spreadsheet created successfully!')


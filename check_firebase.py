import requests, json

url = 'https://nearslay-default-rtdb.firebaseio.com/.json'
try:
    r = requests.get(url, timeout=5)
    print('Rules check status:', r.status_code)
    if r.status_code == 200:
        print('[SUCCESS] Firebase Database is unlocked and ready!')
    elif r.status_code == 401:
        print('[ACTION REQUIRED] Security rules are still locked. Please update the Rules tab in Firebase Console.')
    else:
        print('Status:', r.status_code, r.text)
except Exception as e:
    print('Connection error:', e)

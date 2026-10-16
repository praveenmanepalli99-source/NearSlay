import urllib.request
import json
import time

def run():
    print("Testing End-to-End Registration & Cloud DB Sync...")
    
    # 1. Post new resident via Public Cloud API
    res_payload = {
        "id": "user_test_sync_99",
        "name": "Ananya Reddy",
        "phone": "+91 9888877777",
        "avatarUrl": "",
        "colonyId": "colony_ktps",
        "colonyName": "KTPS",
        "city": "Palvancha",
        "flatAddress": "Flat 402, Block B"
    }
    
    req1 = urllib.request.Request(
        "https://keep-xml-tribe-trusts.trycloudflare.com/api/residents",
        data=json.dumps(res_payload).encode('utf-8'),
        headers={"Content-Type": "application/json", "Accept": "application/json"}
    )
    with urllib.request.urlopen(req1, timeout=6) as r1:
        print(f"1. Resident posted via Cloud API -> Status: {r1.status}")
    
    # 2. Post new provider via CrudCrud endpoint
    prov_payload = {
        "id": "prov_test_sync_88",
        "name": "Naveen Electricals",
        "category": "electrician",
        "categoryTitle": "Electrician",
        "hourlyRate": 350,
        "colonyId": "colony_ktps",
        "colonyName": "KTPS",
        "city": "Palvancha",
        "realPhone": "+91 9777766666",
        "maskedVirtualNumber": "+91 80 4710 9999",
        "isAvailable": True,
        "isVerified": True,
        "rating": 5.0,
        "reviewsCount": 1,
        "bio": "Certified commercial & residential electrician"
    }
    
    req2 = urllib.request.Request(
        "https://crudcrud.com/api/a464e61dc3f743768f2ce0831b5a469d/providers",
        data=json.dumps(prov_payload).encode('utf-8'),
        headers={"Content-Type": "application/json", "Accept": "application/json"}
    )
    with urllib.request.urlopen(req2, timeout=6) as r2:
        print(f"2. Provider posted via CrudCrud -> Status: {r2.status}")
        
    print("Waiting 4 seconds for background thread to sync CrudCrud to cloud_db.json...")
    time.sleep(4)
    
    # 3. Check stats from Public Cloud API
    req3 = urllib.request.Request("https://keep-xml-tribe-trusts.trycloudflare.com/api/stats")
    with urllib.request.urlopen(req3, timeout=6) as r3:
        stats = json.loads(r3.read().decode('utf-8'))
        print("\n--- Current Cloud DB Stats ---")
        print(f"Total Users: {stats['totalUsers']}")
        print(f"Providers: {stats['providersCount']}")
        print(f"Residents: {stats['residentsCount']}")
        
        resident_names = [r.get('name') for r in stats['residents']]
        provider_names = [p.get('name') for p in stats['providers']]
        print(f"Found Resident 'Ananya Reddy': {'Ananya Reddy' in resident_names}")
        print(f"Found Provider 'Naveen Electricals': {'Naveen Electricals' in provider_names}")

if __name__ == '__main__':
    run()

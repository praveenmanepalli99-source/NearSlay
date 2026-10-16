import urllib.request
import json
import re

def test():
    # 1. Fetch live CrudCrud endpoint
    try:
        req = urllib.request.Request('https://crudcrud.com', headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as res:
            html = res.read().decode('utf-8')
            match = re.search(r'https://crudcrud\.com/api/([a-f0-9]{32})', html)
            if match:
                ep = match.group(1)
                print(f"Discovered Live CrudCrud Endpoint: {ep}")
                
                # Test POST provider
                post_req = urllib.request.Request(
                    f"https://crudcrud.com/api/{ep}/providers",
                    data=json.dumps({"id": "test_prov_1", "name": "Test Technician", "realPhone": "+91 9999900001"}).encode('utf-8'),
                    headers={"Content-Type": "application/json", "Accept": "application/json"}
                )
                with urllib.request.urlopen(post_req, timeout=5) as post_res:
                    print(f"CrudCrud POST status: {post_res.status}")
                
                # Test GET providers
                get_req = urllib.request.Request(f"https://crudcrud.com/api/{ep}/providers", headers={"Accept": "application/json"})
                with urllib.request.urlopen(get_req, timeout=5) as get_res:
                    print(f"CrudCrud GET response: {get_res.read().decode('utf-8')}")
    except Exception as e:
        print(f"CrudCrud error: {e}")

    # 2. Test Local Server
    try:
        req = urllib.request.Request('http://127.0.0.1:5000/api/stats')
        with urllib.request.urlopen(req, timeout=3) as res:
            print(f"Local stats status: {res.status}")
            print(f"Local stats response: {res.read().decode('utf-8')[:200]}")
    except Exception as e:
        print(f"Local server error: {e}")

if __name__ == '__main__':
    test()

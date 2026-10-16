"""
NearFix Bulk Service Provider Import Utility
---------------------------------------------
Reads service providers from a CSV / Excel file and imports/upserts them
directly into the NearFix Cloud Database (admin_portal/cloud_db.json).

Usage:
    python import_providers.py
    python import_providers.py my_providers.csv
"""

import os
import sys
import csv
import json
import random
import time

# Known colony coordinate fallback mappings
COLONY_COORDS = {
    "ktps": {"lat": 17.5980, "lng": 80.6970, "city": "Palvancha"},
    "palvancha": {"lat": 17.5980, "lng": 80.6970, "city": "Palvancha"},
    "kukatpally": {"lat": 17.4849, "lng": 78.4138, "city": "Hyderabad"},
    "hyderabad": {"lat": 17.4849, "lng": 78.4138, "city": "Hyderabad"},
    "green glen layout": {"lat": 12.9298, "lng": 77.6749, "city": "Bengaluru"},
    "bellandur": {"lat": 12.9298, "lng": 77.6749, "city": "Bengaluru"},
    "indiranagar": {"lat": 12.9784, "lng": 77.6408, "city": "Bengaluru"},
    "bengaluru": {"lat": 12.9784, "lng": 77.6408, "city": "Bengaluru"},
    "koramangala": {"lat": 12.9352, "lng": 77.6245, "city": "Bengaluru"},
    "whitefield": {"lat": 12.9698, "lng": 77.7500, "city": "Bengaluru"},
}

CATEGORY_TITLES = {
    "plumber": "Plumber",
    "electrician": "Electrician",
    "carpenter": "Carpenter",
    "painter": "Painter",
    "catering": "Catering",
    "dj_sound": "DJ & Sound System",
    "ac_repair": "AC Repair & Service",
    "appliance_repair": "Appliance Repair",
    "cleaning": "Home Cleaning",
    "gardening": "Gardening & Lawn Care",
    "ro_service": "RO & Water Purifier",
    "mechanic": "Bike & Car Mechanic",
    "doctor": "Doctor",
    "hotel": "Hotel",
    "restaurant": "Restaurant",
    "decoration": "Decoration",
    "tent_house": "Tent House",
    "other": "General Handyman"
}

CATEGORY_PHOTOS = {
    "plumber": "https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200",
    "electrician": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200",
    "carpenter": "https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200",
    "painter": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200",
    "catering": "https://images.unsplash.com/photo-1555244162-803834f70033?w=200",
    "dj_sound": "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=200",
    "ac_repair": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200",
    "appliance_repair": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200",
    "cleaning": "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200",
    "gardening": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200",
    "ro_service": "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200",
    "mechanic": "https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=200",
    "other": "https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200"
}

def clean_phone(phone_str):
    digits = ''.join(c for c in str(phone_str) if c.isdigit())
    if len(digits) >= 10:
        digits = digits[-10:]
    return f"+91 {digits}" if digits else ""

def generate_masked_number():
    d1 = random.randint(1000, 9999)
    d2 = random.randint(1000, 9999)
    return f"+91 80 {d1} {d2}"

def import_providers_from_csv(csv_path="service_providers_template.csv"):
    if not os.path.exists(csv_path):
        print(f"❌ Error: File '{csv_path}' not found.")
        return 0

    db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "admin_portal", "cloud_db.json")
    
    if os.path.exists(db_path):
        with open(db_path, "r", encoding="utf-8") as f:
            try:
                db = json.load(f)
            except Exception:
                db = {"providers": [], "residents": []}
    else:
        db = {"providers": [], "residents": []}

    existing_providers = db.get("providers", [])
    
    # Read CSV
    imported_count = 0
    updated_count = 0

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Clean keys (trim whitespace)
            clean_row = {k.strip(): v.strip() for k, v in row.items() if k}
            
            name = clean_row.get("Name") or clean_row.get("name") or ""
            raw_phone = clean_row.get("Phone") or clean_row.get("phone") or clean_row.get("Mobile") or ""
            cat_key = (clean_row.get("Category") or clean_row.get("category") or "other").lower().replace(" ", "_")
            rate_str = clean_row.get("HourlyRate") or clean_row.get("hourlyRate") or clean_row.get("Rate") or "250"
            colony = clean_row.get("ColonyName") or clean_row.get("colonyName") or clean_row.get("Colony") or "KTPS"
            city = clean_row.get("City") or clean_row.get("city") or "Palvancha"
            bio = clean_row.get("Bio") or clean_row.get("bio") or ""
            lat_str = clean_row.get("Latitude") or clean_row.get("latitude") or ""
            lng_str = clean_row.get("Longitude") or clean_row.get("longitude") or ""
            avail_str = (clean_row.get("Available") or clean_row.get("available") or "true").lower()
            is_available = avail_str in ("true", "1", "yes", "y")

            if not name or not raw_phone:
                continue

            phone = clean_phone(raw_phone)
            phone_digits = ''.join(c for c in phone if c.isdigit())[-10:]

            try:
                rate = int(float(rate_str))
            except Exception:
                rate = 250

            # Determine Coordinates
            lat = 0.0
            lng = 0.0
            try:
                if lat_str:
                    lat = float(lat_str)
                if lng_str:
                    lng = float(lng_str)
            except Exception:
                pass

            if lat == 0.0 or lng == 0.0:
                lookup = colony.lower().strip()
                if lookup in COLONY_COORDS:
                    lat = COLONY_COORDS[lookup]["lat"]
                    lng = COLONY_COORDS[lookup]["lng"]
                    if not city:
                        city = COLONY_COORDS[lookup]["city"]
                else:
                    # Default Palvancha
                    lat = 17.5980
                    lng = 80.6970

            category_title = CATEGORY_TITLES.get(cat_key, cat_key.replace("_", " ").title())
            avatar = CATEGORY_PHOTOS.get(cat_key, "https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200")

            if not bio:
                bio = f"Experienced {category_title.lower()} providing service in {colony}, {city}."

            colony_id = f"colony_{abs(hash(colony.lower())) % 1000000000}"

            # Check if provider already exists by phone
            existing_idx = -1
            for i, p in enumerate(existing_providers):
                p_digits = ''.join(c for c in str(p.get("realPhone", "")) if c.isdigit())[-10:]
                if p_digits == phone_digits:
                    existing_idx = i
                    break

            if existing_idx >= 0:
                # Update existing provider record
                p = existing_providers[existing_idx]
                p["name"] = name
                p["category"] = cat_key
                p["categoryTitle"] = category_title
                p["hourlyRate"] = rate
                p["colonyName"] = colony
                p["colonyId"] = colony_id
                p["city"] = city
                p["latitude"] = lat
                p["longitude"] = lng
                p["bio"] = bio
                p["isAvailable"] = is_available
                existing_providers[existing_idx] = p
                updated_count += 1
                print(f"[UPDATED] {name} ({phone}) - {category_title} in {colony}")
            else:
                # Insert new provider
                new_p = {
                    "id": f"prov_{int(time.time() * 1000)}_{random.randint(100, 999)}",
                    "name": name,
                    "avatarUrl": avatar,
                    "category": cat_key,
                    "categoryTitle": category_title,
                    "hourlyRate": rate,
                    "colonyId": colony_id,
                    "colonyName": colony,
                    "city": city,
                    "latitude": lat,
                    "longitude": lng,
                    "distanceMeters": 250,
                    "isAvailable": is_available,
                    "isVerified": True,
                    "realPhone": phone,
                    "maskedVirtualNumber": generate_masked_number(),
                    "rating": 5.0,
                    "reviewsCount": 1,
                    "bio": bio
                }
                existing_providers.insert(0, new_p)
                imported_count += 1
                print(f"[ADDED] {name} ({phone}) - {category_title} in {colony}")

    # Save to cloud DB
    db["providers"] = existing_providers
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)

    print("\n" + "="*50)
    print(f"Import Complete!")
    print(f"   - Added New: {imported_count}")
    print(f"   - Updated Existing: {updated_count}")
    print(f"   - Total Providers in Database: {len(existing_providers)}")
    print("="*50 + "\n")
    return imported_count + updated_count

if __name__ == "__main__":
    csv_file = sys.argv[1] if len(sys.argv) > 1 else "service_providers_template.csv"
    import_providers_from_csv(csv_file)

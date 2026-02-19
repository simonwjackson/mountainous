#!/usr/bin/env python3
import kroger
import json

store = "62000082"
searches = [
    "organic eggs",
    "organic bacon",
    "organic ground beef",
    "organic chicken thighs",
    "organic butter",
    "organic cream cheese",
    "organic heavy cream",
    "organic avocado",
    "organic baby spinach",
    "organic broccoli",
    "organic cheddar cheese",
    "organic sour cream",
    "organic almonds",
    "avocado oil",
    "organic mozzarella cheese",
    "organic cauliflower",
]

picks = []
for term in searches:
    data = kroger.api_get("/products", params={
        "filter.term": term,
        "filter.locationId": store,
        "filter.limit": 5,
    })
    prods = data.get("data", [])
    if prods:
        p = prods[0]
        desc = p.get("description", "N/A")
        upc = p.get("upc", "")
        items_data = p.get("items", [{}])
        price_info = items_data[0].get("price", {}) if items_data else {}
        regular = price_info.get("regular", "?")
        promo = price_info.get("promo")
        size = items_data[0].get("size", "") if items_data else ""
        price_str = f"${regular}"
        if promo:
            price_str += f" (sale: ${promo})"
        picks.append({"term": term, "upc": upc, "desc": desc, "size": size, "price": price_str, "regular": regular})
        print(f"✓ {term}: {desc} | {size} | {price_str}")
    else:
        print(f"✗ {term}: no results")

print("\n--- SUMMARY ---")
total = 0
for p in picks:
    try:
        total += float(p["regular"])
    except (ValueError, TypeError):
        pass
    print(f"  {p['upc']} | {p['desc']} | {p['size']} | {p['price']}")

print(f"\nEstimated total: ${total:.2f}")
print(f"\nUPCs for cart: {json.dumps([{'upc': p['upc'], 'quantity': 1} for p in picks])}")

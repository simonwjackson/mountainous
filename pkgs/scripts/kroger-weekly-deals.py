#!/usr/bin/env python3
"""Scan King Soopers for keto-friendly sale items and report the best deals."""
import kroger
import json

store = "62000082"

keto_searches = [
    "organic eggs",
    "organic bacon",
    "organic ground beef",
    "organic chicken",
    "organic pork",
    "organic butter",
    "organic cheese",
    "organic heavy cream",
    "organic cream cheese",
    "organic sour cream",
    "organic avocado",
    "organic spinach",
    "organic broccoli",
    "organic cauliflower",
    "organic kale",
    "organic almonds",
    "organic pecans",
    "organic walnuts",
    "avocado oil",
    "olive oil organic",
    "organic coconut oil",
    "organic whole chicken",
    "organic salmon",
    "organic steak",
    "organic sausage",
]

deals = []
seen_upcs = set()

for term in keto_searches:
    data = kroger.api_get("/products", params={
        "filter.term": term,
        "filter.locationId": store,
        "filter.limit": 8,
    })
    for p in data.get("data", []):
        upc = p.get("upc", "")
        if upc in seen_upcs:
            continue
        seen_upcs.add(upc)
        items_data = p.get("items", [{}])
        price_info = items_data[0].get("price", {}) if items_data else {}
        promo = price_info.get("promo")
        regular = price_info.get("regular")
        if promo and regular:
            try:
                savings = float(regular) - float(promo)
                pct = (savings / float(regular)) * 100
            except (ValueError, TypeError):
                continue
            desc = p.get("description", "")
            size = items_data[0].get("size", "") if items_data else ""
            deals.append({
                "upc": upc,
                "desc": desc,
                "size": size,
                "regular": regular,
                "promo": promo,
                "savings": savings,
                "pct": pct,
            })

# Sort by savings percentage
deals.sort(key=lambda x: x["pct"], reverse=True)

if not deals:
    print("No keto sales found this week.")
else:
    print(f"🔥 {len(deals)} keto-friendly items on sale at King Soopers this week:\n")
    for d in deals:
        print(f"  {d['desc']}")
        print(f"    {d['size']} | ${d['regular']} → ${d['promo']} ({d['pct']:.0f}% off, save ${d['savings']:.2f})")
        print()

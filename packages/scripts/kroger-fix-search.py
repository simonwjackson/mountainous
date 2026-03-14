#!/usr/bin/env python3
import kroger, json

store = "62000082"

# Re-search items that matched wrong products
fixes = [
    "organic cream cheese block",
    "organic sour cream",
    "organic raw almonds",
    "organic mozzarella block cheese",
    "organic chicken thighs",
    "organic bacon",
]

for term in fixes:
    data = kroger.api_get("/products", params={
        "filter.term": term,
        "filter.locationId": store,
        "filter.limit": 8,
    })
    prods = data.get("data", [])
    print(f"\n=== {term} ===")
    for p in prods:
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
        print(f"  {upc} | {desc} | {size} | {price_str}")

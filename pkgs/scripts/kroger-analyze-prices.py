#!/usr/bin/env python3
"""Analyze cart items: find cheaper alternatives, sale items, store brand swaps."""
import kroger, json

store = "62000082"

# What we bought and what we paid
cart = [
    {"upc": "0001111079771", "qty": 2, "name": "Organic Eggs 12ct", "paid": 4.99},
    {"upc": "0001111003491", "qty": 2, "name": "ST Uncured Bacon 12oz", "paid": 5.00},  # sale price
    {"upc": "0001111096896", "qty": 2, "name": "ST Organic Ground Beef 1lb", "paid": 8.49},  # sale
    {"upc": "0020095850000", "qty": 3, "name": "ST Organic Chicken Thighs 1lb", "paid": 6.99},  # sale
    {"upc": "0086231500027", "qty": 1, "name": "Vital Farms Butter", "paid": 8.49},
    {"upc": "0009396600028", "qty": 1, "name": "OV Heavy Cream 1pt", "paid": 7.29},
    {"upc": "0009396611320", "qty": 1, "name": "OV Raw Sharp Cheddar 8oz", "paid": 8.99},
    {"upc": "0074236500772", "qty": 1, "name": "Horizon Mozz String Cheese 8ct", "paid": 6.99},
    {"upc": "0001111013010", "qty": 1, "name": "ST Sour Cream 16oz", "paid": 2.89},
    {"upc": "0000000094046", "qty": 4, "name": "Organic Avocado", "paid": 2.00},  # estimate
    {"upc": "0001111091151", "qty": 1, "name": "ST Organic Baby Spinach 16oz", "paid": 5.00},
    {"upc": "0001111011601", "qty": 1, "name": "ST Organic Frozen Broccoli 32oz", "paid": 8.99},
    {"upc": "0001111012986", "qty": 1, "name": "Avocado Oil 17oz", "paid": 9.99},
    {"upc": "0001111063772", "qty": 1, "name": "ST Organic Raw Almonds 8oz", "paid": 5.99},  # sale
    {"upc": "0000000094079", "qty": 1, "name": "Organic Cauliflower", "paid": 3.99},
]

total = sum(i["paid"] * i["qty"] for i in cart)
print(f"Current weekly spend estimate: ${total:.2f}\n")

# Now search for cheaper alternatives and on-sale items
print("=== BIGGEST COST ITEMS (per unit × qty) ===")
sorted_cart = sorted(cart, key=lambda x: x["paid"] * x["qty"], reverse=True)
for item in sorted_cart:
    line = item["paid"] * item["qty"]
    print(f"  ${line:6.2f}  {item['name']} (${item['paid']} × {item['qty']})")

# Search for items currently on sale that are keto-friendly
print("\n=== SEARCHING FOR ON-SALE KETO STAPLES ===")
sale_searches = [
    "organic eggs sale",
    "organic ground beef",
    "organic chicken",
    "organic butter",
    "organic cheese",
    "organic heavy cream",
    "organic avocado",
    "organic spinach",
    "pork shoulder",
    "organic whole chicken",
]

for term in sale_searches:
    data = kroger.api_get("/products", params={
        "filter.term": term,
        "filter.locationId": store,
        "filter.limit": 5,
    })
    for p in data.get("data", []):
        items_data = p.get("items", [{}])
        price_info = items_data[0].get("price", {}) if items_data else {}
        promo = price_info.get("promo")
        if promo:  # only show items on sale
            regular = price_info.get("regular", "?")
            desc = p.get("description", "")
            size = items_data[0].get("size", "") if items_data else ""
            savings = float(regular) - float(promo) if regular != "?" else 0
            print(f"  SALE: {desc} | {size} | ${regular} → ${promo} (save ${savings:.2f})")

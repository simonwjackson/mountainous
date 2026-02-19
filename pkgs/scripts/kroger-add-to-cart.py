#!/usr/bin/env python3
import kroger, json

# Weekly keto cart - organic first
cart_items = [
    # Protein
    {"upc": "0001111079771", "quantity": 2, "note": "Organic Free Range Eggs 12ct x2"},
    {"upc": "0001111003491", "quantity": 2, "note": "Simple Truth No Sugar Uncured Bacon 12oz x2"},
    {"upc": "0001111096896", "quantity": 2, "note": "Simple Truth Organic Grass Fed Ground Beef 1lb x2"},
    {"upc": "0020095850000", "quantity": 3, "note": "Simple Truth Organic Chicken Thighs 1lb x3"},

    # Dairy/Fat
    {"upc": "0086231500027", "quantity": 1, "note": "Vital Farms Grass-Fed Butter"},
    {"upc": "0009396600028", "quantity": 1, "note": "Organic Valley Heavy Whipping Cream 1pt"},
    {"upc": "0009396611320", "quantity": 1, "note": "Organic Valley Raw Sharp Cheddar 8oz"},
    {"upc": "0074236500772", "quantity": 1, "note": "Horizon Organic Mozzarella String Cheese 8ct"},
    {"upc": "0001111013010", "quantity": 1, "note": "Simple Truth Sour Cream 16oz"},

    # Vegetables
    {"upc": "0000000094046", "quantity": 4, "note": "Organic Avocado x4"},
    {"upc": "0001111091151", "quantity": 1, "note": "Simple Truth Organic Baby Spinach 16oz"},
    {"upc": "0001111011601", "quantity": 1, "note": "Simple Truth Organic Frozen Broccoli 32oz"},
    {"upc": "0000000094079", "quantity": 1, "note": "Organic Cauliflower"},

    # Pantry
    {"upc": "0001111012986", "quantity": 1, "note": "Private Selection Avocado Oil 17oz"},
    {"upc": "0001111063772", "quantity": 1, "note": "Simple Truth Organic Raw Almonds 8oz"},
]

print("Adding to cart:")
for item in cart_items:
    print(f"  {item['note']}")

# Add all at once
body = {"items": [{"upc": i["upc"], "quantity": i["quantity"]} for i in cart_items]}
token = kroger.get_token(need_user=True)
import requests
r = requests.put(
    f"{kroger.BASE_URL}/cart/add",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    },
    json=body
)
print(f"\nHTTP {r.status_code}")
if r.status_code < 300:
    print("✓ All items added to your King Soopers cart!")
else:
    print(f"Error: {r.text}")

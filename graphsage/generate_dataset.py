"""
Synthetic e-commerce graph dataset generator for the GraphSAGE + Aura Graph
Analytics demo.

Produces two "waves" of data:
  1. A historical snapshot (customers, products, purchases, referrals) used
     to TRAIN a GraphSAGE model.
  2. A "next day" snapshot of brand-new customers and their first purchases,
     used to demonstrate INDUCTIVE inference: generating embeddings for
     nodes GraphSAGE has never seen, using the model stored in the Model
     Catalog, without retraining.

Output files (all CSV, written next to this script):
  customers.csv        - historical customers with numeric features
  products.csv          - product catalog with numeric features
  purchases.csv         - historical CUSTOMER -> PRODUCT purchases
  referrals.csv         - historical CUSTOMER -> CUSTOMER referrals
  new_customers.csv     - cold-start customers (unseen during training)
  new_purchases.csv     - their first purchases, connecting them into the graph
"""

import numpy as np
import pandas as pd

rng = np.random.default_rng(42)

CATEGORIES = ["electronics", "home", "outdoors", "beauty", "books", "toys", "grocery"]

N_CUSTOMERS = 500
N_PRODUCTS = 120
N_PURCHASES = 4000
N_REFERRALS = 300

N_NEW_CUSTOMERS = 50
N_NEW_PURCHASES = 260

# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------
category = rng.choice(CATEGORIES, size=N_PRODUCTS)
price = np.round(rng.lognormal(mean=3.2, sigma=0.8, size=N_PRODUCTS), 2)
# Zipf-ish popularity: a handful of products are purchased disproportionately often
popularity_rank = rng.permutation(N_PRODUCTS) + 1
popularity_score = np.round(1.0 / popularity_rank ** 0.6, 4)

products = pd.DataFrame({
    "productId": [f"P{i:04d}" for i in range(N_PRODUCTS)],
    "name": [f"{c.title()} Item {i}" for i, c in enumerate(category)],
    "category": category,
    "price": price,
    "popularityScore": popularity_score,
})

# ---------------------------------------------------------------------------
# Customers
# ---------------------------------------------------------------------------
age = rng.integers(18, 75, size=N_CUSTOMERS)
account_tenure_days = rng.integers(1, 1500, size=N_CUSTOMERS)
avg_session_minutes = np.round(rng.gamma(shape=2.0, scale=4.0, size=N_CUSTOMERS), 2)
marketing_opt_in = rng.integers(0, 2, size=N_CUSTOMERS)

customers = pd.DataFrame({
    "customerId": [f"C{i:04d}" for i in range(N_CUSTOMERS)],
    "name": [f"Customer {i}" for i in range(N_CUSTOMERS)],
    "age": age,
    "accountTenureDays": account_tenure_days,
    "avgSessionMinutes": avg_session_minutes,
    "marketingOptIn": marketing_opt_in,
})

# ---------------------------------------------------------------------------
# Purchases (weighted so popular products and higher-tenure customers buy more)
# ---------------------------------------------------------------------------
customer_weight = 0.3 + customers["accountTenureDays"].to_numpy() / customers["accountTenureDays"].max()
customer_weight = customer_weight / customer_weight.sum()

product_weight = products["popularityScore"].to_numpy()
product_weight = product_weight / product_weight.sum()

purchase_customers = rng.choice(customers["customerId"], size=N_PURCHASES, p=customer_weight)
purchase_products = rng.choice(products["productId"], size=N_PURCHASES, p=product_weight)

price_lookup = products.set_index("productId")["price"]
base_amount = price_lookup.loc[purchase_products].to_numpy()
amount = np.round(base_amount * rng.uniform(0.85, 1.15, size=N_PURCHASES), 2)
rating = rng.integers(1, 6, size=N_PURCHASES)
days_ago = rng.integers(1, 365, size=N_PURCHASES)

purchases = pd.DataFrame({
    "customerId": purchase_customers,
    "productId": purchase_products,
    "amount": amount,
    "rating": rating,
    "daysAgo": days_ago,
}).drop_duplicates(subset=["customerId", "productId"]).reset_index(drop=True)

# ---------------------------------------------------------------------------
# Referrals (CUSTOMER -> CUSTOMER), skewed toward long-tenure "power users"
# ---------------------------------------------------------------------------
referrer_weight = customer_weight  # reuse tenure-based weighting
referrers = rng.choice(customers["customerId"], size=N_REFERRALS, p=referrer_weight)
referees = rng.choice(customers["customerId"], size=N_REFERRALS)
referrals = pd.DataFrame({"referrerId": referrers, "refereeId": referees})
referrals = referrals[referrals["referrerId"] != referrals["refereeId"]].drop_duplicates().reset_index(drop=True)

# ---------------------------------------------------------------------------
# Cold-start batch: brand-new customers who sign up AFTER the model is trained
# ---------------------------------------------------------------------------
new_age = rng.integers(18, 75, size=N_NEW_CUSTOMERS)
new_tenure = rng.integers(0, 3, size=N_NEW_CUSTOMERS)  # they just joined
new_session = np.round(rng.gamma(shape=2.0, scale=4.0, size=N_NEW_CUSTOMERS), 2)
new_opt_in = rng.integers(0, 2, size=N_NEW_CUSTOMERS)

new_customers = pd.DataFrame({
    "customerId": [f"N{i:04d}" for i in range(N_NEW_CUSTOMERS)],
    "name": [f"New Customer {i}" for i in range(N_NEW_CUSTOMERS)],
    "age": new_age,
    "accountTenureDays": new_tenure,
    "avgSessionMinutes": new_session,
    "marketingOptIn": new_opt_in,
})

new_purchase_customers = rng.choice(new_customers["customerId"], size=N_NEW_PURCHASES)
new_purchase_products = rng.choice(products["productId"], size=N_NEW_PURCHASES, p=product_weight)
new_base_amount = price_lookup.loc[new_purchase_products].to_numpy()
new_amount = np.round(new_base_amount * rng.uniform(0.85, 1.15, size=N_NEW_PURCHASES), 2)
new_rating = rng.integers(1, 6, size=N_NEW_PURCHASES)
new_days_ago = rng.integers(0, 3, size=N_NEW_PURCHASES)

new_purchases = pd.DataFrame({
    "customerId": new_purchase_customers,
    "productId": new_purchase_products,
    "amount": new_amount,
    "rating": new_rating,
    "daysAgo": new_days_ago,
}).drop_duplicates(subset=["customerId", "productId"]).reset_index(drop=True)

# ---------------------------------------------------------------------------
# Write it all out
# ---------------------------------------------------------------------------
customers.to_csv("customers.csv", index=False)
products.to_csv("products.csv", index=False)
purchases.to_csv("purchases.csv", index=False)
referrals.to_csv("referrals.csv", index=False)
new_customers.to_csv("new_customers.csv", index=False)
new_purchases.to_csv("new_purchases.csv", index=False)

print("customers:", len(customers))
print("products:", len(products))
print("purchases:", len(purchases))
print("referrals:", len(referrals))
print("new_customers:", len(new_customers))
print("new_purchases:", len(new_purchases))

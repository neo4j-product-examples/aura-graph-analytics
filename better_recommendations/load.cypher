// === PREVENT DUPLICATES ===
CREATE CONSTRAINT product_id_unique IF NOT EXISTS
FOR (p:Product)
REQUIRE p.product_id IS UNIQUE;

// === 1. Load Users ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/order_history.csv' AS row
MERGE (u:User {user_id: toInteger(row.user_id)});

// === 2. Load Orders with properties ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/order_history.csv' AS row
MERGE (o:Order {order_id: toInteger(row.order_id)})
SET o.order_number = toInteger(row.order_number),
    o.eval_set = row.eval_set,
    o.order_dow = toInteger(row.order_dow),
    o.order_hour_of_day = toInteger(row.order_hour_of_day),
    o.days_since_prior_order = toFloat(row.days_since_prior_order);

// === 3. Connect Users to Orders ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/order_history.csv' AS row
MATCH (u:User {user_id: toInteger(row.user_id)})
MATCH (o:Order {order_id: toInteger(row.order_id)})
MERGE (u)-[:PLACED]->(o);

// === 4. Create Products with names ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/products.csv' AS row
MERGE (p:Product {product_id: toInteger(row.product_id)})
SET p.name = row.product_name;

// === 5. Load Aisles ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/aisles.csv' AS row
MERGE (a:Aisle {aisle_id: toInteger(row.aisle_id)})
SET a.name = row.aisle;

// === 6. Load Departments ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/departments.csv' AS row
MERGE (d:Department {department_id: toInteger(row.department_id)})
SET d.name = row.department;

// === 7. Connect Products → Aisles → Departments ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/products.csv' AS row
MATCH (p:Product {product_id: toInteger(row.product_id)})
MERGE (a:Aisle {aisle_id: toInteger(row.aisle_id)})
MERGE (d:Department {department_id: toInteger(row.department_id)})
MERGE (p)-[:IN_AISLE]->(a)
MERGE (a)-[:IN_DEPARTMENT]->(d);

// === 8. Link Orders to Products — use MATCH to avoid duplicate Products ===
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/retail/data/baskets.csv' AS row
MATCH (o:Order {order_id: toInteger(row.order_id)})
MATCH (p:Product {product_id: toInteger(row.product_id)})
MERGE (o)-[r:CONTAINS]->(p)
SET r.add_to_cart_order = toInteger(row.add_to_cart_order),
    r.reordered = toInteger(row.reordered);
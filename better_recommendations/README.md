# Building Better Recommendations

Recommendations are big business. Amazon reports that 35% of its revenue comes from recommendations. Even more surprisingly, Netflix and Youtube report that 75 and 70% of what people watch on their platforms comes from recommendations.

So how do we build a good recommendation engine? Well, follow along to find out!

## Set Up

You can (and likely should) use the data found in this repository for this tutorial. However, if you want to see how we created this data, see below:

> In order to recreate our data from scratch, start with the following [dataset](https://www.kaggle.com/datasets/yasserh/instacart-online-grocery-basket-analysis-dataset). Then use the `clean.R` script to safely sample your data down.

Next, use the following to load your data into AuraDB:

```cypher
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
```

Next, we are going to create a colab notebook that has everything we need to conduct our analysis. The rest of the tutorial will focus on what we can do using python. From here, you can follow along using the colab notebook in this repo.

Start by loading in the various packages

```
!pip install graphdatascience
```

```python
from graphdatascience.session import DbmsConnectionInfo, AlgorithmCategory, CloudLocation, GdsSessions, AuraAPICredentials
from datetime import timedelta
import pandas as pd
import os
from google.colab import userdata
```

### Authentication

You must first generate your credentials in Neo4j Aura. Afterwards, you can store your credentials securely using **colab secrets**.

```python
# For use in Google Colab
# This crediential is the Organization ID
TENANT_ID=userdata.get('TENANT_ID')

# These credentials were generated after the creation of the Aura Instance
NEO4J_URI = userdata.get('RETAIL_URI')
NEO4J_USERNAME = userdata.get('NEO4J_USER')
NEO4J_PASSWORD = userdata.get('RETAIL_PASSWORD')

# These credentials were generated after the creation of the API Endpoint
CLIENT_SECRET=userdata.get('CLIENT_SECRET')
CLIENT_ID=userdata.get('CLIENT_ID')
```

## Establishing a Session

Estimate resources based on graph size and create a session with a 2‑hour TTL.  

```python
sessions = GdsSessions(api_credentials=AuraAPICredentials(CLIENT_ID, CLIENT_SECRET, TENANT_ID))

session_name = "demo-session"
memory = sessions.estimate(
    node_count=1000, relationship_count=5000,
    algorithm_categories=[AlgorithmCategory.CENTRALITY, AlgorithmCategory.NODE_EMBEDDING],
)

db_connection_info = DbmsConnectionInfo(NEO4J_URI, NEO4J_USERNAME, NEO4J_PASSWORD)

# Initialize a GDS session scoped for 2 hours, sized to estimated graph
gds = sessions.get_or_create(
    session_name,
    memory=memory,
    db_connection=db_connection_info, # this is checking for a bolt server currently
    ttl=timedelta(hours=2),
)

print("GDS session initialized.")
```

## Our Data

We are going to be working with a dataset put together by instacart. It looks at different orders from a grocery store. We will use this to put together product recommendations.

Our data is currently in this format:
```
(User)-[PLACED]->(Order)-[CONTAINS]->(Product)-[IN_AISLE]->(Aisle)-[IN_DEPARTMENT]->(Department)
```
For our purposes, we are actually going to be working with a subset of this graph. We are going to create a co-purchase graph. Basically, we will see what items are purchased in the same market basket. Let's break down the query needed to generate this graph.

**For the inner projection:**

First, we find orders that contain two given products. We then add in a filter that ensures we don't have duplicate pairs. 

```cypher
MATCH (o:Order)-[:CONTAINS]->(p1:Product),
      (o)-[:CONTAINS]->(p2:Product)
WHERE p1.product_id < p2.product_id
```
We use `<` to ensure that we don't count each pair twice. So if we had Milk (id: 1) and Bread (id: 2), we get (1, 2) but not also (2, 1). 

Next, we count the number of times that combination occurs and save it as a float:
```python
WITH p1, p2, toFloat(COUNT(*)) AS weight
```
Finally, we return our values:
```python
RETURN p1 AS source, p2 AS target, weight
```
**For the outer projection:**
We first grab what we returned from the inner projection, starting with the start and end nodes for our new relationship:

```python
RETURN gds.graph.project.remote(
    source,
    target,
    {
    sourceNodeLabels: labels(source),
    targetNodeLabels: labels(target),
```
And then we give a name to the relationship:
```python
relationshipType: 'CO_PURCHASED_WITH',
```
And finally, we pull in our weight property. Because we named our count as weight in the triplet from the inner query (source, target, weight), we have to access it like so:
```python
relationshipProperties: {weight: weight}
```

So all together that looks like:

```python
if gds.graph.exists("copurchase")["exists"]:
    gds.graph.drop("copurchase")

query = """
CALL {
    MATCH (o:Order)-[:CONTAINS]->(p1:Product),
          (o)-[:CONTAINS]->(p2:Product)
    WHERE p1.product_id < p2.product_id
    WITH p1, p2, toFloat(COUNT(*)) AS weight
    RETURN p1 AS source, p2 AS target, weight
}
RETURN gds.graph.project.remote(
    source,
    target,
    {
        sourceNodeLabels: labels(source),
        targetNodeLabels: labels(target),
        relationshipType: 'CO_PURCHASED_WITH',
        relationshipProperties: {weight:weight} 
        }
    
);
"""

copurchase_graph, result = gds.graph.project(
    graph_name="copurchase",
    query=query
)
```

Next, we will run nodeSimilarity to see which products tend to be purchased together. Let's break down exactly what we are looking at. Imagine, if we had only three baskets:

| Basket | Products             |
|--------|----------------------|
| 1      | Eggs, Bread, Milk    |
| 2      | Bread, Milk, Butter  |
| 3      | Eggs, Bread, Butter  |

We can see that eggs tend to be purchased with bread, and that butter tends to be purchased with bread. So we can therefore say, eggs and butter are likely to be purchased together since they commonly share neighbors in their baskets (in this case bread). Items that share a lot of neighbors are considered to be similar to eachother. 

That's one half of how that algorithm works. Bread in the above example actually appears in every basket, so it really doesn't provide us that much information (since it is a shared neighbor with every item). Luckily, Node Similarity discounts items that have too many neighbors. 

Now imagine a case where:

| Basket | Products             |
|--------|----------------------|
| 1      | Eggs, Bread, Milk    |
| 2      | Bread, Milk, Butter  |
| 3      | Eggs, Bread, Butter  |
| 4      | Wine, Crackers, Bread  |
| 5      | Cheese, Crackers, Bread  |

The similarity between cheese and wine will largely be driven by the presence of crackers than bread because bread is mostly noise (and empty calories). Again, this is because bread is in every basket and therefore, its presence is not a good predictor of what other items will be in the basket. 

Enough talk, let's run the algorithm:

```python
result = gds.nodeSimilarity.write(
    copurchase_graph,
    topK=10,
    relationshipWeightProperty="weight",
    writeRelationshipType="SIMILAR_TO",
    writeProperty="score"
)
```

In our actual dataset, you'll notice that bananas are co-purchased with nearly everything — and for that reason, they mostly represent noise.

In fact, if you look at the ***\*least similar items\****, bananas often top the list. Why?

Because their presence in a basket doesn’t really signal that the customer wants any other specific item — they’re just a frequent, general-purpose purchase.

So while bananas are everywhere, they tell us almost nothing about co-purchase patterns — and `nodeSimilarity` correctly learns to ***\*downweight\**** them. And this is why using node similarity provides some value over simply looking at what items are co-purchased together the most. 

```python
query = """
MATCH (p1:Product)-[r:SIMILAR_TO]->(p2:Product)
RETURN p1.product_id AS product1_id, p1.name AS product1_name,
       p2.product_id AS product2_id, p2.name AS product2_name,
       r.score AS similarity_score
ORDER BY similarity_score 
LIMIT 10
"""

gds.run_cypher(query)
```

Finally, we end our session:

```python
sessions.delete(session_name=session_name)
```


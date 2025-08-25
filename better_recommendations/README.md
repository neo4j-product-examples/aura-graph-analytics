# Building Better Recommendations

Recommendations are big business. Amazon reports that 35% of its revenue comes from recommendations. Even more surprisingly, Netflix and YouTube report that 75% and 70% of what people watch on their platforms comes from recommendations. That means the majority of what we buy, watch, or even listen to is shaped by algorithms working quietly in the background.

But building a great recommendation engine isn’t just about throwing data into a model. It involves understanding user behavior, spotting patterns across millions of interactions, and surfacing just the right item at just the right time. The best systems feel almost magical — they seem to know what you want before you do.

We will be using Neo4j Aura Graph Analytics to build our recommendations. Graph powered recommendations go deeper than traditional methods because they intuitively model user behavior. 

In our example, we will be looking at co-purchasing behavior built off of data sampled from Instakart. We will discover how simply looking at items that are most frequently purchased together isn’t enough to build a good recommendation, and interestingly might cause us to recommend products that customers were already planning on buying without our intervention.

So how do we build a good recommendation engine? What techniques power these systems, and how can you start applying them yourself? Well, follow along to find out\!

## Set Up

Using the data found [here](https://github.com/neo4j-product-examples/aura-graph-analytics/tree/main/better_recommendations), load in your data into an AuraDB instance that has Graph Analytics installed using these [cypher statements](https://github.com/neo4j-product-examples/aura-graph-analytics/tree/main/better_recommendations).

Next, we are going to create a colab notebook that has everything we need to conduct our analysis. The rest of the tutorial will focus on what we can do using python. From here, you can follow along using the colab notebook in this repo.

Start by loading in the various packages

```
!pip install graphdatascience
```

```py
from graphdatascience.session import DbmsConnectionInfo, AlgorithmCategory, CloudLocation, GdsSessions, AuraAPICredentials
from datetime import timedelta
import pandas as pd
import os
from google.colab import userdata
```

### Authentication

You must first generate your credentials in Neo4j Aura. Afterwards, you can store your credentials securely using **colab secrets**.

```py
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

```py
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

For our purposes, we are actually going to be working with a subset of this graph. We are going to create a co-purchase graph. Basically, we will see what items are purchased in the same market basket. But before we do that, let's first take a look at the top items that are co-purchased together.

```py
query = """MATCH (o:Order)-[:CONTAINS]->(p1:Product),
      (o)-[:CONTAINS]->(p2:Product)
WHERE id(p1) < id(p2)
RETURN p1.name AS productA,
       p2.name AS productB,
       count(*) AS timesTogether
ORDER BY timesTogether DESC
LIMIT 5;"""

df = gds.run_cypher(query)
df
```

| productA | productB | timesTogether |
| ----- | ----- | ----- |
| Organic Baby Spinach | Banana | 24 |
| Bag of Organic Bananas | Organic Hass Avocado | 22 |
| Bag of Organic Bananas | Organic Strawberries | 19 |
| Banana | Organic Avocado | 16 |
| Organic Strawberries | Organic Hass Avocado | 15 |

You will notice that four out of five of the top co-purchased pairs include bananas. Logically, I suppose this means that grocery stores should nearly always recommend bananas to customers?

Let's keep working through and see if that holds up.

## Creating a Graph Projection

Now that we have a good idea of what's in our data, let's break down the query needed to generate a graph projection.

**For the inner projection:**

This will look pretty familiar to the query that we used to generate our co-purchase pairs. First, we find orders that contain two given products. We then add in a filter that ensures we don't have duplicate pairs.

```
MATCH (o:Order)-[:CONTAINS]->(p1:Product),
      (o)-[:CONTAINS]->(p2:Product)
WHERE p1.product_id < p2.product_id
```

We use `<` to ensure that we don't count each pair twice. So if we had Milk (id: 1\) and Bread (id: 2), we get (1, 2\) but not also (2, 1).

Next, we count the number of times that combination occurs and save it as a float:

```py
WITH p1, p2, toFloat(COUNT(*)) AS weight
```

Finally, we return our values:

```py
RETURN p1 AS source, p2 AS target, weight
```

**For the outer projection:** We first grab what we returned from the inner projection, starting with the start and end nodes for our new relationship:

```py
RETURN gds.graph.project.remote(
    source,
    target,
    {
    sourceNodeLabels: labels(source),
    targetNodeLabels: labels(target),
```

And then we give a name to the relationship:

```py
relationshipType: 'CO_PURCHASED_WITH',
```

And finally, we pull in our weight property. Because we named our count as weight in the triplet from the inner query (source, target, weight), we have to access it like so:

```py
relationshipProperties: {weight: weight}
```

So all together that looks like:

```py
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

## Node Similarity

Next, we will run `nodeSimilarity` to see which products tend to be purchased together. But before we do that, let's break down how this algorithm works. Imagine, if we had only three baskets:

| Basket | Products |
| :---- | :---- |
| 1 | Eggs, Bread, Milk |
| 2 | Bread, Milk, Butter |
| 3 | Eggs, Bread, Butter |

We can see that eggs tend to be purchased with bread, and that butter tends to be purchased with bread. So we can therefore say, eggs and butter are likely to be purchased together since they commonly share neighbors in their baskets (in this case bread). Items that share a lot of neighbors are considered to be similar to each other.

That's one half of how that algorithm works. Bread in the above example actually appears in every basket, so it really doesn't provide us that much information (since it is a shared neighbor with every item). Luckily, Node Similarity discounts items that have too many neighbors.

Now imagine a case where:

| Basket | Products |
| :---- | :---- |
| 1 | Eggs, Bread, Milk |
| 2 | Bread, Milk, Butter |
| 3 | Eggs, Bread, Butter |
| 4 | Wine, Crackers, Bread |
| 5 | Cheese, Crackers, Bread |

In this case, the similarity between cheese and wine will largely be driven by the presence of crackers rather than bread because bread is mostly noise (and empty calories). Again, this is because bread is in every basket and therefore, its presence is not a good predictor of what other items will be in the basket.

Enough talk, let's run the algorithm:

```py
result = gds.nodeSimilarity.write(
    copurchase_graph,
    topK=10,
    relationshipWeightProperty="weight",
    writeRelationshipType="SIMILAR_TO",
    writeProperty="score"
)
```

And then we look at our results:

```py
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

| product1\_id | product1\_name | product2\_id | product2\_name | similarity\_score |
| ----- | ----- | ----- | ----- | ----- |
| 41162 | Grapes Certified Organic California Black Seed... | 13176 | Bag of Organic Bananas | 0.000856 |
| 41605 | Chocolate Bar Milk Stevia Sweetened Salted Almond | 13176 | Bag of Organic Bananas | 0.000856 |
| 31478 | DairyFree Cheddar Style Wedges | 13176 | Bag of Organic Bananas | 0.000856 |
| 46900 | Organic Chicken Noodle Soup | 24852 | Banana | 0.000887 |
| 45265 | Raspberry on the Bottom NonFat Greek Yogurt | 24852 | Banana | 0.000887 |

In our actual dataset, you'll notice that bananas are co-purchased with nearly everything — and for that reason, they mostly represent noise.

In fact, if you look at the ***least similar items***, bananas often top the list. Why?

Because their presence in a basket doesn’t really signal that the customer wants any other specific item — they’re just a frequent, general-purpose purchase.

So while bananas are everywhere, they tell us almost nothing about co-purchase patterns — and `nodeSimilarity` correctly learns to ***downweight*** them. Plus, since bananas are in nearly every shopping cart, our theoretical customer was likely to buy them regardless of whether we recommended them. And this is why using node similarity provides some value over simply looking at what items are co-purchased together the most.

Finally, we end our session:

```py
sessions.delete(session_name=session_name)
```

And with that, you have learned how to build a better recommendation, one that goes deeper than simply looking at which items are frequently purchased together. From this, you can recommend interesting and unique products that your customers really want to buy.
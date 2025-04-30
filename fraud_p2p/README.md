# P2P Fraud

P2P fraud losses are skyrocketing. In 2023, 8% of banking customers reported being victims of P2P scams. Identifying malicious actors is crucial to protecting customers.

Starting with anonymized financial transaction data, we will detect communities, identify important financial nodes, and resolve entities–providing impactful results with less effort than traditional analysis

## Getting the Data

The data can be found in the `raw_data` subdirectory of this project. It is a dump file, so follow the upload instructions found [here](https://neo4j.com/docs/aura/classic/auradb/importing/import-database/).

## Set Up

First we need to install the `graphdatascience` package:

```python
!pip install graphdatascience & neo4j
```

And load them:

```python
from graphdatascience.session import GdsSessions, AuraAPICredentials, DbmsConnectionInfo, AlgorithmCategory
from datetime import timedelta
import pandas as pd
import os
from google.colab import userdata
```

Finally, our secrets:

```python
CLIENT_ID = userdata.get("CLIENT_ID")
CLIENT_SECRET = userdata.get("CLIENT_SECRET")
TENANT_ID = userdata.get("TENANT_ID")

# Neo4j Database Connection Info
FRAUD_URI = userdata.get("fd_uri")
NEO4J_USER = userdata.get("NEO4J_USER")
FRAUD_PASSWORD = userdata.get("fd_pass")
```

## Establishing a Session

We then use our secrets to establish a connection to our AuraDB

```python
sessions = GdsSessions(api_credentials=AuraAPICredentials(CLIENT_ID, CLIENT_SECRET, TENANT_ID))

name = "fraud"
memory = sessions.estimate(
    node_count=475,
    relationship_count=800,
    algorithm_categories=[AlgorithmCategory.CENTRALITY, AlgorithmCategory.NODE_EMBEDDING],
)

db_connection_info = DbmsConnectionInfo(FRAUD_URI, NEO4J_USER, FRAUD_PASSWORD)

# Create or retrieve a session
gds = sessions.get_or_create(
    session_name=name,
    memory=memory,
    db_connection=db_connection_info, # this is checking for a bolt server currently
    ttl=timedelta(hours=5),
)
```

## Exploratory Analysis and Cleaning our Data

First let's take a look at the node labels for our graph. We quickly notice that the most common type is an IP address.

```python
gds.run_cypher('''
    CALL apoc.meta.stats()
    YIELD labels
    UNWIND keys(labels) AS nodeLabel
    RETURN nodeLabel, labels[nodeLabel] AS nodeCount
''')
```

Next let's do the same for relationships. Unsurprisingly, the most common type is `HAS_IP`.

```python
gds.run_cypher('''
    CALL apoc.meta.stats()
    YIELD relTypesCount
    UNWIND keys(relTypesCount) AS relationshipType
    RETURN relationshipType, relTypesCount[relationshipType] AS relationshipCount
''')
```

Next we are going to examine how many of our nodes has the preassigned fraud label:

```python
gds.run_cypher('MATCH(u:User) RETURN u.fraudMoneyTransfer AS fraudMoneyTransfer, count(u) AS cnt')
```

Then we are going to assign the `FlaggedUser` label to the nodes that are suspected fraudsters:

```python
gds.run_cypher('MATCH(u:User) WHERE u.fraudMoneyTransfer=1 SET u:FlaggedUser RETURN count(u)')
```

Next we are going to find users who have a transaction between them and also share a credit card. We are going to create a new relationship between them called `P2P_WITH_SHARED_CARD`:

```python
gds.run_cypher('''
    MATCH (u1:User)-[r:P2P]->(u2)
    WITH u1, u2, count(r) AS cnt
    MATCH (u1)-[:HAS_CC]->(n)<-[:HAS_CC]-(u2)
    WITH u1, u2, count(DISTINCT n) AS cnt
    MERGE(u1)-[s:P2P_WITH_SHARED_CARD]->(u2)
    RETURN count(DISTINCT s) AS cnt
''')
```

Next we are going to create a `SHARED_IDS` based on a few different business rules:

```python
gds.run_cypher('''
MATCH (u1:User)-[r1:HAS_CC|USED]->(n)<-[r2:HAS_CC|USED]-(u2)
WHERE id(u1) < id(u2)
  AND COUNT { (n)<--() } <= 10
WITH u1, u2, collect(DISTINCT n) AS shared_n

MATCH (u1)-[r3:HAS_CC|USED|HAS_IP]->(m)<-[r4:HAS_CC|USED|HAS_IP]-(u2)
WITH u1, u2, shared_n, count(DISTINCT m) AS shared_count
WHERE shared_count > 2

MERGE (u1)-[s:SHARED_IDS]->(u2)
RETURN count(DISTINCT s)
''')
```

## Creating a Projection and Running Algorithms 

Next we create a graph projection using these two new relationships that we just created. We use an `OPTIONAL` match to ensure that we keep those singleton communities of users who do not have a shared id or credit card:

```python
query = """
CALL {
  MATCH (u1:User)
  OPTIONAL MATCH (u1)-[r:SHARED_IDS|P2P_WITH_SHARED_CARD]-(u2:User)
  WHERE id(u1) < id(u2)
  RETURN u1 AS source, u2 AS target, type(r) AS relType
}
RETURN gds.graph.project.remote(source, target, {
    sourceNodeLabels: labels(source),
    targetNodeLabels: labels(target),
    relationshipType: relType
});
"""

# Project the graph into GDS
gds.graph.drop("full")
full, result = gds.graph.project(
    graph_name="full",
    query=query
)
```

### Weakly Connected Components

Weakly Connected Components (WCC) is a practical and highly scalable community detection algorithm. It is also deterministic and very explainable. It defines a community simply as a set of nodes connected by a subset of relationship types in the graph. This makes WCC a good choice for formal community assignment in production fraud detection settings.

```python
df = gds.wcc.write(full, writeProperty='wccId')
```

As these communities are meant to label underlying groups of individuals, if even one flagged account is in the community, we will label all user accounts in the group as fraud risks:

```cypher
gds.run_cypher('''
    MATCH (f:FlaggedUser)
    WITH collect(DISTINCT f.wccId) AS flaggedCommunities
    MATCH(u:User) WHERE u.wccId IN flaggedCommunities
    SET u:FraudRiskUser
    SET u.fraudRisk=1
    RETURN count(u)
''')

```

This gives us a total of 452 fraud risk accounts which means if we subtract the 241 already flagged accounts we identified ***211 new fraud risk user accounts.***

## Wrapping Things Up

The breakdown of communities by size is listed below. The majority are single user communities. Only a small portion have multiple users and of those, community sizes are mostly 2 and 3. Larger communities are rare. However, if we look at the fraudUser accounts we will see that the majority reside in multi-user communities. The 118 fraud accounts in single user communities are flagged users (via original chargeback logic) that have yet to be resolved to a community.

```python
gds.run_cypher( '''
    MATCH (u:User)
    WITH u.wccId AS community, count(u) AS cSize, sum(u.fraudRisk) AS cFraudSize
    WITH community, cSize, cFraudSize,
    CASE
        WHEN cSize=1 THEN ' 1'
        WHEN cSize=2 THEN ' 2'
        WHEN cSize=3 THEN ' 3'
        WHEN cSize>3 AND cSize<=10 THEN ' 4-10'
        WHEN cSize>10 AND cSize<=50 THEN '11-50'
        WHEN cSize>10 THEN '>50' END AS componentSize
    RETURN componentSize,
        count(*) AS numberOfComponents,
        sum(cSize) AS totalUserCount,
        sum(cFraudSize) AS fraudUserCount
    ORDER BY componentSize
''')
```

Fraud Risk labeling helped identify an additional 211 new fraud risk user accounts, nearly doubling the number of known fraud users (87.5 percent increase).

***We also see that 65 percent of the money going to/from previously flagged accounts and other users can be attributed to the newly identified risk accounts:***

```python
gds.run_cypher('''
   MATCH (:FlaggedUser)-[r:P2P]-(u)  WHERE NOT u:FlaggedUser
   WITH toFloat(sum(r.totalAmount)) AS p2pTotal
   MATCH (u:FraudRiskUser)-[r:P2P]-(:FlaggedUser) WHERE NOT u:FlaggedUser
   WITH p2pTotal,  toFloat(sum(r.totalAmount)) AS fraudRiskP2pTotal
   RETURN round((fraudRiskP2pTotal)/p2pTotal,3) AS p

''')
```

Additionally, while the newly identified 211 accounts represents less than 1 percent of total users in the sample, ***12.7 percent of the total P2P amount*** in the sample involved the newly identified accounts as senders or receivers:

```python
gds.run_cypher('''
   MATCH (:User)-[r:P2P]->()
   WITH toFloat(sum(r.totalAmount)) AS p2pTotal
   MATCH (u:FraudRiskUser)-[r:P2P]-() WHERE NOT u:FlaggedUser
   WITH p2pTotal, toFloat(sum(r.totalAmount)) AS fraudRiskP2pTotal
   RETURN round((fraudRiskP2pTotal)/p2pTotal,3) AS p
''').p[0]
```

Finally, we delete our session:

```python
sessions.delete(session_name="fraud")
```


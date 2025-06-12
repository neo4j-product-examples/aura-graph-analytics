# Managing Risk in a Manufacturing Plant with Neo4j Graph Data Science

This notebook shows how to model a manufacturing workflow in Neo4j and apply Graph Data Science (GDS) algorithms to find structural risks, operational bottlenecks, and machine similarities.

We will cover:

1. **Setting Up**: The basics needed to run `graphdatascience`
2. **Graph Projection**: Combine the `Machine` and `Sensor` nodes and their relationships into a single in-memory graph.
3. **Connectivity Analysis**: Utilize Weakly and Strongly Connected Components to identify isolated subsystems and recycling loops.
4. **Criticality Ranking**: Apply PageRank to identify key machines whose failure would have the most significant downstream impact.
5. **Structural Embeddings and Similarity**: Generate FastRP embeddings and run KNN to group machines with similar roles or dependencies.

**Data Source** 

The analysis uses simulated manufacturing data loaded into Neo4j. There are two node types (`Machine`, `Sensor`) and two relationships (`FEEDS_INTO` for production flow, `LOGS` for sensor readings).

**Python Environment**

This demo is written to run in [Google Colab](https://colab.research.google.com/) and contains references to Colab features.  You may run it in any Python environment that has access to compute resources needed to execute the GDS algorithms.

**Neo4j Graph Setup**

Using the Neo4j web UI do the following:
- Create a new database
- Create the Machine nodes using [Machines.cypher](https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/manufacturing/data/cypher/Machines.cypher ) 
- Create the FEEDS_INTO relationships using [Feed_Relationships.cypher](https://raw.githubusercontent.com/neo4j-product-examples/aura-graph-analytics/refs/heads/main/manufacturing/data/cypher/Feed_Relationships.cypher ) 

## Setting Up

First we need to install the graphdatascience package and load all of our secrets

```
!pip install graphdatascience
```

```python
from graphdatascience.session import GdsSessions, AuraAPICredentials, DbmsConnectionInfo, AlgorithmCategory
from neo4j import GraphDatabase
import pandas as pd
from datetime import timedelta
from google.colab import userdata
```

You must first generate your credentials in Neo4j Aura. Afterwards, you can store your credentials securely using **colab secrets**.

```python
# This crediential is the Organization ID
TENANT_ID=userdata.get('TENANT_ID')

# These credentials were generated after the creation of the Aura Instance
NEO4J_URI = userdata.get('NEO4J_URI')
NEO4J_USERNAME = userdata.get('NEO4J_USERNAME')
NEO4J_PASSWORD = userdata.get('NEO4J_PASSWORD')

# These credentials were generated after the creation of the API Endpoint
CLIENT_SECRET=userdata.get('CLIENT_SECRET')
CLIENT_ID=userdata.get('CLIENT_ID')
CLIENT_NAME=userdata.get('CLIENT_NAME')
```

#### Establishing a Session

Estimate resources based on graph size and create a session with a 2‑hour TTL.  

```python
sessions = GdsSessions(api_credentials=AuraAPICredentials(CLIENT_ID, CLIENT_SECRET, TENANT_ID))

session_name = "demo-session"
memory = sessions.estimate(
    node_count=1000, relationship_count=5000,
    algorithm_categories=[AlgorithmCategory.CENTRALITY, AlgorithmCategory.NODE_EMBEDDING],
)

db_connection_info = DbmsConnectionInfo(NEO4J_URI, NEO4J_USERNAME, NEO4J_PASSWORD)
```

Then initalize the session itself:

```python
# Initialize a GDS session scoped for 2 hours, sized to estimated graph
gds = sessions.get_or_create(
    session_name,
    memory=memory,
    db_connection=db_connection_info, # this is checking for a bolt server currently
    ttl=timedelta(hours=2),
)

print("GDS session initialized.")
```

We are also going to include a helper function here:

```python
# Helper: execute Cypher and return pandas DataFrame
def query_to_df(cypher: str, params=None):
    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USERNAME, NEO4J_PASSWORD))
    with driver.session() as session:
        result = session.run(cypher, params or {})
        df = pd.DataFrame([r.data() for r in result])
    driver.close()
    return df
```

## Graph Projection

First, we project all Machine and Sensor nodes and their FEEDS_INTO and LOG relationships into a single in-memory graph called full. Building one consistent projection ensures that every algorithm runs against the same structure. It helps to avoid analysis discrepancies and makes the results easier to interpret and compare.

```python
# Define the custom Cypher query for projecting the graph

if gds.graph.exists("full")["exists"]:
    gds.graph.drop("full")

query = """
CALL {
    MATCH (source)-[rel]->(target)
    RETURN
        source,
        rel,
        target
}
RETURN gds.graph.project.remote(source, target, {
    sourceNodeLabels: labels(source),
    targetNodeLabels: labels(target),
    relationshipType: type(rel)
});

"""

# Project the graph into GDS
full_graph, result = gds.graph.project(
    graph_name="full",
    query=query
)
```

## Connectivity Analysis

Structural connectivity examines how the nodes in your plant are linked together and identifies hidden structural risks. We use two complementary methods:

- **Weakly Connected Components (WCC)**
WCC treats the graph as undirected, ignoring the flow of edges. It groups nodes that can reach each other regardless of direction. If your graph breaks into multiple weak components, it suggests segmented workflows or isolated equipment groups that may represent operational blind spots or disconnected production lines.

- **Strongly Connected Components (SCC)**
SCC respects edge direction and identifies true directed loops (A→B→...→A). Cycles in production graphs often correspond to scrap-and-rework loops or inefficient recycling, which can cause hidden costs or production bottlenecks. Finding non-trivial SCCs helps target areas for workflow correction.

WCC gives a high-level view of connectivity, highlighting whether your plant functions as one unified system. SCC drills down into specific cycle structures that could be costing efficiency.

#### Weakly Connected Components (WCC)

**How to Interpret WCC Results**:
A single connected component for our domain is ideal; it suggests an integrated production network. Multiple smaller components imply isolated lines or equipment clusters that may need integration or review.

**Expected result:** The simulated data is designed to form a single significant component, reflecting a unified workflow.

```python
gds.wcc.write(full_graph, writeProperty='wcc')

wcc_df = query_to_df(
    """
    MATCH (m:Machine)
    RETURN m.node_id AS machine, m.wcc AS component
    ORDER BY component, machine
    """
)
print("Component counts:")
print(wcc_df['component'].value_counts().head())
```

#### Strongly Connected Components (SCC)

**How to Interpret SCC Results**:

Each strongly connected component represents a set of machines with a directed path from any machine to every other in the group. Components with multiple machines often signal rework loops, material recycling paths, or cyclic flows that can slow production and waste capacity.

**Expected result:** Small cycles have been intentionally created between specific machines in the simulated data. You should detect these directed loops and confirm that material or flow can cycle back to earlier steps in the process.

```python
gds.scc.write(full_graph, writeProperty="scc")

scc_df = query_to_df(
    """
    MATCH (m:Machine)
    RETURN m.node_id AS machine, m.scc AS scc
    ORDER BY scc, machine
    """
)
# show only the non-trivial cycles:
cycles = scc_df.groupby("scc").filter(lambda g: len(g) > 1)
print("Detected loops (machine pairs):")
display(cycles)
```

**Interpretation** Machines 6 and 7 form a closed loop (SCC 6), and machines 8 and 9 form another (SCC 9), meaning each pair feeds back into each other. These directed cycles often signal scrap‐and‐rework loops or inefficiencies that you’ll want to investigate and break.

## Criticality Analysis

Identifying the most critical machines in your workflow can help avoid shutdowns. If these machines slow down or fail, downstream operations halt. We can use centrality algorithms to surface those high-impact nodes so you can:
* Prioritize monitoring of the machines whose disruption would ripple through the entire line
* Allocate maintenance resources where they’ll have the most significant effect
* Design redundancy or backup processes around your process hubs
Plan capacity expansions by understanding which machines handle the most “traffic.”

#### PageRank Centrality

Designed initially to rank web pages, PageRank measures a node’s importance by the “quality and quantity” of incoming edges. In our graph, an edge A → B means “Machine A feeds into Machine B.” A high PageRank score indicates a machine that receives material from many other well-connected machines.


**How to Interpret Page Rank**:
The highest-performing machines manage the most critical data flow.

**Expected Result**:  Machine 20 has been set up as the processing hub for the simulated data, so it should be at the very top of the list.

```python
gds.pageRank.write(
    full_graph,
    writeProperty='pagerank',
    maxIterations=20,
    dampingFactor=0.85
)

pr_df = query_to_df(
    """
    MATCH (m:Machine)
    RETURN m.node_id AS machine, m.pagerank AS score
    ORDER BY score DESC LIMIT 10
    """
)
pr_df.head()
```

**Interpretation** As expected, Machine 20 sits at the heart of our production flow, receiving the most “inbound” throughput and so carries the greatest operational weight. Machines 8 and 9 also serve as major hubs, channeling significant material or information, while Machines 19 and 6 play more peripheral roles. In practice, you’d prioritize redundancy or maintenance for the top-scoring machines to minimize system-wide disruptions.

##  Structural Embeddings & Similarity

Getting an even deeper understanding of each machine's workflow requires more than looking at direct connections, as we have done so far. Structural embeddings capture broader patterns by summarizing each machine’s position in the overall operation into a numeric vector. This allows you to:

* Group machines with similar roles or dependencies

* Identify candidates for backup or load-balancing

* Spot unusual machines that behave differently from the rest of the plant

We use embeddings to make these comparisons based on immediate neighbors and overall graph structure.

We’ll use two GDS algorithms:

* **Fast Random Projection (FastRP)**
FastRP generates a compact 16-dimensional vector for each machine. These vectors are built by sampling the graph around each node, so two machines with similar surroundings will end up with similar embeddings.

* **K-Nearest Neighbors (KNN)**
Finds, for each machine, the top K most similar peers based on cosine similarity of their embeddings.

Together, embeddings + KNN surface structural affinities beyond simple degree or centrality measures.

#### Fast Random Projection (FastRP) Embeddings

The results for FastRp are not immediately interpretable. However, machines with nearly identical embeddings have similar upstream and downstream relationships and likely play the same role in the plant. These embeddings are numerical representations that enable downstream clustering, similarity search, or anomaly detection.

```python
# Run FastRP and write embeddings to each Machine node property 'embedding'
print("Running FastRP embeddings…")
res = gds.fastRP.write(
    full_graph,
    writeProperty='embedding',
    embeddingDimension=16,
    randomSeed=42
)


emb_df = query_to_df(
    """
    MATCH (m:Machine)
    RETURN m.node_id AS machine, m.embedding AS embedding
    ORDER BY machine
    LIMIT 5
    """
)
emb_df
```

Our initial graph projection does not include any property information, so we will have to create a new graph projection that includes the new 'embedding' property we created for any future downstream algorthims.

```python
query = query="""
    CALL {
        MATCH (m1)
        WHERE m1.embedding IS NOT NULL
        OPTIONAL MATCH (m1)-[r]->(m2)
        where m2.embedding is not null
        RETURN m1 AS source, r AS rel, m2 AS target, {embedding: m1.embedding} AS sourceNodeProperties, {embedding: m2.embedding} AS targetNodeProperties
    }
    RETURN gds.graph.project.remote(source, target, {
      sourceNodeProperties: sourceNodeProperties,
      targetNodeProperties: targetNodeProperties,
      sourceNodeLabels: labels(source),
      targetNodeLabels: labels(target)
    })
    """

# Project the graph into GDS
embeddings_graph, result = gds.graph.project(
    graph_name="embeddings",
    query=query
)
```

#### k-Nearest Neighbors (KNN)

Once we have embeddings for every machine, we can use K-Nearest Neighbors to find the most structurally similar machines based on their vector representations. KNN compares the cosine similarity between embeddings to pull out the top matches for each machine.

***\*How to Interpret KNN Results\****:

Machines with a similarity score close to 1.0 are operating in nearly identical parts of the workflow. These machines may be interchangeable, ideal backups for each other, or grouped for shared maintenance plans.

***\*Expected Result\****:

Machines that were intentionally set up as redundant paths or part of the same processing line (such as 43 and 64 in the simulation) should show similarity scores very close to 1.0.

```python
# Stream top-5 similar per machine
knn_stream = gds.knn.stream(
    embeddings_graph,                 # your already-bound handle
    nodeProperties=["embedding"],
    topK=5
)

knn_df = pd.DataFrame(knn_stream)

knn_df.sort_values("similarity", ascending=False).head(10)
```

**Intrepretation** Each row with a similarity of 1.0 means those two machines occupy essentially the exact same structural “neighborhood” in your workflow graph. For example, Machines 49, 50 and 51 form a tight clique of interchangeable roles, as do the pairs (47, 68) and (43, 64). You can treat each of these clusters as functionally equivalent units—ideal candidates for load-balancing, redundancy checks or targeted process tuning.

## Clean Up!

Close your GDS session when you’re done.

```python
sessions.delete(session_name=session_name)
```


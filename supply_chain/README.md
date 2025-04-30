# Identifying Bottlenecks in a Supply Chain
In this quick start you will:

- Learn how to load data into AuraDB
- Connect Neo4j Aura Graph Analytics from python to your database
- Project a graph and run algorithm against it 

This repo is broken into a few parts. First, we have two folders containing original source data, which was pulled from [here](https://eto.tech/dataset-docs/chipexplorer/) and another folder containing cleaned data. As you might expect, the `clean_data.ipynb` was used the clean the data. 

The data shows the relationship between companies and components in the microchip supply chain. Components will either have a `INPUTS` or `OUTPUTS` relationship to a company based on if the company makes that component (outputs) or uses it to make something else (inputs)

The `Microchip Supply Chain.ipynb` was used to actually analyze the data. Below, we will go over how to load data into AuraDB and use Aura Graph Analytics to determine bottlenecks.

### Prerequisites 

- AuraDB
- Aura Graph Analytics - a new pay-as-you-go service offering from Neo4j 

## Step 1: Getting Data into AuraDB

We will use the cleaned data to load into AuraDB. Run each one of these cypher statements directly in your AuraDB console:

```
// Create Company Nodes
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/corydonbaylor/supply-chain/refs/heads/main/clean_data/organizatons.csv" AS row
CREATE (:Company {
    name: row.provider_name,
    provider_id: row.provider_id,
    country: row.country
});

// Create Component Nodes
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/corydonbaylor/supply-chain/refs/heads/main/data/inputs.csv" AS row
CREATE (:Component {
    input_name: row.input_name,
    input_id: row.input_id
});

// Create INPUTS Relationships
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/corydonbaylor/supply-chain/refs/heads/main/clean_data/inputs_to_providers.csv" AS row
MATCH (company:Company {provider_id: row.provider_id})
MATCH (component:Component {input_id: row.input_id})
MERGE (component)-[:INPUTS]->(company);

// Create OUTPUTS Relationships
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/corydonbaylor/supply-chain/refs/heads/main/clean_data/outputs.csv" AS row
MATCH (company:Company {provider_id: row.provider_id})
MATCH (component:Component {input_id: row.provided_id})
MERGE (company)-[:OUTPUTS]->(component);

```

## Step 2: Setting Up in Python

You will use python to establish sessions with Aura Graph Analytics. Here we will walk through what packages to install and what secrets you will need. We are going to assume that you are using Google Colab to run your code, but this will work with any python environment. You will just need to change how you load in secrets.

You will need the following packages:

```
from graphdatascience.session import GdsSessions, AuraAPICredentials, DbmsConnectionInfo, AlgorithmCategory
from datetime import timedelta
import pandas as pd
import os
from google.colab import userdata
```

And to load in the following credentials:

```
# tenant secrets
CLIENT_ID = userdata.get("CLIENT_ID")
CLIENT_SECRET = userdata.get("CLIENT_SECRET")
TENANT_ID = userdata.get("TENANT_ID")

# Neo4j Database Connection Info
SUPPLIER_URI = userdata.get("SUPPLIER_URI")
NEO4J_USER = userdata.get("NEO4J_USER")
SUPPLIER_PASSWORD = userdata.get("SUPPLIER_PASSWORD")
```

## Step 3: Establishing a Session and Creating a Projection

Next, using our Aura API credentials, we are going to create a session and connect it to our database:

```
sessions = GdsSessions(api_credentials=AuraAPICredentials(CLIENT_ID, CLIENT_SECRET, TENANT_ID))

name = "my-new-session"
memory = sessions.estimate(
    node_count=475,
    relationship_count=800,
    algorithm_categories=[AlgorithmCategory.CENTRALITY, AlgorithmCategory.NODE_EMBEDDING],
)

db_connection_info = DbmsConnectionInfo(SUPPLIER_URI, NEO4J_USER, SUPPLIER_PASSWORD)

# Create or retrieve a session
gds = sessions.get_or_create(
    session_name=name,
    memory=memory,
    db_connection=db_connection_info, # this is checking for a bolt server currently
    ttl=timedelta(hours=5),
)

```

Then we are going to create a projection In order to do so, we need specify a **subgraph** of the data. In our case, we are essentially going to be looking at the entire graph:

```
# Define the custom Cypher query for projecting the graph
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
full, result = gds.graph.project(
    graph_name="full-graph",
    query=query
)

```

## Step 4: Running PageRank

Finally, we will run the PageRank algorithm to assign a score for each node in our graph. We will write it back to our AuraDB instance:

```
pagerank_result = gds.pageRank.write(
    full,
    writeProperty="PR",  # Name of the property to store scores
    maxIterations=20,      # Maximum number of iterations
    dampingFactor=0.85     # Damping factor (default is 0.85)
)
```

And then we will review the results like so:

```
# Example Cypher query
cypher_query = """
MATCH (n:Company)
RETURN n.name, n.provider_id, n.PR
ORDER BY n.PR DESC;
"""

# Define a function to execute the Cypher query and return a DataFrame
def query_to_dataframe(query, parameters=None):
    with driver.session() as session:
        result = session.run(query, parameters)
        # Convert the result to a list of dictionaries (records)
        records = [record.data() for record in result]
        # Convert the list of dictionaries into a Pandas DataFrame
        df = pd.DataFrame(records)
        return df
        
# Execute the query and get the results as a DataFrame
df = query_to_dataframe(cypher_query)

# Display the DataFrame
df.head(5)
```

## Step 5: Further Analysis

Using what we learned from PageRank, we could try and see the effect of removing some of the most important on the entire supply chain. 

We can create a subgraph removing the most important companies and then run WCC to see if our supply chain broke into two graphs by removing those important companies:

```
# Define the custom Cypher query for projecting the entire graph
query = """
CALL {
    MATCH (source)-[rel]->(target)
    WHERE NOT (source:Company AND source.provider_id IN ["P9",  "P35", "P19"])
      AND NOT (target:Company AND target.provider_id IN ["P9",  "P35", "P19"])
    RETURN source, rel, target
}
RETURN gds.graph.project.remote(source, target, {
    sourceNodeLabels: labels(source),
    targetNodeLabels: labels(target),
    relationshipType: type(rel)
});
"""

graph_name = "four-less"

if gds.graph.exists(graph_name)["exists"]:
    # Drop the graph if it exists
    gds.graph.drop(graph_name)
    print(f"Graph '{graph_name}' dropped.")

# Project the entire graph into GDS using the custom query
G, result = gds.graph.project(
    graph_name=graph_name,
    query=query
)
```

And then we look at the results:

```
# Run Weakly Connected Components on the projected graph
result = gds.wcc.write(G, writeProperty="wcc")

# Example Cypher query
cypher_query = """
MATCH (n)
RETURN n.wcc, count(*)
"""

# Execute the query and get the results as a DataFrame
df = query_to_dataframe(cypher_query)

# Display the DataFrame
df.head(10)
```


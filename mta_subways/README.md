# Modeling Disruptions in the MTA Subway

3.6 million Americans ride the New York City subway each day. That's 1.3 million more people than who take a flight each day in the United States. The New York City Subway is unique in the number of riders, stations, and the level of service it provides.

Using [Aura Graph Analytics](https://docs.google.com/presentation/d/1jv99yyIbG6Q6eNE3tPDfeE7qlyR-VtaCXDsJFTs4_jI/edit?slide=id.g34c47828515_0_881#slide=id.g34c47828515_0_881), we can easily model what would happen if a station was fully closed for repairs. Insights like this can apply not just to transport systems, but to **supply** **chains, manufacturing processes** and much more. 

For supply chains, imagine if a particular vendor was hit with tariffs or, even worse, went out of business. Which alternate supplier path gets your product to market fastest with the least disruption? Using the same shortest-path techniques demonstrated in this blog, you can quickly evaluate the next best route and keep operations running smoothly. 

Aura Graph Analytics works with any enterprise data. In this example, we are going to load data from Snowflake into dataframes, create a graph projection, and run algorithms– ***all without having to move our data into AuraDB\!***

Whether it’s passengers or products, understanding and adapting the paths through your network is key to resilience.

## Getting Started

We are going to be working in a google colab notebook, but you can run this in any python environment. First we need to install and load the necessary packages:

```
!pip install graphdatascience
```

```py
from graphdatascience.session import GdsSessions, AuraAPICredentials, DbmsConnectionInfo, AlgorithmCategory
from datetime import timedelta
import pandas as pd
import os
from google.colab import userdata
```

## Creating a Session

Next we will set up a session, first by loading in our secrets:

```py
CLIENT_ID = userdata.get("CLIENT_ID")
CLIENT_SECRET = userdata.get("CLIENT_SECRET")
TENANT_ID = userdata.get("TENANT_ID")

```

And then by establishing a session:

```py
from graphdatascience.session import GdsSessions, AuraAPICredentials, AlgorithmCategory, CloudLocation
from datetime import timedelta

sessions = GdsSessions(api_credentials=AuraAPICredentials(CLIENT_ID, CLIENT_SECRET, TENANT_ID))

name = "my-new-session-sm"
memory = sessions.estimate(
    node_count=20,
    relationship_count=50,
    algorithm_categories=[AlgorithmCategory.CENTRALITY, AlgorithmCategory.NODE_EMBEDDING],
)
cloud_location = CloudLocation(provider="gcp", region="europe-west1")

gds = sessions.get_or_create(
    session_name=name,
    memory=memory,
    ttl=timedelta(hours=5),
    cloud_location=cloud_location,
)
```

## Loading in Data from Snowflake

*Note: [Use the csvs found here to follow along](https://github.com/neo4j-product-examples/aura-graph-analytics/tree/main/mta_subways/data). Just load them into Snowflake or directly into your python environment.*

One of the key advantages of Aura Graph Analytics is that you don’t need to store your data in AuraDB to use it. In our case, we will load in data from Snowflake into python dataframes. Let’s start by downloading the `snowflake-connector-python` package:

```
!pip install snowflake-connector-python
```

Then let’s create a connection to snowflake:

```py
import pandas as pd
import snowflake.connector

SNOWFLAKE_USER = userdata.get("snowflake_user")
SNOWFLAKE_PASSWORD = userdata.get("snowflake_password")
SNOWFLAKE_ACCOUNT = userdata.get("snowflake_account")


# Replace with your credentials
conn = snowflake.connector.connect(
    user= SNOWFLAKE_USER,
    password=SNOWFLAKE_PASSWORD,
    account=SNOWFLAKE_ACCOUNT,  
    warehouse='GDSONSNOWFLAKE',
    database='MTA',
    schema='PUBLIC',
)
```

And return our two tables as python dataframes:

```py
cur = conn.cursor()
cur.execute("SELECT * FROM LINES")
lines = cur.fetch_pandas_all()
cur.close()
lines
```

| STARTING\_STATION | NEXT\_STATION | RELATIONSHIPTYPE |
| ----- | ----- | ----- |
| 0 | 1 | GOES\_TO |
| 1 | 2 | GOES\_TO |
| 2 | 3 | GOES\_TO |
| 3 | 4 | GOES\_TO |

```py
cur = conn.cursor()
cur.execute("SELECT * FROM stations")
stations = cur.fetch_pandas_all()
cur.close()
stations
```

| STATION\_NAME | ID |
| ----- | ----- |
| Van Cortlandt Park-242 \- Bx | 0 |
| 238 St \- Bx | 1 |
| 231 St \- Bx | 2 |
| Marble Hill-225 St \- M | 3 |
| 215 St \- M | 4 |

## Creating a Projection

We do need to do some mild clean up to make sure that everything has the right names.

For the dataframe representing nodes:  
\- The first column should be called \`nodeId\`  
\- There can be no characters so we will have to drop the station names

```py
stations = stations.rename(columns={'id': 'nodeId'})
nodes = stations[['nodeId']]
nodes
```

For the dataframe representing relationships:  
\- We need to have columns called \`sourceNodeId\` and \`targetNodeId\`

```py
lines2 = lines.rename(
    columns={
        'sourceNodeId' : 'targetNodeId',
        'targetNodeId' : 'sourceNodeId'
    }
)

lines = lines[['targetNodeId', 'sourceNodeId']]
lines
```

## Graph Construct

Using `graph.construct`, we can easily create a projection.

```py
graph_name = "subways"

if gds.graph.exists(graph_name)["exists"]:
    # Drop the graph if it exists
    gds.graph.drop(graph_name)
    print(f"Graph '{graph_name}' dropped.")
    
G = gds.graph.construct("subways", nodes, lines)
```

We will use Dijkstra shortest path to see how we can move through the system efficiently.

We can create a simple wrapper function below, so that we can use the names of stations rather than their `nodeIds`:

```py
station_crosswalk = dict(zip(stations['STATION_NAME'], stations['nodeId']))

# Function to get the node IDs from station names and run Dijkstra
def get_shortest_path(source_station, target_station, G):
    # Map the station names to node IDs
    source_node_id = station_crosswalk.get(source_station)
    target_node_id = station_crosswalk.get(target_station)

    result = gds.shortestPath.dijkstra.stream(
          G,
          sourceNode=source_node_id,
          targetNode=target_node_id
      )
    node_ids = result['nodeIds'][0]
    id_to_station = {v: k for k, v in station_crosswalk.items()}
    ordered_subset = {id_to_station[i]: i for i in node_ids if i in id_to_station}
    return ordered_subset
```

Let's see how to get from Grand Army Plaza in Brooklyn to Times Square:

```py
# Example usage
# Assuming 'G' is your graph
source_station = "Grand Army Plaza - Bk"
target_station = "Times Sq-42 St - M"

# Call the function
path_df = get_shortest_path(source_station, target_station, G)
path_df
```

This returns:

```
{'Grand Army Plaza - Bk': 69,
 'Bergen St - Bk': 68,
 'Atlantic Av-Barclays Ctr - Bk': 67,
 'Canal St - M': 32,
 '14 St-Union Sq - M': 104,
 '34 St-Herald Sq - M': 230,
 'Times Sq-42 St - M': 24}
```

## Modeling Disruptions

But what if one of those stations closed? What would be the quickest path there? Let's see what would happen if Herald Square was closed:

```py
def exclude_node(nodes_df, lines_df, node_to_exclude):
    closed = nodes_df[nodes_df['nodeId'] != node_to_exclude]
    closed_lines = lines_df[
        (lines_df['sourceNodeId'] != node_to_exclude) &
        (lines_df['targetNodeId'] != node_to_exclude)
    ]
    return closed, closed_lines

closed_nodes, closed_lines = exclude_node(nodes, lines, 230)
```

We then need to create a new projection without Herald Square

```py
graph_name = "exclude"

if gds.graph.exists(graph_name)["exists"]:
    # Drop the graph if it exists
    gds.graph.drop(graph_name)
    print(f"Graph '{graph_name}' dropped.")

G = gds.graph.construct(graph_name, closed_nodes, closed_lines)
```

And then we rerun our algorithm:

```py
# Example usage
# Assuming 'G' is your graph
source_station = "Grand Army Plaza - Bk"
target_station = "Times Sq-42 St - M"

# Call the function
path_df = get_shortest_path(source_station, target_station, G)
path_df
```

Which returns:

```
{'Grand Army Plaza - Bk': 69,
 'Bergen St - Bk': 68,
 'Atlantic Av-Barclays Ctr - Bk': 67,
 'Canal St - M': 32,
 'Chambers St - M': 34,
 '14 St - M': 29,
 '34 St-Penn Station - M': 25,
 'Times Sq-42 St - M': 24}
```

We can see that this is a slightly longer path than before\!

Finally, we end our session\!

```py
sessions.delete(session_name="my-new-session")
```

And with that, you can see how to run graph algorithms against any enterprise data, and how to model disruptions\!

## What’s Next

Now that you’ve got a solid grasp on modeling disruptions (whether that be on the subway or otherwise), head over to our [GitHub repo](https://github.com/neo4j-product-examples/aura-graph-analytics/tree/main/mta_subways) for step-by-step instructions on how to do it yourself with Neo4j Aura Graph Analytics. You’ll find a Colab notebook, the full dataset, and everything you need to get started. 

Prefer working in Snowflake? You can run the same example there using [Neo4j Graph Analytics for Snowflake](https://quickstarts.snowflake.com/guide/modeling-subway-disruptions-with-neo4j/index.html?index=..%2F..index#0).
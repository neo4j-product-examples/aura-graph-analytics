# Finding Similar Patient Journeys

The Future of healthcare is personalized. Currently, $1.5 trillion dollars goes toward healthcare for chronic conditions each year in the United States. 72% of patients desire more personalized care and believe tech [can help](https://rendia.com/resources/insights/what-patients-want-personalized-healthcare-experiences/?utm_source=chatgpt.com). Modeling a patients journey through the healthcare system is a graph problem. See below how we find similar communities of patients. 

## Setting up the Environment

First install and load the packages:

```
!pip install graphdatascience==1.15a2
```

```
!pip install --upgrade numpy
```

```python
import pandas as pd
from google.colab import userdata
```

Then load in our credentials for Aura:

```python
CLIENT_ID = userdata.get("CLIENT_ID")
CLIENT_SECRET = userdata.get("CLIENT_SECRET")
TENANT_ID = userdata.get("TENANT_ID")
```

And then we create a session:

```python
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

## Taking a Look at the Data

We will be using [Synthea](https://synthetichealth.github.io/synthea/) to generate mock data. Synthea creates realistic mock healthcare data. Our goal will be to model patient similarity, that way we could see if there is an ideal patient plan for similar patients.

We will be looking at patients and the procedures they undergone. One thing we will need to change is the `ID` as it contains characters.

```python
patients = pd.read_csv("Patients.csv")
patients.head()

procedures = pd.read_csv("Procedures.csv")
procedures.head()
```

## Converting Id to Numeric

Next, we are to create a numeric id for the patient ids in procedures. First we need to make sure that our ids don't collide. One way to do that would be to just have a longer id.

Let's see how long the ids in `CODE` in the `procedures` dataframe:

```python
all_same_length = procedures['CODE'].astype(str).str.len().nunique() == 1
procedures['CODE'].astype(str).str.len().value_counts()
```

And then we will create one that is a bit longer and doesn't have any leading 0s.

```python
import pandas as pd

# Get unique patient IDs
unique_patients = procedures['PATIENT'].unique()

# Use pure Python integers to generate 20-digit codes
start_value = 10**18  # ensures 20 digits, doesn't start with 0
numeric_ids = [start_value + i for i in range(len(unique_patients))]

# Create mapping
patient_id_map = pd.Series(numeric_ids, index=unique_patients, dtype='object')

# Apply mapping
procedures['PATIENT2'] = procedures['PATIENT'].map(patient_id_map)
```

Next, we are need to ensure that `PATIENT` in `patients` and `PATIENT2` in `procedures` have the same id.

```python
patients['PATIENT'] = patients['ID'].map(patient_id_map)
```

## Prepping for graph.construct
First we are going to create a dataframe that only contains the ids for patients who have had kidney disease.

We do need to do some mild clean up to make sure that everything has the right names.

For the dataframe representing nodes:
- The first column should be called `nodeId`

For the dataframe representing relationships:
- We need to have columns called `sourceNodeId` and `targetNodeId`
- As well as what we want to call that relationship in a column called `relationshipType`

Additionally, we are going to be looking just at patients who have kidney disease, so we are going to just look at patients with certain disease codes.

```python
# Kidney-related reason codes
kidney_disease_codes = {431857002, 46177005, 161665007, 698306007}

# Filter procedures for kidney-related reasons
kidney_procedures = procedures[procedures['REASONCODE'].isin(kidney_disease_codes)]

# Extract unique patient IDs
kidney_patient_ids = kidney_procedures['PATIENT2'].unique()
kidney_patients_vw = pd.DataFrame({'nodeId': kidney_patient_ids})
```

Then we are going to do the same for procedures. This time we are just going to be looking for procedures that kidney patients have undergone.

```python
# Filter all procedures done by kidney patients
kidney_patient_procedures = procedures[procedures['PATIENT2'].isin(kidney_patient_ids)]

# Extract unique procedure codes
kidney_patient_procedures_vw = pd.DataFrame({
    'nodeId': kidney_patient_procedures['CODE'].unique()
})
```

Finally create a view that represents the relationship between the kidney patients and all the procedures they have had.  

This will be the relationship used in the bipartite graph projection for Jaccard similarity:

```python
# Create patient-to-procedure relationship pairs
kidney_patient_procedure_relationship = kidney_patient_procedures[['PATIENT2', 'CODE']].drop_duplicates()

# Rename columns for graph semantics
relationships = kidney_patient_procedure_relationship.rename(
    columns={'PATIENT2': 'sourceNodeId', 'CODE': 'targetNodeId'}
)
```

Finally, we are going to combine the `NodeId`s for patients and procedures into one dataframe called nodes.

```python
nodes = pd.concat([kidney_patients_vw, kidney_patient_procedures_vw], ignore_index=True)
```

## Projecting a Graph and Running Patient Similarity

Next we are going to quickly create a graph using `graph.construct`.

```python
graph_name = "patients"

if gds.graph.exists(graph_name)["exists"]:
    # Drop the graph if it exists
    gds.graph.drop(graph_name)
    print(f"Graph '{graph_name}' dropped.")

G = gds.graph.construct(graph_name, nodes, relationships)
```

and see the results like so:

```python
similarity = gds.nodeSimilarity.stream(
  G
)

similarity
```

We can now use this similarity dataframe to build a new graph projection and then run louvain to see if we can build communities from our pairwise calculation.

```python
nodes_sim = pd.DataFrame(
    pd.unique(similarity[['node1', 'node2']].values.ravel()),
    columns=['nodeId']
)

# Create the relationships DataFrame
relationships_sim = similarity.rename(columns={
    'node1': 'sourceNodeId',
    'node2': 'targetNodeId',
    'similarity': 'weight'
})
```

Now, we create a new graph projection using the similarity scores:  

```python
graph_name = "patients_sim"

if gds.graph.exists(graph_name)["exists"]:
    # Drop the graph if it exists
    gds.graph.drop(graph_name)
    print(f"Graph '{graph_name}' dropped.")

G = gds.graph.construct(graph_name, nodes_sim, relationships_sim)
```

And then we run louvain against it. This will allow us to bucket different users together into communities. From this we can build out similar treatment programs for similar patients!

```python
gds.louvain.stream(
  G
)
```

Finally, we must close the session and end our billing:

```python
sessions.delete(session_name="my-new-session-sm")
```


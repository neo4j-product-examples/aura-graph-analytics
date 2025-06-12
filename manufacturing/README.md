# Aura Graph Analytics - Manufacturing Quick-Start Guide

Aura Graph Analytics Serverless is an on-demand ephemeral compute environment for running GDS workloads. Each compute unit is called a GDS Session. It is offered as part of Neo4j Aura, a fast, scalable, always-on, fully automated cloud graph platform.

You can read more about the Neo4j Graph Analytics for Aura in the [Neo4j Graph Data Science Manual](https://neo4j.com/docs/graph-data-science/current/installation/aura-graph-analytics-serverless/)

## Contents
This readme contains the following sections
- [Demo Overview](#demo-overview)
- [Quick Start Pre-requisites](#quick-start-pre-requisites)
- [Python notebook](#demo-notebook)

## Demo Overview

This demo shows how to model a manufacturing workflow in Neo4j and apply Graph Data Science (GDS) algorithms to find structural risks, operational bottlenecks, and machine similarities.

We will cover:

- **Graph Projection**: Combine the nodes and their relationships into a single in-memory graph.
- **Connectivity Analysis**: Utilize Weakly and Strongly Connected Components to identify isolated subsystems and recycling loops.
- **Criticality Ranking**: Use PageRank to find influential machines and Betweenness Centrality to identify bridges that control workflow.
- **Structural Embeddings and Similarity**: Generate FastRP embeddings and run KNN to group machines with similar roles or dependencies.

### Business Case 

Our model is based on a manufacturing case where machines are interconnected in a process.  If any machine breaks or is undergoing mainentance, it will impact all machines down the line.   The machines are connected in a graph as follows:

In this demo we will attempt to analyze business questions such as
- Which machines are most likely to fail soon?
- What if a critical piece of equipment goes offline?
- How do abnormal sensor readings cascade and affect downstream machines?

### Data Model 

The analysis uses simulated manufacturing data loaded into Neo4j. There are two node types (`Machine`, `Sensor`) and two relationships (`FEEDS_INTO` for production flow, `LOGS` for sensor readings).

<img src="./images/machine_sensor_model.png" width = "400"/>

The raw data can be found here 
- [Machines.csv](<./data/csv/Feed_Relationships.csv> "manufacturing dataset") 
- [Feed_Relationships.csv](<./data/csv/Feed_Relationships.csv> "manufacturing dataset")
- [Sensors.csv](<./data/csv/Sensors.csv> "manufacturing dataset")
- [Sensor_Logs.csv](<./data/csv/Sensor_Logs.csv> "manufacturing dataset")

## Quick Start Pre-requisites

In order to complete these quickstart steps, you will need the following resources and access

- An active Neo4j Aura account
- A Python notebook environment, such as Google Colab
- Neo4j account administrator access, with permissions to create databases and access to API tokens
- Access to the Neo4j Graph Data Science (GDS) library

Please contact your Neo4j representative if you need additional access.

## Demo notebook
You can use your faorite Python environment, such as Google Colab, to run the following notebook:
- [Manufacturing_Aura_Demo.ipynb](https://github.com/EastridgeAnalytics/Neo4jSnowflake/tree/main/aura_demos/Manufacturing_Reliability/Manufacturing_Aura_Demo.ipynb)

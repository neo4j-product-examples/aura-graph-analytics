MERGE (sensor101:Sensor {id: 101})
MERGE (machine1:Machine {id: 1})
MERGE (sensor101)-[:LOGS {reading_type: 'temperature', reading_value: 98.5, timestamp: '2025-04-27T10:00:00Z'}]->(machine1)
MERGE (sensor101)-[:LOGS {reading_type: 'temperature', reading_value: 101.2, timestamp: '2025-04-27T11:00:00Z'}]->(machine1)
MERGE (sensor101)-[:LOGS {reading_type: 'temperature', reading_value: 99.8, timestamp: '2025-04-27T12:00:00Z'}]->(machine1)

MERGE (sensor102:Sensor {id: 102})
MERGE (machine2:Machine {id: 2})
MERGE (sensor102)-[:LOGS {reading_type: 'temperature', reading_value: 100.4, timestamp: '2025-04-27T10:15:00Z'}]->(machine2)
MERGE (sensor102)-[:LOGS {reading_type: 'temperature', reading_value: 97.9, timestamp: '2025-04-27T11:15:00Z'}]->(machine2)
MERGE (sensor102)-[:LOGS {reading_type: 'temperature', reading_value: 102.3, timestamp: '2025-04-27T12:15:00Z'}]->(machine2)

MERGE (sensor106:Sensor {id: 106})
MERGE (machine6:Machine {id: 6})
MERGE (sensor106)-[:LOGS {reading_type: 'vibration', reading_value: 0.03, timestamp: '2025-04-27T10:30:00Z'}]->(machine6)
MERGE (sensor106)-[:LOGS {reading_type: 'vibration', reading_value: 0.05, timestamp: '2025-04-27T11:30:00Z'}]->(machine6)
MERGE (sensor106)-[:LOGS {reading_type: 'vibration', reading_value: 0.04, timestamp: '2025-04-27T12:30:00Z'}]->(machine6)

MERGE (sensor107:Sensor {id: 107})
MERGE (machine7:Machine {id: 7})
MERGE (sensor107)-[:LOGS {reading_type: 'vibration', reading_value: 0.02, timestamp: '2025-04-27T10:45:00Z'}]->(machine7)
MERGE (sensor107)-[:LOGS {reading_type: 'vibration', reading_value: 0.06, timestamp: '2025-04-27T11:45:00Z'}]->(machine7)
MERGE (sensor107)-[:LOGS {reading_type: 'vibration', reading_value: 0.03, timestamp: '2025-04-27T12:45:00Z'}]->(machine7)

MERGE (sensor101)-[:LOGS {reading_type: 'temperature', reading_value: 200.0, timestamp: '2025-04-27T14:00:00Z'}]->(machine1)
MERGE (sensor102)-[:LOGS {reading_type: 'temperature', reading_value: 5.0, timestamp: '2025-04-27T15:00:00Z'}]->(machine2)
MERGE (sensor106)-[:LOGS {reading_type: 'vibration', reading_value: 0.01, timestamp: '2025-04-27T14:30:00Z'}]->(machine6)
MERGE (sensor107)-[:LOGS {reading_type: 'vibration', reading_value: 0.10, timestamp: '2025-04-27T15:30:00Z'}]->(machine7);
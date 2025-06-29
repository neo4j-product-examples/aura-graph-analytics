DELETE FROM logs_rel;

INSERT INTO logs_rel (sensor_id, machine_id, reading_type, reading_value, timestamp) VALUES
    (101, 1, 'temperature', 98.5, '2025-04-27T10:00:00Z'),
    (101, 1, 'temperature', 101.2, '2025-04-27T11:00:00Z'),
    (101, 1, 'temperature', 99.8, '2025-04-27T12:00:00Z'),
    (102, 2, 'temperature', 100.4, '2025-04-27T10:15:00Z'),
    (102, 2, 'temperature', 97.9, '2025-04-27T11:15:00Z'),
    (102, 2, 'temperature', 102.3, '2025-04-27T12:15:00Z'),
    (106, 6, 'vibration', 0.03, '2025-04-27T10:30:00Z'),
    (106, 6, 'vibration', 0.05, '2025-04-27T11:30:00Z'),
    (106, 6, 'vibration', 0.04, '2025-04-27T12:30:00Z'),
    (107, 7, 'vibration', 0.02, '2025-04-27T10:45:00Z'),
    (107, 7, 'vibration', 0.06, '2025-04-27T11:45:00Z'),
    (107, 7, 'vibration', 0.03, '2025-04-27T12:45:00Z'),
    (101, 1, 'temperature', 200.0, '2025-04-27T14:00:00Z'),
    (102, 2, 'temperature', 5.0, '2025-04-27T15:00:00Z'),
    (106, 6, 'vibration', 0.01, '2025-04-27T14:30:00Z'),
    (107, 7, 'vibration', 0.10, '2025-04-27T15:30:00Z');
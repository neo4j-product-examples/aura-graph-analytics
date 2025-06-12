DELETE FROM mode;

INSERT INTO node (machine_id, machine_type, current_status, risk_level) VALUES
(1, 'Cutter', 'active', 'low'),
(2, 'Welder', 'active', 'low'),
(3, 'Press', 'active', 'medium'),
(4, 'Assembler', 'active', 'medium'),
(5, 'Paint', 'active', 'low'),
(6, 'Cutter', 'active', 'low'),
(7, 'Welder', 'active', 'medium'),
(8, 'Press', 'active', 'medium'),
(9, 'Assembler', 'active', 'low'),
(10, 'Paint', 'active', 'low'),
(11, 'Cutter', 'active', 'medium'),
(12, 'Welder', 'active', 'high'),
(13, 'Press', 'active', 'medium'),
(14, 'Assembler', 'active', 'high'),
(15, 'Paint', 'active', 'medium'),
(16, 'Cutter', 'active', 'low'),
(17, 'Welder', 'active', 'medium'),
(18, 'Press', 'active', 'low'),
(19, 'Assembler', 'active', 'medium'),
(20, 'Assembler', 'active', 'high');
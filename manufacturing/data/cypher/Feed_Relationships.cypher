MATCH (n1:Machine {id: 1}), (n2:Machine {id: 2})
MERGE (n1)-[f1:FEEDS_INTO]->(n2)
SET f1.THROUGHPUT_RATE = 50;

MATCH (n2:Machine {id: 2}), (n3:Machine {id: 3})
MERGE (n2)-[f2:FEEDS_INTO]->(n3)
SET f2.THROUGHPUT_RATE = 50;

MATCH (n3:Machine {id: 3}), (n4:Machine {id: 4})
MERGE (n3)-[f3:FEEDS_INTO]->(n4)
SET f3.THROUGHPUT_RATE = 50;

MATCH (n4:Machine {id: 4}), (n5:Machine {id: 5})
MERGE (n4)-[f4:FEEDS_INTO]->(n5)
SET f4.THROUGHPUT_RATE = 50;

MATCH (n5:Machine {id: 5}), (n6:Machine {id: 6})
MERGE (n5)-[f5:FEEDS_INTO]->(n6)
SET f5.THROUGHPUT_RATE = 50;

MATCH (n6:Machine {id: 6}), (n7:Machine {id: 7})
MERGE (n6)-[f6:FEEDS_INTO]->(n7)
SET f6.THROUGHPUT_RATE = 50;

MATCH (n7:Machine {id: 7}), (n8:Machine {id: 8})
MERGE (n7)-[f7:FEEDS_INTO]->(n8)
SET f7.THROUGHPUT_RATE = 50;

MATCH (n8:Machine {id: 8}), (n9:Machine {id: 9})
MERGE (n8)-[f8:FEEDS_INTO]->(n9)
SET f8.THROUGHPUT_RATE = 50;

MATCH (n9:Machine {id: 9}), (n10:Machine {id: 10})
MERGE (n9)-[f9:FEEDS_INTO]->(n10)
SET f9.THROUGHPUT_RATE = 50;

MATCH (n5:Machine {id: 5}), (n6:Machine {id: 6})
MERGE (n5)-[f10:FEEDS_INTO]->(n6)
SET f10.THROUGHPUT_RATE = 40;

MATCH (n6:Machine {id: 6}), (n5:Machine {id: 5})
MERGE (n6)-[f11:FEEDS_INTO]->(n5)
SET f11.THROUGHPUT_RATE = 40;

MATCH (n8:Machine {id: 8}), (n9:Machine {id: 9})
MERGE (n8)-[f12:FEEDS_INTO]->(n9)
SET f12.THROUGHPUT_RATE = 30;

MATCH (n9:Machine {id: 9}), (n8:Machine {id: 8})
MERGE (n9)-[f13:FEEDS_INTO]->(n8)
SET f13.THROUGHPUT_RATE = 30;

MATCH (n1:Machine {id: 1}), (n20:Machine {id: 20})
MERGE (n1)-[f14:FEEDS_INTO]->(n20)
SET f14.THROUGHPUT_RATE = 200;

MATCH (n2:Machine {id: 2}), (n20:Machine {id: 20})
MERGE (n2)-[f15:FEEDS_INTO]->(n20)
SET f15.THROUGHPUT_RATE = 180;

MATCH (n3:Machine {id: 3}), (n20:Machine {id: 20})
MERGE (n3)-[f16:FEEDS_INTO]->(n20)
SET f16.THROUGHPUT_RATE = 160;

MATCH (n4:Machine {id: 4}), (n20:Machine {id: 20})
MERGE (n4)-[f17:FEEDS_INTO]->(n20)
SET f17.THROUGHPUT_RATE = 140;

MATCH (n11:Machine {id: 11}), (n12:Machine {id: 12})
MERGE (n11)-[f18:FEEDS_INTO]->(n12)
SET f18.THROUGHPUT_RATE = 20;

MATCH (n12:Machine {id: 12}), (n13:Machine {id: 13})
MERGE (n12)-[f19:FEEDS_INTO]->(n13)
SET f19.THROUGHPUT_RATE = 20;

MATCH (n13:Machine {id: 13}), (n14:Machine {id: 14})
MERGE (n13)-[f20:FEEDS_INTO]->(n14)
SET f20.THROUGHPUT_RATE = 20;

MATCH (n14:Machine {id: 14}), (n15:Machine {id: 15})
MERGE (n14)-[f21:FEEDS_INTO]->(n15)
SET f21.THROUGHPUT_RATE = 20;

MATCH (n15:Machine {id: 15}), (n16:Machine {id: 16})
MERGE (n15)-[f22:FEEDS_INTO]->(n16)
SET f22.THROUGHPUT_RATE = 20;

MATCH (n16:Machine {id: 16}), (n17:Machine {id: 17})
MERGE (n16)-[f23:FEEDS_INTO]->(n17)
SET f23.THROUGHPUT_RATE = 20;

MATCH (n17:Machine {id: 17}), (n18:Machine {id: 18})
MERGE (n17)-[f24:FEEDS_INTO]->(n18)
SET f24.THROUGHPUT_RATE = 20;

MATCH (n18:Machine {id: 18}), (n19:Machine {id: 19})
MERGE (n18)-[f25:FEEDS_INTO]->(n19)
SET f25.THROUGHPUT_RATE = 20;

MATCH (n19:Machine {id: 19}), (n20:Machine {id: 20})
MERGE (n19)-[f26:FEEDS_INTO]->(n20)
SET f26.THROUGHPUT_RATE = 20;

MATCH (n3:Machine {id: 3}), (n11:Machine {id: 11})
MERGE (n3)-[f27:FEEDS_INTO]->(n11)
SET f27.THROUGHPUT_RATE = 120;

MATCH (n10:Machine {id: 10}), (n19:Machine {id: 19})
MERGE (n10)-[f28:FEEDS_INTO]->(n19)
SET f28.THROUGHPUT_RATE = 19;
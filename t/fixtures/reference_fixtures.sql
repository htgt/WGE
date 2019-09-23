INSERT INTO species (numerical_id, id, display_name, active) VALUES (1,'Human', 'Human (GRCh37)', 't'), (2,'Mouse', 'Mouse (GRCm38)', 't'), (3, 'Pig', 'Pig (Sscrofa10.2)', 'f'), (4, 'Grch38', 'Human (GRCh38)', 't');

INSERT INTO crispr_pair_statuses VALUES
    (-2, 'Too many individual off targets'),
    (-1, 'Error'),
    (0, 'Not started'),
    (1, 'Pending'),
    (2, 'Finding individual off targets'),
    (3, 'Persisting individual off targets'),
    (4, 'Calculating paired off targets'),
    (5, 'Complete');

INSERT INTO assemblies
VALUES ('GRCh37','Human'),('GRCm38','Mouse'), ('GRCh38', 'Human');

INSERT INTO species_default_assembly
VALUES ('Human','GRCh38'),
       ('Mouse','GRCm38');

INSERT INTO users (id, name, password)
VALUES (100, 'guest','guest'),
       (101, 'unknown','unknown'),
       (102, 'known', 'known');

INSERT INTO haplotype (id, species_id, name, source, restricted)
VALUES (100, 'Human', 'Hap1', 'haplotype_test', '{}'),
       (101, 'Human', 'Hap2', 'haplotype_test', '{"*"}'),
       (102, 'Human', 'Hap3', 'haplotype_test', '{"X", "Y"}');

INSERT INTO user_haplotype (user_id, haplotype_id)
VALUES (101, 101),
       (102, 101),
       (102, 102);

INSERT INTO design_types (id)
VALUES ('gibson'),
       ('gibson-deletion');

INSERT INTO design_oligo_types (id)
VALUES ('G5'),('U5'),('U3'),('D5'),('D3'),('G3'),('5F'),('5R'),('EF'),('ER'),('3F'),('3R');

INSERT INTO chromosomes (id, species_id, name)
VALUES
(1,'Mouse','1'),
(2,'Mouse','2'),
(3,'Mouse','3'),
(4,'Mouse','4'),
(5,'Mouse','5'),
(6,'Mouse','6'),
(7,'Mouse','7'),
(8,'Mouse','8'),
(9,'Mouse','9'),
(10,'Mouse','10'),
(11,'Mouse','11'),
(12,'Mouse','12'),
(13,'Mouse','13'),
(14,'Mouse','14'),
(15,'Mouse','15'),
(16,'Mouse','16'),
(17,'Mouse','17'),
(18,'Mouse','18'),
(19,'Mouse','19'),
(20,'Mouse','X'),
(21,'Mouse','Y'),
(22,'Human','1'),
(23,'Human','2'),
(24,'Human','3'),
(25,'Human','4'),
(26,'Human','5'),
(27,'Human','6'),
(28,'Human','7'),
(29,'Human','8'),
(30,'Human','9'),
(31,'Human','10'),
(32,'Human','11'),
(33,'Human','12'),
(34,'Human','13'),
(35,'Human','14'),
(36,'Human','15'),
(37,'Human','16'),
(38,'Human','17'),
(39,'Human','18'),
(40,'Human','19'),
(41,'Human','20'),
(42,'Human','21'),
(43,'Human','22'),
(44,'Human','X'),
(45,'Human','Y');


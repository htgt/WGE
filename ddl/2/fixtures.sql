INSERT INTO species (name) VALUES ('Human'), ('Mouse');

INSERT INTO crispr_pair_statuses VALUES
    (-1, 'error'),
    (0, 'not started'),
    (1, 'pending'),
    (2, 'finding individual off targets'),
    (3, 'persisting individual off targets'),
    (4, 'calculating paired off targets'),
    (5, 'complete');

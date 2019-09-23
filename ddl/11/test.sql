--run this in your test environment
--needed for the tests
CREATE TABLE haplotype_test (
    id SERIAL PRIMARY KEY,
    chrom TEXT NOT NULL,
    pos INTEGER NOT NULL,
    ref TEXT NOT NULL,
    alt TEXT NOT NULL,
    qual NUMERIC,
    filter TEXT,
    genome_phasing TEXT
);

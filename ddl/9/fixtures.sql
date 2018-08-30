DROP TABLE IF EXISTS haplotype;
DROP TABLE IF EXISTS bob1;
DROP TABLE IF EXISTS bob2;
DROP TABLE IF EXISTS kolf2;
CREATE TABLE haplotype (
    id TEXT PRIMARY KEY NOT NULL,
    species_id TEXT NOT NULL REFERENCES species(id),
    restricted BOOLEAN NOT NULL
);
CREATE TABLE bob1 (
    id SERIAL PRIMARY KEY,
    chrom TEXT NOT NULL,
    pos INTEGER NOT NULL,
    ref TEXT NOT NULL,
    alt TEXT NOT NULL,
    qual NUMERIC,
    filter TEXT,
    genome_phasing TEXT
);
CREATE TABLE bob2 (
    id SERIAL PRIMARY KEY,
    chrom TEXT NOT NULL,
    pos INTEGER NOT NULL,
    ref TEXT NOT NULL,
    alt TEXT NOT NULL,
    qual NUMERIC,
    filter TEXT,
    genome_phasing TEXT
);
CREATE TABLE kolf2 (
    id SERIAL PRIMARY KEY,
    chrom TEXT NOT NULL,
    pos INTEGER NOT NULL,
    ref TEXT NOT NULL,
    alt TEXT NOT NULL,
    qual NUMERIC,
    filter TEXT,
    genome_phasing TEXT
);
CREATE TABLE user_haplotype (
    user_id INTEGER NOT NULL REFERENCES users(id),
    haplotype_id TEXT NOT NULL REFERENCES haplotype(id)
);
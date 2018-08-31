CREATE TABLE IF NOT EXISTS feature_type (
    id TEXT NOT NULL PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS gene_set (
    id TEXT NOT NULL PRIMARY KEY,   
    species_id TEXT NOT NULL REFERENCES species(id)
);

CREATE TABLE refseq (
    id TEXT NOT NULL PRIMARY KEY,
    feature_type_id TEXT NOT NULL REFERENCES feature_type(id),
    chr_name TEXT NOT NULL,
    chr_start INTEGER NOT NULL,
    chr_end INTEGER NOT NULL,
    strand INTEGER NOT NULL,
    rank INTEGER NOT NULL,
    name TEXT,
    parent_id TEXT REFERENCES refseq(id),
    gene_type TEXT,
    gene_id TEXT,
    transcript_id TEXT,
    protein_id TEXT,
    biotype TEXT,
    description TEXT
);

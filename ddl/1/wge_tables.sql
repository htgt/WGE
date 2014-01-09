CREATE TABLE species (
    id                TEXT PRIMARY KEY
);

INSERT INTO species VALUES ('Human'), ('Mouse');

CREATE TABLE genes (
    id                   SERIAL PRIMARY KEY,
    species_id           TEXT NOT NULL REFERENCES species(id),
    marker_symbol        TEXT NOT NULL,
    ensembl_gene_id      TEXT NOT NULL,
    strand               INTEGER NOT NULL,
    chr_start            INTEGER NOT NULL,
    chr_end              INTEGER NOT NULL,
    chr_name             TEXT NOT NULL,
    canonical_transcript TEXT NOT NULL,
    UNIQUE ( ensembl_gene_id ),
    UNIQUE ( species_id, marker_symbol )
);

CREATE INDEX idx_gene_loci ON genes (chr_name, chr_start, chr_end);

CREATE TABLE exons (
    id                SERIAL PRIMARY KEY,
    ensembl_exon_id   TEXT NOT NULL,
    gene_id           INTEGER NOT NULL REFERENCES genes(id),
    chr_start         INTEGER NOT NULL,
    chr_end           INTEGER NOT NULL,
    chr_name          TEXT NOT NULL,
    rank              INTEGER NOT NULL,
    UNIQUE ( ensembl_exon_id )
);

CREATE INDEX idx_exon_loci ON exons (chr_name, chr_start, chr_end);

CREATE TABLE crisprs (
    id                SERIAL PRIMARY KEY,
    chr_start         INTEGER NOT NULL,
    chr_end           INTEGER NOT NULL,
    chr_name          TEXT NOT NULL,
    seq               TEXT NOT NULL,
    pam_right         BOOLEAN NOT NULL,
    species_id        TEXT NOT NULL REFERENCES species(id),
    UNIQUE ( chr_start, chr_end, chr_name, pam_right, species_id )
);

CREATE INDEX idx_crispr_loci ON crisprs (chr_name, chr_start, chr_end);

CREATE TABLE crispr_pairs (
    id                SERIAL PRIMARY KEY,
    left_crispr_id    INTEGER NOT NULL REFERENCES crisprs(id),
    right_crispr_id   INTEGER NOT NULL REFERENCES crisprs(id),
    spacer            INTEGER NOT NULL,
    UNIQUE( left_crispr_id, right_crispr_id )
);

CREATE INDEX idx_crispr_pair_left ON crispr_pairs (left_crispr_id);
CREATE INDEX idx_crispr_pair_right ON crispr_pairs (right_crispr_id);

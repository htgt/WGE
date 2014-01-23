CREATE TABLE species (
    numerical_id      SERIAL PRIMARY KEY,
    id                TEXT NOT NULL
    UNIQUE ( id )
);

INSERT INTO species (numerical_id, id) VALUES (1, 'Human'), (2, 'Mouse');

CREATE TABLE genes (
    id                   SERIAL PRIMARY KEY,
    species_id           INTEGER NOT NULL REFERENCES species(id),
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

CREATE INDEX idx_gene_loci ON genes (chr_name, chr_start, chr_end, species_id);

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
CREATE INDEX idx_gene_id ON exons (gene_id);

CREATE TABLE crisprs (
    id                 SERIAL PRIMARY KEY,
    chr_name           TEXT NOT NULL,
    chr_start          INTEGER NOT NULL,
    seq                TEXT NOT NULL,
    pam_right          BOOLEAN NOT NULL,
    species_id         INTEGER NOT NULL,
    off_targets        INTEGER[],
    off_target_summary TEXT,
    UNIQUE ( chr_start, chr_name, pam_right )
);

-- create child tables that the data will actually be stored in
CREATE TABLE crisprs_human ( CHECK (species_id=1) ) inherits (crisprs);
CREATE TABLE crisprs_mouse ( CHECK (species_id=2) ) inherits (crisprs);

ALTER TABLE crisprs_human ADD CONSTRAINT crispr_human_unique_loci UNIQUE ( chr_start, chr_name, pam_right );
ALTER TABLE crisprs_human ADD CONSTRAINT crisprs_pkey PRIMARY KEY (id);

ALTER TABLE crisprs_mouse ADD CONSTRAINT crispr_mouse_unique_loci UNIQUE ( chr_start, chr_name, pam_right );
ALTER TABLE crisprs_mouse ADD CONSTRAINT crisprs_pkey PRIMARY KEY (id);

CREATE INDEX idx_crispr_human_loci ON crisprs_human (chr_name, chr_start);
CREATE INDEX idx_crispr_mouse_loci ON crisprs_mouse (chr_name, chr_start);

-- add in insert trigger, but data should explicitly be entered into the right table with copy.
-- update/delete work as normal, but you should specify a species_id even if you have an id
CREATE OR REPLACE FUNCTION crispr_insert_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF ( NEW.SPECIES_ID = 1 ) THEN 
        INSERT INTO crisprs_human VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 2 ) THEN
        INSERT INTO crisprs_mouse VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Invalid species_id given to crispr_insert_trigger()';
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER insert_crisprs_trigger 
    BEFORE INSERT ON crisprs 
    FOR EACH ROW EXECUTE PROCEDURE crispr_insert_trigger();

CREATE TABLE crispr_pairs (
    left_id         INTEGER NOT NULL REFERENCES crisprs(id),
    right_id        INTEGER NOT NULL REFERENCES crisprs(id),
    spacer          INTEGER NOT NULL,
    left_ots        INTEGER[],
    right_ots       INTEGER[],
    PRIMARY KEY(left_id, right_id)
);

CREATE INDEX idx_crispr_pair_left ON crispr_pairs (left_id);
CREATE INDEX idx_crispr_pair_right ON crispr_pairs (right_id);

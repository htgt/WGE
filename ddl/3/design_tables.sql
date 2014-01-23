CREATE TABLE assemblies (
       id            TEXT PRIMARY KEY,
       species_id    TEXT NOT NULL REFERENCES species(id)
);

CREATE TABLE chromosomes (
       id            TEXT PRIMARY KEY,
       species_id    TEXT NOT NULL REFERENCES species(id),
       name          TEXT NOT NULL
);

CREATE TABLE species_default_assembly (
       species_id   TEXT PRIMARY KEY REFERENCES species(id),
       assembly_id  TEXT NOT NULL REFERENCES assemblies(id)
);

CREATE TABLE users (
       id        SERIAL PRIMARY KEY,
       name      TEXT NOT NULL UNIQUE CHECK (name <> ''),
       password  TEXT
);

CREATE TABLE design_types (
       id    TEXT PRIMARY KEY
);

CREATE TABLE genotyping_primer_types (
       id TEXT PRIMARY KEY
);

CREATE TABLE design_comment_categories (
       id   SERIAL PRIMARY KEY,
       name TEXT NOT NULL UNIQUE
);

CREATE TABLE design_oligo_types (
       id TEXT PRIMARY KEY
);

--
-- Design Specific Tables 
--

CREATE SEQUENCE designs_id_seq;

CREATE TABLE designs (
       id                       INTEGER PRIMARY KEY DEFAULT nextval('designs_id_seq'),
       species_id               TEXT NOT NULL REFERENCES species(id),
       name                     TEXT,
       created_by               INTEGER NOT NULL REFERENCES users(id),
       created_at               TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       design_type_id           TEXT NOT NULL REFERENCES design_types(id),
       phase                    INTEGER CHECK (phase IN (-1, 0, 1, 2)),
       validated_by_annotation  TEXT NOT NULL CHECK (validated_by_annotation IN ( 'yes', 'no', 'maybe', 'not done' )),
       target_transcript        TEXT,
       design_parameters        TEXT,
       cassette_first           BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE design_oligos (
       id                   SERIAL PRIMARY KEY,
       design_id            INTEGER NOT NULL REFERENCES designs(id),
       design_oligo_type_id TEXT NOT NULL REFERENCES design_oligo_types(id),
       seq                  TEXT NOT NULL,
       UNIQUE(design_id, design_oligo_type_id)
);

CREATE TABLE design_oligo_loci (
       design_oligo_id      INTEGER NOT NULL REFERENCES design_oligos(id),
       assembly_id          TEXT NOT NULL REFERENCES assemblies(id),
       chr_id               TEXT NOT NULL REFERENCES chromosomes(id),
       chr_start            INTEGER NOT NULL,
       chr_end              INTEGER NOT NULL,
       chr_strand           INTEGER NOT NULL CHECK (chr_strand IN (1, -1)),
       PRIMARY KEY (design_oligo_id, assembly_id),
       CHECK ( chr_start <= chr_end )
);

CREATE TABLE gene_design (
       gene_id           TEXT NOT NULL,
       design_id         INTEGER NOT NULL REFERENCES designs(id),
       created_by        INTEGER NOT NULL REFERENCES users(id),
       created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       gene_type_id      TEXT NOT NULL,
       PRIMARY KEY(gene_id, design_id)
);

CREATE TABLE design_comments (
       id                         SERIAL PRIMARY KEY,
       design_comment_category_id INTEGER NOT NULL REFERENCES design_comment_categories(id),
       design_id                  INTEGER NOT NULL REFERENCES designs(id),
       comment_text               TEXT NOT NULL DEFAULT '',
       is_public                  BOOLEAN NOT NULL DEFAULT FALSE,
       created_by                 INTEGER NOT NULL REFERENCES users(id),
       created_at                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE genotyping_primers (
       id                        SERIAL PRIMARY KEY,
       genotyping_primer_type_id TEXT NOT NULL REFERENCES genotyping_primer_types(id),
       design_id                 INTEGER NOT NULL REFERENCES designs(id),
       seq                       TEXT NOT NULL
);

CREATE TABLE design_attempts (
    id                SERIAL PRIMARY KEY,
    design_parameters TEXT,
    gene_id           TEXT,
    status            TEXT,
    fail              TEXT,
    error             TEXT,
    design_ids        TEXT,
    species_id        TEXT NOT NULL REFERENCES species(id),
    created_by        INTEGER NOT NULL REFERENCES users(id),
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comment           TEXT
);

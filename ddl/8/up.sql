-- species changes
ALTER TABLE species ADD COLUMN display_name text;
ALTER TABLE species ADD COLUMN active boolean not null default 'f';

--update existing rows so we can set not null
UPDATE species SET display_name='Human (GRCh37)', active='t' WHERE id='Human';
UPDATE species SET display_name='Mouse (GRCm38)', active='t' WHERE id='Mouse';

ALTER TABLE species ALTER COLUMN display_name SET not null;

INSERT INTO species (numerical_id, id, display_name, active) VALUES
(3, 'Pig', 'Pig (Sscrofa10.2)', 'f'),
(4, 'Grch38', 'Human (GRCh38)', 't');

-- modify constraints to allow non unique ensembl exon/gene ids
ALTER TABLE genes DROP CONSTRAINT genes_ensembl_gene_id_key;
ALTER TABLE genes ADD CONSTRAINT genes_ensembl_gene_id_key UNIQUE (ensembl_gene_id, species_id);

ALTER TABLE exons DROP CONSTRAINT exons_ensembl_exon_id_key;
ALTER TABLE exons ADD CONSTRAINT exons_ensembl_exon_id_key UNIQUE (ensembl_exon_id, gene_id);

-- new crispr tables
CREATE TABLE crisprs_grch38 ( CHECK (species_id=4) ) INHERITS (crisprs);
ALTER TABLE crisprs_grch38 ADD CONSTRAINT crisprs_grch38_pkey PRIMARY KEY (id);
ALTER TABLE ONLY crisprs_grch38 ADD CONSTRAINT crisprs_grch38_unique_loci UNIQUE (chr_start, chr_name, pam_right);
CREATE INDEX idx_crisprs_grch38_loci ON crisprs_grch38 USING btree (chr_name, chr_start);

CREATE OR REPLACE FUNCTION crispr_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF ( NEW.SPECIES_ID = 1 ) THEN
        INSERT INTO crisprs_human VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 2 ) THEN
        INSERT INTO crisprs_mouse VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 3 ) THEN
        INSERT INTO crisprs_pig VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 4 ) THEN
        INSERT INTO crisprs_grch38 VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Invalid species_id given to crispr_insert_trigger()';
    END IF;
    RETURN NULL;
END;
$$;

--pair tables
CREATE TABLE crispr_pairs_grch38 (
    CONSTRAINT crispr_pairs_grch38_species_id_check CHECK ((species_id = 4))
)
INHERITS (crispr_pairs);
ALTER TABLE ONLY crispr_pairs_grch38 ADD CONSTRAINT crispr_pairs_grch38_pkey PRIMARY KEY (left_id, right_id);
ALTER TABLE ONLY crispr_pairs_grch38 ADD CONSTRAINT unique_grch38_pair_id UNIQUE (id);
CREATE INDEX idx_crisprs_grch38_id ON crispr_pairs_grch38 USING btree (id);
ALTER TABLE ONLY crispr_pairs_grch38 ADD CONSTRAINT crispr_pairs_grch38_left_id_fkey FOREIGN KEY (left_id) REFERENCES crisprs_grch38(id);
ALTER TABLE ONLY crispr_pairs_grch38 ADD CONSTRAINT crispr_pairs_grch38_right_id_fkey FOREIGN KEY (right_id) REFERENCES crisprs_grch38(id);
ALTER TABLE ONLY crispr_pairs_grch38 ADD CONSTRAINT crispr_pairs_status_fkey FOREIGN KEY (status_id) REFERENCES crispr_pair_statuses(id);

CREATE TRIGGER crispr_pairs_grch38_update_time BEFORE UPDATE ON crispr_pairs_grch38 FOR EACH ROW EXECUTE PROCEDURE crispr_pairs_update_trigger();

CREATE OR REPLACE FUNCTION crispr_pairs_insert_trigger() RETURNS trigger    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.id = NEW.left_id || '_' || NEW.right_id;
    IF ( NEW.SPECIES_ID = 1 ) THEN
        INSERT INTO crispr_pairs_human VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 2 ) THEN
        INSERT INTO crispr_pairs_mouse VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 4 ) THEN
        INSERT INTO crispr_pairs_grch38 VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Invalid species_id given to crispr_pairs_insert_trigger()';                                                                                END IF;
    RETURN NULL;
END;
$$;

-- user tables
CREATE TABLE user_crisprs_grch38 (
       crispr_id  INTEGER NOT NULL REFERENCES crisprs_grch38(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY(crispr_id, user_id)
);
CREATE TABLE user_crispr_pairs_grch38 (
       crispr_pair_id  TEXT NOT NULL REFERENCES crispr_pairs_grch38(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY(crispr_pair_id, user_id)
);
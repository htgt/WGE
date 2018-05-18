--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: wge; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE wge WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_GB.UTF-8' LC_CTYPE = 'en_GB.UTF-8';


ALTER DATABASE wge OWNER TO postgres;

\connect wge

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: crispr_insert_trigger(); Type: FUNCTION; Schema: public; Owner: wge_admin
--

CREATE FUNCTION crispr_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF ( NEW.SPECIES_ID = 1 ) THEN
        INSERT INTO crisprs_human VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 2 ) THEN
        INSERT INTO crisprs_mouse VALUES (NEW.*);
    ELSIF ( NEW.SPECIES_ID = 4 ) THEN
        INSERT INTO crisprs_grch38 VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Invalid species_id given to crispr_insert_trigger()';
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.crispr_insert_trigger() OWNER TO wge_admin;

--
-- Name: crispr_pairs_insert_trigger(); Type: FUNCTION; Schema: public; Owner: wge_admin
--

CREATE FUNCTION crispr_pairs_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
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
        RAISE EXCEPTION 'Invalid species_id given to crispr_pairs_insert_trigger()';
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.crispr_pairs_insert_trigger() OWNER TO wge_admin;

--
-- Name: crispr_pairs_update_trigger(); Type: FUNCTION; Schema: public; Owner: wge_admin
--

CREATE FUNCTION crispr_pairs_update_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.last_modified = NOW();
    NEW.id = NEW.left_id || '_' || NEW.right_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.crispr_pairs_update_trigger() OWNER TO wge_admin;

--
-- Name: update_library_design_job_modified(); Type: FUNCTION; Schema: public; Owner: wge_admin
--

CREATE FUNCTION update_library_design_job_modified() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.last_modified = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_library_design_job_modified() OWNER TO wge_admin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: assemblies; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE assemblies (
    id text NOT NULL,
    species_id text NOT NULL
);


ALTER TABLE public.assemblies OWNER TO wge_admin;

--
-- Name: chromosomes; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE chromosomes (
    id text NOT NULL,
    species_id text NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.chromosomes OWNER TO wge_admin;

--
-- Name: crispr_ots_pending; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crispr_ots_pending (
    crispr_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.crispr_ots_pending OWNER TO wge_admin;

--
-- Name: crispr_pair_statuses; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crispr_pair_statuses (
    id integer NOT NULL,
    status text NOT NULL
);


ALTER TABLE public.crispr_pair_statuses OWNER TO wge_admin;

--
-- Name: crispr_pairs; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crispr_pairs (
    left_id integer NOT NULL,
    right_id integer NOT NULL,
    spacer integer NOT NULL,
    off_target_ids integer[],
    status_id integer DEFAULT 0,
    species_id integer NOT NULL,
    off_target_summary text,
    last_modified timestamp without time zone DEFAULT now(),
    id text NOT NULL
);


ALTER TABLE public.crispr_pairs OWNER TO wge_admin;

--
-- Name: crispr_pairs_grch38; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crispr_pairs_grch38 (
    CONSTRAINT crispr_pairs_grch38_species_id_check CHECK ((species_id = 4))
)
INHERITS (crispr_pairs);


ALTER TABLE public.crispr_pairs_grch38 OWNER TO wge_admin;

--
-- Name: crispr_pairs_human; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crispr_pairs_human (
    CONSTRAINT crispr_pairs_human_species_id_check CHECK ((species_id = 1))
)
INHERITS (crispr_pairs);


ALTER TABLE public.crispr_pairs_human OWNER TO wge_admin;

--
-- Name: crispr_pairs_mouse; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crispr_pairs_mouse (
    CONSTRAINT crispr_pairs_mouse_species_id_check CHECK ((species_id = 2))
)
INHERITS (crispr_pairs);


ALTER TABLE public.crispr_pairs_mouse OWNER TO wge_admin;

--
-- Name: crisprs; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crisprs (
    id integer NOT NULL,
    chr_name text NOT NULL,
    chr_start integer NOT NULL,
    seq text NOT NULL,
    pam_right boolean NOT NULL,
    species_id integer NOT NULL,
    off_target_ids integer[],
    off_target_summary text,
    exonic boolean DEFAULT false NOT NULL,
    genic boolean DEFAULT false NOT NULL
);


ALTER TABLE public.crisprs OWNER TO wge_admin;

--
-- Name: crisprs_grch38; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crisprs_grch38 (
    CONSTRAINT crisprs_grch38_species_id_check CHECK ((species_id = 4))
)
INHERITS (crisprs);


ALTER TABLE public.crisprs_grch38 OWNER TO wge_admin;

--
-- Name: crisprs_human; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crisprs_human (
    id integer,
    chr_name text,
    chr_start integer,
    seq text,
    pam_right boolean,
    species_id integer,
    off_target_ids integer[],
    off_target_summary text,
    CONSTRAINT crisprs_human_species_id_check CHECK ((species_id = 1))
)
INHERITS (crisprs);


ALTER TABLE public.crisprs_human OWNER TO wge_admin;

--
-- Name: crisprs_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE crisprs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.crisprs_id_seq OWNER TO wge_admin;

--
-- Name: crisprs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE crisprs_id_seq OWNED BY crisprs_human.id;


--
-- Name: crisprs_mouse; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE crisprs_mouse (
    CONSTRAINT crispr_pairs_mouse_species_id_check CHECK ((species_id = 2))
)
INHERITS (crisprs);


ALTER TABLE public.crisprs_mouse OWNER TO wge_admin;

--
-- Name: design_attempts; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_attempts (
    id integer NOT NULL,
    design_parameters json,
    gene_id text,
    status text,
    fail json,
    error text,
    design_ids integer[],
    species_id text NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    comment text,
    candidate_oligos json,
    candidate_regions json
);


ALTER TABLE public.design_attempts OWNER TO wge_admin;

--
-- Name: design_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE design_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.design_attempts_id_seq OWNER TO wge_admin;

--
-- Name: design_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE design_attempts_id_seq OWNED BY design_attempts.id;


--
-- Name: design_comment_categories; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_comment_categories (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.design_comment_categories OWNER TO wge_admin;

--
-- Name: design_comment_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE design_comment_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.design_comment_categories_id_seq OWNER TO wge_admin;

--
-- Name: design_comment_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE design_comment_categories_id_seq OWNED BY design_comment_categories.id;


--
-- Name: design_comments; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_comments (
    id integer NOT NULL,
    design_comment_category_id integer NOT NULL,
    design_id integer NOT NULL,
    comment_text text DEFAULT ''::text NOT NULL,
    is_public boolean DEFAULT false NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.design_comments OWNER TO wge_admin;

--
-- Name: design_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE design_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.design_comments_id_seq OWNER TO wge_admin;

--
-- Name: design_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE design_comments_id_seq OWNED BY design_comments.id;


--
-- Name: design_oligo_loci; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_oligo_loci (
    design_oligo_id integer NOT NULL,
    assembly_id text NOT NULL,
    chr_id text NOT NULL,
    chr_start integer NOT NULL,
    chr_end integer NOT NULL,
    chr_strand integer NOT NULL,
    CONSTRAINT design_oligo_loci_check CHECK ((chr_start <= chr_end)),
    CONSTRAINT design_oligo_loci_chr_strand_check CHECK ((chr_strand = ANY (ARRAY[1, (-1)])))
);


ALTER TABLE public.design_oligo_loci OWNER TO wge_admin;

--
-- Name: design_oligo_types; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_oligo_types (
    id text NOT NULL
);


ALTER TABLE public.design_oligo_types OWNER TO wge_admin;

--
-- Name: design_oligos; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_oligos (
    id integer NOT NULL,
    design_id integer NOT NULL,
    design_oligo_type_id text NOT NULL,
    seq text NOT NULL
);


ALTER TABLE public.design_oligos OWNER TO wge_admin;

--
-- Name: design_oligos_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE design_oligos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.design_oligos_id_seq OWNER TO wge_admin;

--
-- Name: design_oligos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE design_oligos_id_seq OWNED BY design_oligos.id;


--
-- Name: design_types; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE design_types (
    id text NOT NULL
);


ALTER TABLE public.design_types OWNER TO wge_admin;

--
-- Name: designs_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE designs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.designs_id_seq OWNER TO wge_admin;

--
-- Name: designs; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE designs (
    id integer DEFAULT nextval('designs_id_seq'::regclass) NOT NULL,
    species_id text NOT NULL,
    name text,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    design_type_id text NOT NULL,
    phase integer,
    validated_by_annotation text NOT NULL,
    target_transcript text,
    design_parameters json,
    cassette_first boolean DEFAULT true NOT NULL,
    CONSTRAINT designs_phase_check CHECK ((phase = ANY (ARRAY[(-1), 0, 1, 2]))),
    CONSTRAINT designs_validated_by_annotation_check CHECK ((validated_by_annotation = ANY (ARRAY['yes'::text, 'no'::text, 'maybe'::text, 'not done'::text])))
);


ALTER TABLE public.designs OWNER TO wge_admin;

--
-- Name: exons; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE exons (
    id integer NOT NULL,
    ensembl_exon_id text NOT NULL,
    gene_id integer NOT NULL,
    chr_start integer NOT NULL,
    chr_end integer NOT NULL,
    chr_name text NOT NULL,
    rank integer NOT NULL
);


ALTER TABLE public.exons OWNER TO wge_admin;

--
-- Name: exons_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE exons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exons_id_seq OWNER TO wge_admin;

--
-- Name: exons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE exons_id_seq OWNED BY exons.id;


--
-- Name: gene_design; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE gene_design (
    gene_id text NOT NULL,
    design_id integer NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    gene_type_id text NOT NULL
);


ALTER TABLE public.gene_design OWNER TO wge_admin;

--
-- Name: genes; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE genes (
    id integer NOT NULL,
    species_id text NOT NULL,
    marker_symbol text NOT NULL,
    ensembl_gene_id text NOT NULL,
    chr_start integer NOT NULL,
    chr_end integer NOT NULL,
    chr_name text NOT NULL,
    strand integer NOT NULL,
    canonical_transcript text NOT NULL
);


ALTER TABLE public.genes OWNER TO wge_admin;

--
-- Name: genes_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE genes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.genes_id_seq OWNER TO wge_admin;

--
-- Name: genes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE genes_id_seq OWNED BY genes.id;


--
-- Name: genotyping_primer_types; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE genotyping_primer_types (
    id text NOT NULL
);


ALTER TABLE public.genotyping_primer_types OWNER TO wge_admin;

--
-- Name: genotyping_primers; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE genotyping_primers (
    id integer NOT NULL,
    genotyping_primer_type_id text NOT NULL,
    design_id integer NOT NULL,
    seq text NOT NULL
);


ALTER TABLE public.genotyping_primers OWNER TO wge_admin;

--
-- Name: genotyping_primers_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE genotyping_primers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.genotyping_primers_id_seq OWNER TO wge_admin;

--
-- Name: genotyping_primers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE genotyping_primers_id_seq OWNED BY genotyping_primers.id;


--
-- Name: library_design_jobs; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE library_design_jobs (
    id text NOT NULL,
    name text NOT NULL,
    params json NOT NULL,
    target_region_count integer NOT NULL,
    library_design_stage_id text,
    progress_percent integer NOT NULL,
    complete boolean DEFAULT false NOT NULL,
    error text,
    warning text,
    results_file text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_id integer NOT NULL,
    last_modified timestamp without time zone DEFAULT now() NOT NULL,
    info text,
    input_file text
);


ALTER TABLE public.library_design_jobs OWNER TO wge_admin;

--
-- Name: library_design_stages; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE library_design_stages (
    id text NOT NULL,
    description text NOT NULL,
    rank integer NOT NULL
);


ALTER TABLE public.library_design_stages OWNER TO wge_admin;

--
-- Name: species; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE species (
    numerical_id integer NOT NULL,
    id text NOT NULL,
    display_name text NOT NULL,
    active boolean DEFAULT false NOT NULL
);


ALTER TABLE public.species OWNER TO wge_admin;

--
-- Name: species_default_assembly; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE species_default_assembly (
    species_id text NOT NULL,
    assembly_id text NOT NULL
);


ALTER TABLE public.species_default_assembly OWNER TO wge_admin;

--
-- Name: species_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE species_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.species_id_seq OWNER TO wge_admin;

--
-- Name: species_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE species_id_seq OWNED BY species.numerical_id;


--
-- Name: user_crispr_pairs_grch38; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE user_crispr_pairs_grch38 (
    crispr_pair_id text NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_crispr_pairs_grch38 OWNER TO wge_admin;

--
-- Name: user_crispr_pairs_human; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE user_crispr_pairs_human (
    crispr_pair_id text NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_crispr_pairs_human OWNER TO wge_admin;

--
-- Name: user_crispr_pairs_mouse; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE user_crispr_pairs_mouse (
    crispr_pair_id text NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_crispr_pairs_mouse OWNER TO wge_admin;

--
-- Name: user_crisprs_grch38; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE user_crisprs_grch38 (
    crispr_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_crisprs_grch38 OWNER TO wge_admin;

--
-- Name: user_crisprs_human; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE user_crisprs_human (
    crispr_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_crisprs_human OWNER TO wge_admin;

--
-- Name: user_crisprs_mouse; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE user_crisprs_mouse (
    crispr_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_crisprs_mouse OWNER TO wge_admin;

--
-- Name: users; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    name text NOT NULL,
    password text,
    CONSTRAINT users_name_check CHECK ((name <> ''::text))
);


ALTER TABLE public.users OWNER TO wge_admin;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO wge_admin;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: variant_call_format; Type: TABLE; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE TABLE variant_call_format (
    id integer NOT NULL,
    chrom text NOT NULL,
    pos integer NOT NULL,
    vcf_id text,
    ref text NOT NULL,
    alt text,
    qual numeric,
    filter text,
    info text,
    format text,
    genome_phasing text
);


ALTER TABLE public.variant_call_format OWNER TO wge_admin;

--
-- Name: variant_call_format_id_seq; Type: SEQUENCE; Schema: public; Owner: wge_admin
--

CREATE SEQUENCE variant_call_format_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variant_call_format_id_seq OWNER TO wge_admin;

--
-- Name: variant_call_format_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wge_admin
--

ALTER SEQUENCE variant_call_format_id_seq OWNED BY variant_call_format.id;


--
-- Name: status_id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_grch38 ALTER COLUMN status_id SET DEFAULT 0;


--
-- Name: last_modified; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_grch38 ALTER COLUMN last_modified SET DEFAULT now();


--
-- Name: status_id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_human ALTER COLUMN status_id SET DEFAULT 0;


--
-- Name: last_modified; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_human ALTER COLUMN last_modified SET DEFAULT now();


--
-- Name: status_id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_mouse ALTER COLUMN status_id SET DEFAULT 0;


--
-- Name: last_modified; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_mouse ALTER COLUMN last_modified SET DEFAULT now();


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs ALTER COLUMN id SET DEFAULT nextval('crisprs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_grch38 ALTER COLUMN id SET DEFAULT nextval('crisprs_id_seq'::regclass);


--
-- Name: exonic; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_grch38 ALTER COLUMN exonic SET DEFAULT false;


--
-- Name: genic; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_grch38 ALTER COLUMN genic SET DEFAULT false;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_human ALTER COLUMN id SET DEFAULT nextval('crisprs_id_seq'::regclass);


--
-- Name: exonic; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_human ALTER COLUMN exonic SET DEFAULT false;


--
-- Name: genic; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_human ALTER COLUMN genic SET DEFAULT false;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_mouse ALTER COLUMN id SET DEFAULT nextval('crisprs_id_seq'::regclass);


--
-- Name: exonic; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_mouse ALTER COLUMN exonic SET DEFAULT false;


--
-- Name: genic; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crisprs_mouse ALTER COLUMN genic SET DEFAULT false;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_attempts ALTER COLUMN id SET DEFAULT nextval('design_attempts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_comment_categories ALTER COLUMN id SET DEFAULT nextval('design_comment_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_comments ALTER COLUMN id SET DEFAULT nextval('design_comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_oligos ALTER COLUMN id SET DEFAULT nextval('design_oligos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY exons ALTER COLUMN id SET DEFAULT nextval('exons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY genes ALTER COLUMN id SET DEFAULT nextval('genes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY genotyping_primers ALTER COLUMN id SET DEFAULT nextval('genotyping_primers_id_seq'::regclass);


--
-- Name: numerical_id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY species ALTER COLUMN numerical_id SET DEFAULT nextval('species_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY variant_call_format ALTER COLUMN id SET DEFAULT nextval('variant_call_format_id_seq'::regclass);


--
-- Name: assemblies_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY assemblies
    ADD CONSTRAINT assemblies_pkey PRIMARY KEY (id);


--
-- Name: chromosomes_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY chromosomes
    ADD CONSTRAINT chromosomes_pkey PRIMARY KEY (id);


--
-- Name: crispr_ots_pending_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_ots_pending
    ADD CONSTRAINT crispr_ots_pending_pkey PRIMARY KEY (crispr_id);


--
-- Name: crispr_pair_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pair_statuses
    ADD CONSTRAINT crispr_pair_statuses_pkey PRIMARY KEY (id);


--
-- Name: crispr_pairs_grch38_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs_grch38
    ADD CONSTRAINT crispr_pairs_grch38_pkey PRIMARY KEY (left_id, right_id);


--
-- Name: crispr_pairs_human_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs_human
    ADD CONSTRAINT crispr_pairs_human_pkey PRIMARY KEY (left_id, right_id);


--
-- Name: crispr_pairs_mouse_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs_mouse
    ADD CONSTRAINT crispr_pairs_mouse_pkey PRIMARY KEY (left_id, right_id);


--
-- Name: crispr_pairs_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs
    ADD CONSTRAINT crispr_pairs_pkey PRIMARY KEY (left_id, right_id);


--
-- Name: crisprs_grch38_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs_grch38
    ADD CONSTRAINT crisprs_grch38_pkey PRIMARY KEY (id);


--
-- Name: crisprs_grch38_unique_loci; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs_grch38
    ADD CONSTRAINT crisprs_grch38_unique_loci UNIQUE (chr_start, chr_name, pam_right);


--
-- Name: crisprs_human_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs_human
    ADD CONSTRAINT crisprs_human_pkey PRIMARY KEY (id);


--
-- Name: crisprs_human_unique_loci; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs_human
    ADD CONSTRAINT crisprs_human_unique_loci UNIQUE (chr_start, chr_name, pam_right);


--
-- Name: crisprs_mouse_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs_mouse
    ADD CONSTRAINT crisprs_mouse_pkey PRIMARY KEY (id);


--
-- Name: crisprs_mouse_unique_loci; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs_mouse
    ADD CONSTRAINT crisprs_mouse_unique_loci UNIQUE (chr_start, chr_name, pam_right);


--
-- Name: crisprs_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crisprs
    ADD CONSTRAINT crisprs_pkey PRIMARY KEY (id);


--
-- Name: design_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_attempts
    ADD CONSTRAINT design_attempts_pkey PRIMARY KEY (id);


--
-- Name: design_comment_categories_name_key; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_comment_categories
    ADD CONSTRAINT design_comment_categories_name_key UNIQUE (name);


--
-- Name: design_comment_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_comment_categories
    ADD CONSTRAINT design_comment_categories_pkey PRIMARY KEY (id);


--
-- Name: design_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_comments
    ADD CONSTRAINT design_comments_pkey PRIMARY KEY (id);


--
-- Name: design_oligo_loci_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_oligo_loci
    ADD CONSTRAINT design_oligo_loci_pkey PRIMARY KEY (design_oligo_id, assembly_id);


--
-- Name: design_oligo_types_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_oligo_types
    ADD CONSTRAINT design_oligo_types_pkey PRIMARY KEY (id);


--
-- Name: design_oligos_design_id_design_oligo_type_id_key; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_oligos
    ADD CONSTRAINT design_oligos_design_id_design_oligo_type_id_key UNIQUE (design_id, design_oligo_type_id);


--
-- Name: design_oligos_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_oligos
    ADD CONSTRAINT design_oligos_pkey PRIMARY KEY (id);


--
-- Name: design_types_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY design_types
    ADD CONSTRAINT design_types_pkey PRIMARY KEY (id);


--
-- Name: designs_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY designs
    ADD CONSTRAINT designs_pkey PRIMARY KEY (id);


--
-- Name: exons_ensembl_exon_id_key; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY exons
    ADD CONSTRAINT exons_ensembl_exon_id_key UNIQUE (ensembl_exon_id, gene_id);


--
-- Name: exons_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY exons
    ADD CONSTRAINT exons_pkey PRIMARY KEY (id);


--
-- Name: gene_design_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY gene_design
    ADD CONSTRAINT gene_design_pkey PRIMARY KEY (gene_id, design_id);


--
-- Name: genes_ensembl_gene_id_key; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY genes
    ADD CONSTRAINT genes_ensembl_gene_id_key UNIQUE (ensembl_gene_id, species_id);


--
-- Name: genes_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY genes
    ADD CONSTRAINT genes_pkey PRIMARY KEY (id);


--
-- Name: genes_species_id_marker_symbol_key; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY genes
    ADD CONSTRAINT genes_species_id_marker_symbol_key UNIQUE (species_id, marker_symbol);


--
-- Name: genotyping_primer_types_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY genotyping_primer_types
    ADD CONSTRAINT genotyping_primer_types_pkey PRIMARY KEY (id);


--
-- Name: genotyping_primers_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY genotyping_primers
    ADD CONSTRAINT genotyping_primers_pkey PRIMARY KEY (id);


--
-- Name: library_design_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY library_design_jobs
    ADD CONSTRAINT library_design_jobs_pkey PRIMARY KEY (id);


--
-- Name: library_design_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY library_design_stages
    ADD CONSTRAINT library_design_stages_pkey PRIMARY KEY (id);


--
-- Name: species_default_assembly_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY species_default_assembly
    ADD CONSTRAINT species_default_assembly_pkey PRIMARY KEY (species_id);


--
-- Name: species_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY species
    ADD CONSTRAINT species_pkey PRIMARY KEY (numerical_id);


--
-- Name: unique_grch38_pair_id; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs_grch38
    ADD CONSTRAINT unique_grch38_pair_id UNIQUE (id);


--
-- Name: unique_human_pair_id; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs_human
    ADD CONSTRAINT unique_human_pair_id UNIQUE (id);


--
-- Name: unique_mouse_pair_id; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs_mouse
    ADD CONSTRAINT unique_mouse_pair_id UNIQUE (id);


--
-- Name: unique_pair_id; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY crispr_pairs
    ADD CONSTRAINT unique_pair_id UNIQUE (id);


--
-- Name: unique_species; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY species
    ADD CONSTRAINT unique_species UNIQUE (id);


--
-- Name: user_crispr_pairs_grch38_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY user_crispr_pairs_grch38
    ADD CONSTRAINT user_crispr_pairs_grch38_pkey PRIMARY KEY (crispr_pair_id, user_id);


--
-- Name: user_crispr_pairs_human_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY user_crispr_pairs_human
    ADD CONSTRAINT user_crispr_pairs_human_pkey PRIMARY KEY (crispr_pair_id, user_id);


--
-- Name: user_crispr_pairs_mouse_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY user_crispr_pairs_mouse
    ADD CONSTRAINT user_crispr_pairs_mouse_pkey PRIMARY KEY (crispr_pair_id, user_id);


--
-- Name: user_crisprs_grch38_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY user_crisprs_grch38
    ADD CONSTRAINT user_crisprs_grch38_pkey PRIMARY KEY (crispr_id, user_id);


--
-- Name: user_crisprs_human_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY user_crisprs_human
    ADD CONSTRAINT user_crisprs_human_pkey PRIMARY KEY (crispr_id, user_id);


--
-- Name: user_crisprs_mouse_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY user_crisprs_mouse
    ADD CONSTRAINT user_crisprs_mouse_pkey PRIMARY KEY (crispr_id, user_id);


--
-- Name: users_name_key; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_name_key UNIQUE (name);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: variant_call_format_pkey; Type: CONSTRAINT; Schema: public; Owner: wge_admin; Tablespace: 
--

ALTER TABLE ONLY variant_call_format
    ADD CONSTRAINT variant_call_format_pkey PRIMARY KEY (id);


--
-- Name: idx_crisprs_grch38_id; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_crisprs_grch38_id ON crispr_pairs_grch38 USING btree (id);


--
-- Name: idx_crisprs_grch38_loci; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_crisprs_grch38_loci ON crisprs_grch38 USING btree (chr_name, chr_start);


--
-- Name: idx_crisprs_human_id; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_crisprs_human_id ON crispr_pairs_human USING btree (id);


--
-- Name: idx_crisprs_human_loci; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_crisprs_human_loci ON crisprs_human USING btree (chr_name, chr_start);


--
-- Name: idx_crisprs_mouse_id; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_crisprs_mouse_id ON crispr_pairs_mouse USING btree (id);


--
-- Name: idx_crisprs_mouse_loci; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_crisprs_mouse_loci ON crisprs_mouse USING btree (chr_name, chr_start);


--
-- Name: idx_exon_gene_id; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_exon_gene_id ON exons USING btree (gene_id);


--
-- Name: idx_exon_loci; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_exon_loci ON exons USING btree (chr_name, chr_start, chr_end);


--
-- Name: idx_gene_loci; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX idx_gene_loci ON genes USING btree (chr_name, chr_start, chr_end, species_id);


--
-- Name: variant_call_format_chrom_pos_seq; Type: INDEX; Schema: public; Owner: wge_admin; Tablespace: 
--

CREATE INDEX variant_call_format_chrom_pos_seq ON variant_call_format USING btree (chrom, pos);


--
-- Name: crispr_pairs_grch38_update_time; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER crispr_pairs_grch38_update_time BEFORE UPDATE ON crispr_pairs_grch38 FOR EACH ROW EXECUTE PROCEDURE crispr_pairs_update_trigger();


--
-- Name: crispr_pairs_human_update_time; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER crispr_pairs_human_update_time BEFORE UPDATE ON crispr_pairs_human FOR EACH ROW EXECUTE PROCEDURE crispr_pairs_update_trigger();


--
-- Name: crispr_pairs_mouse_update_time; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER crispr_pairs_mouse_update_time BEFORE UPDATE ON crispr_pairs_mouse FOR EACH ROW EXECUTE PROCEDURE crispr_pairs_update_trigger();


--
-- Name: crispr_pairs_update_time; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER crispr_pairs_update_time BEFORE UPDATE ON crispr_pairs FOR EACH ROW EXECUTE PROCEDURE crispr_pairs_update_trigger();


--
-- Name: insert_crispr_pairs_trigger; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER insert_crispr_pairs_trigger BEFORE INSERT ON crispr_pairs FOR EACH ROW EXECUTE PROCEDURE crispr_pairs_insert_trigger();


--
-- Name: insert_crisprs_trigger; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER insert_crisprs_trigger BEFORE INSERT ON crisprs FOR EACH ROW EXECUTE PROCEDURE crispr_insert_trigger();


--
-- Name: update_library_design_job; Type: TRIGGER; Schema: public; Owner: wge_admin
--

CREATE TRIGGER update_library_design_job BEFORE UPDATE ON library_design_jobs FOR EACH ROW EXECUTE PROCEDURE update_library_design_job_modified();


--
-- Name: assemblies_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY assemblies
    ADD CONSTRAINT assemblies_species_id_fkey FOREIGN KEY (species_id) REFERENCES species(id);


--
-- Name: chromosomes_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY chromosomes
    ADD CONSTRAINT chromosomes_species_id_fkey FOREIGN KEY (species_id) REFERENCES species(id);


--
-- Name: crispr_pairs_grch38_left_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_grch38
    ADD CONSTRAINT crispr_pairs_grch38_left_id_fkey FOREIGN KEY (left_id) REFERENCES crisprs_grch38(id);


--
-- Name: crispr_pairs_grch38_right_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_grch38
    ADD CONSTRAINT crispr_pairs_grch38_right_id_fkey FOREIGN KEY (right_id) REFERENCES crisprs_grch38(id);


--
-- Name: crispr_pairs_human_left_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_human
    ADD CONSTRAINT crispr_pairs_human_left_id_fkey FOREIGN KEY (left_id) REFERENCES crisprs_human(id);


--
-- Name: crispr_pairs_human_right_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_human
    ADD CONSTRAINT crispr_pairs_human_right_id_fkey FOREIGN KEY (right_id) REFERENCES crisprs_human(id);


--
-- Name: crispr_pairs_left_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs
    ADD CONSTRAINT crispr_pairs_left_id_fkey FOREIGN KEY (left_id) REFERENCES crisprs(id);


--
-- Name: crispr_pairs_mouse_left_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_mouse
    ADD CONSTRAINT crispr_pairs_mouse_left_id_fkey FOREIGN KEY (left_id) REFERENCES crisprs_mouse(id);


--
-- Name: crispr_pairs_mouse_right_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_mouse
    ADD CONSTRAINT crispr_pairs_mouse_right_id_fkey FOREIGN KEY (right_id) REFERENCES crisprs_mouse(id);


--
-- Name: crispr_pairs_right_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs
    ADD CONSTRAINT crispr_pairs_right_id_fkey FOREIGN KEY (right_id) REFERENCES crisprs(id);


--
-- Name: crispr_pairs_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs
    ADD CONSTRAINT crispr_pairs_status_fkey FOREIGN KEY (status_id) REFERENCES crispr_pair_statuses(id);


--
-- Name: crispr_pairs_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_mouse
    ADD CONSTRAINT crispr_pairs_status_fkey FOREIGN KEY (status_id) REFERENCES crispr_pair_statuses(id);


--
-- Name: crispr_pairs_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_human
    ADD CONSTRAINT crispr_pairs_status_fkey FOREIGN KEY (status_id) REFERENCES crispr_pair_statuses(id);


--
-- Name: crispr_pairs_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY crispr_pairs_grch38
    ADD CONSTRAINT crispr_pairs_status_fkey FOREIGN KEY (status_id) REFERENCES crispr_pair_statuses(id);


--
-- Name: design_attempts_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_attempts
    ADD CONSTRAINT design_attempts_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);


--
-- Name: design_attempts_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_attempts
    ADD CONSTRAINT design_attempts_species_id_fkey FOREIGN KEY (species_id) REFERENCES species(id);


--
-- Name: design_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_comments
    ADD CONSTRAINT design_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);


--
-- Name: design_comments_design_comment_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_comments
    ADD CONSTRAINT design_comments_design_comment_category_id_fkey FOREIGN KEY (design_comment_category_id) REFERENCES design_comment_categories(id);


--
-- Name: design_comments_design_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_comments
    ADD CONSTRAINT design_comments_design_id_fkey FOREIGN KEY (design_id) REFERENCES designs(id);


--
-- Name: design_oligo_loci_assembly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_oligo_loci
    ADD CONSTRAINT design_oligo_loci_assembly_id_fkey FOREIGN KEY (assembly_id) REFERENCES assemblies(id);


--
-- Name: design_oligo_loci_chr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_oligo_loci
    ADD CONSTRAINT design_oligo_loci_chr_id_fkey FOREIGN KEY (chr_id) REFERENCES chromosomes(id);


--
-- Name: design_oligo_loci_design_oligo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_oligo_loci
    ADD CONSTRAINT design_oligo_loci_design_oligo_id_fkey FOREIGN KEY (design_oligo_id) REFERENCES design_oligos(id);


--
-- Name: design_oligos_design_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_oligos
    ADD CONSTRAINT design_oligos_design_id_fkey FOREIGN KEY (design_id) REFERENCES designs(id);


--
-- Name: design_oligos_design_oligo_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY design_oligos
    ADD CONSTRAINT design_oligos_design_oligo_type_id_fkey FOREIGN KEY (design_oligo_type_id) REFERENCES design_oligo_types(id);


--
-- Name: designs_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY designs
    ADD CONSTRAINT designs_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);


--
-- Name: designs_design_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY designs
    ADD CONSTRAINT designs_design_type_id_fkey FOREIGN KEY (design_type_id) REFERENCES design_types(id);


--
-- Name: designs_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY designs
    ADD CONSTRAINT designs_species_id_fkey FOREIGN KEY (species_id) REFERENCES species(id);


--
-- Name: exons_gene_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY exons
    ADD CONSTRAINT exons_gene_id_fkey FOREIGN KEY (gene_id) REFERENCES genes(id) ON DELETE CASCADE;


--
-- Name: gene_design_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY gene_design
    ADD CONSTRAINT gene_design_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);


--
-- Name: gene_design_design_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY gene_design
    ADD CONSTRAINT gene_design_design_id_fkey FOREIGN KEY (design_id) REFERENCES designs(id);


--
-- Name: genes_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY genes
    ADD CONSTRAINT genes_species_id_fkey FOREIGN KEY (species_id) REFERENCES species(id);


--
-- Name: genotyping_primers_design_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY genotyping_primers
    ADD CONSTRAINT genotyping_primers_design_id_fkey FOREIGN KEY (design_id) REFERENCES designs(id);


--
-- Name: genotyping_primers_genotyping_primer_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY genotyping_primers
    ADD CONSTRAINT genotyping_primers_genotyping_primer_type_id_fkey FOREIGN KEY (genotyping_primer_type_id) REFERENCES genotyping_primer_types(id);


--
-- Name: library_design_jobs_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY library_design_jobs
    ADD CONSTRAINT library_design_jobs_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES users(id);


--
-- Name: library_design_jobs_library_design_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY library_design_jobs
    ADD CONSTRAINT library_design_jobs_library_design_stage_id_fkey FOREIGN KEY (library_design_stage_id) REFERENCES library_design_stages(id);


--
-- Name: species_default_assembly_assembly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY species_default_assembly
    ADD CONSTRAINT species_default_assembly_assembly_id_fkey FOREIGN KEY (assembly_id) REFERENCES assemblies(id);


--
-- Name: species_default_assembly_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY species_default_assembly
    ADD CONSTRAINT species_default_assembly_species_id_fkey FOREIGN KEY (species_id) REFERENCES species(id);


--
-- Name: user_crispr_pairs_grch38_crispr_pair_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crispr_pairs_grch38
    ADD CONSTRAINT user_crispr_pairs_grch38_crispr_pair_id_fkey FOREIGN KEY (crispr_pair_id) REFERENCES crispr_pairs_grch38(id);


--
-- Name: user_crispr_pairs_grch38_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crispr_pairs_grch38
    ADD CONSTRAINT user_crispr_pairs_grch38_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_crispr_pairs_human_crispr_pair_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crispr_pairs_human
    ADD CONSTRAINT user_crispr_pairs_human_crispr_pair_id_fkey FOREIGN KEY (crispr_pair_id) REFERENCES crispr_pairs_human(id);


--
-- Name: user_crispr_pairs_human_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crispr_pairs_human
    ADD CONSTRAINT user_crispr_pairs_human_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_crispr_pairs_mouse_crispr_pair_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crispr_pairs_mouse
    ADD CONSTRAINT user_crispr_pairs_mouse_crispr_pair_id_fkey FOREIGN KEY (crispr_pair_id) REFERENCES crispr_pairs_mouse(id);


--
-- Name: user_crispr_pairs_mouse_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crispr_pairs_mouse
    ADD CONSTRAINT user_crispr_pairs_mouse_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_crisprs_grch38_crispr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crisprs_grch38
    ADD CONSTRAINT user_crisprs_grch38_crispr_id_fkey FOREIGN KEY (crispr_id) REFERENCES crisprs_grch38(id);


--
-- Name: user_crisprs_grch38_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crisprs_grch38
    ADD CONSTRAINT user_crisprs_grch38_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_crisprs_human_crispr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crisprs_human
    ADD CONSTRAINT user_crisprs_human_crispr_id_fkey FOREIGN KEY (crispr_id) REFERENCES crisprs_human(id);


--
-- Name: user_crisprs_human_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crisprs_human
    ADD CONSTRAINT user_crisprs_human_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_crisprs_mouse_crispr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crisprs_mouse
    ADD CONSTRAINT user_crisprs_mouse_crispr_id_fkey FOREIGN KEY (crispr_id) REFERENCES crisprs_mouse(id);


--
-- Name: user_crisprs_mouse_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wge_admin
--

ALTER TABLE ONLY user_crisprs_mouse
    ADD CONSTRAINT user_crisprs_mouse_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--


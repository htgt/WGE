--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- Data for Name: species; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY species (numerical_id, id) FROM stdin;
1	Human
2	Mouse
\.


--
-- Data for Name: assemblies; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY assemblies (id, species_id) FROM stdin;
GRCh37	Human
GRCm38	Mouse
\.


--
-- Data for Name: chromosomes; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY chromosomes (id, species_id, name) FROM stdin;
1	Mouse	1
2	Mouse	2
3	Mouse	3
4	Mouse	4
5	Mouse	5
6	Mouse	6
7	Mouse	7
8	Mouse	8
9	Mouse	9
10	Mouse	10
11	Mouse	11
12	Mouse	12
13	Mouse	13
14	Mouse	14
15	Mouse	15
16	Mouse	16
17	Mouse	17
18	Mouse	18
19	Mouse	19
20	Mouse	X
21	Mouse	Y
22	Human	1
23	Human	2
24	Human	3
25	Human	4
26	Human	5
27	Human	6
28	Human	7
29	Human	8
30	Human	9
31	Human	10
32	Human	11
33	Human	12
34	Human	13
35	Human	14
36	Human	15
37	Human	16
38	Human	17
39	Human	18
40	Human	19
41	Human	20
42	Human	21
43	Human	22
44	Human	X
45	Human	Y
\.


--
-- Data for Name: crispr_pair_statuses; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY crispr_pair_statuses (id, status) FROM stdin;
-1	Error
0	Not started
1	Pending
2	Finding individual off targets
3	Persisting individual off targets
4	Calculating paired off targets
5	Complete
-2	Too many individual off targets
\.


--
-- Data for Name: design_comment_categories; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY design_comment_categories (id, name) FROM stdin;
\.


--
-- Name: design_comment_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wge_admin
--

SELECT pg_catalog.setval('design_comment_categories_id_seq', 1, false);


--
-- Data for Name: design_oligo_types; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY design_oligo_types (id) FROM stdin;
G5
U5
U3
D5
D3
G3
5F
5R
EF
ER
3F
3R
\.


--
-- Data for Name: genotyping_primer_types; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY genotyping_primer_types (id) FROM stdin;
\.


--
-- Data for Name: species_default_assembly; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY species_default_assembly (species_id, assembly_id) FROM stdin;
Human	GRCh37
Mouse	GRCm38
\.


--
-- Name: species_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wge_admin
--

SELECT pg_catalog.setval('species_id_seq', 2, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: wge_admin
--

COPY users (id, name, password) FROM stdin;
1	guest	guest
2	unknown	unknown
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wge_admin
--

SELECT pg_catalog.setval('users_id_seq', 2, true);


--
-- PostgreSQL database dump complete
--


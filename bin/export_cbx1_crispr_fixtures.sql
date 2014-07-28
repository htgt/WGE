\copy (select * from crisprs_human where chr_name = '17' and chr_start between 46100000 and 46200000) to t/fixtures/human_crisprs.csv with delimiter ';' csv header
\copy (select * from genes where chr_name = '17' and species_id='Human' and chr_start between 46100000 and 46200000) to t/fixtures/human_genes.csv  with delimiter ';' csv header
\copy (select * from exons where gene_id in (select id from genes where chr_name = '17' and species_id='Human' and chr_start between 46100000 and 46200000)) to t/fixtures/human_exons.csv  with delimiter ';' csv header
\copy (select * from crispr_pairs where left_id in (select id from crisprs_human where chr_name='17' and chr_start between 46100000 and 46200000)) to t/fixtures/human_crispr_pairs.csv  with delimiter ';' csv header

\copy (select * from crisprs_mouse where chr_name = '11' and chr_start between 96750000 and 96850000) to t/fixtures/mouse_crisprs.csv with delimiter ';' csv header
\copy (select * from genes where chr_name = '11' and species_id='Mouse' and chr_start between 96750000 and 96850000) to t/fixtures/mouse_genes.csv  with delimiter ';' csv header
\copy (select * from exons where gene_id in (select id from genes where chr_name = '11' and species_id='Mouse' and chr_start between 96750000 and 96850000)) to t/fixtures/mouse_exons.csv  with delimiter ';' csv header
\copy (select * from crispr_pairs where left_id in (select id from crisprs_mouse where chr_name = '11' and chr_start between 96750000 and 96850000)) to t/fixtures/mouse_crispr_pairs.csv  with delimiter ';' csv header
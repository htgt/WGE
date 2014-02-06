-- loading data:
-- run get_all_crisprs on the desired genome, then:
\copy crisprs(chr_name, chr_start, seq, pam_right, species_id) from '/var/tmp/chr1-10_crisprs.csv' with delimiter ','
\copy crisprs(chr_name, chr_start, seq, pam_right, species_id) from '/var/tmp/chr11_onwards_crisprs.csv' with delimiter ','
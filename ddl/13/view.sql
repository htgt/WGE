CREATE VIEW crisprs_grch38_ex AS
SELECT c.id, c.chr_name, c.chr_start, seq, pam_right, species_id, exonic, genic,
    CASE 
        WHEN c.off_target_summary IS NOT NULL THEN c.off_target_summary
        ELSE o.summary
    END AS off_target_summary,
    CASE
        WHEN c.off_target_ids IS NOT NULL THEN c.off_target_ids
        ELSE o.off_targets
    END AS off_target_ids
FROM crisprs_grch38 c
INNER JOIN sequences_grch38_ngg s ON c.id=s.crispr_id
LEFT JOIN off_targets_grch38_ngg o ON o.seq_id=s.seq_id;

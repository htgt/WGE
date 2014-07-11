ALTER TABLE design_attempts ALTER COLUMN design_parameters TYPE json USING design_parameters::JSON;
ALTER TABLE design_attempts ALTER COLUMN fail TYPE json USING fail::JSON;
ALTER TABLE design_attempts ALTER COLUMN fail TYPE json USING fail::JSON;
ALTER TABLE design_attempts ALTER COLUMN candidate_regions TYPE json USING candidate_regions::JSON;
ALTER TABLE design_attempts ALTER COLUMN candidate_oligos TYPE json USING candidate_oligos::JSON;
ALTER TABLE designs ALTER COLUMN design_parameters TYPE json USING design_parameters::JSON;
ALTER TABLE design_attempts ALTER COLUMN design_ids TYPE integer[] using CASE WHEN design_ids IS NOT NULL THEN array[design_ids::int] ELSE NULL END;

CREATE TABLE library_design_stages(
    id TEXT NOT NULL PRIMARY KEY,
    description TEXT NOT NULL,
    rank INT NOT NULL
);

INSERT INTO library_design_stages (id,description,rank) values
('find_targets','Finding target regions',1),
('find_crisprs','Finding CRISPR sites',2),
('generate_csv','Generating file for download',3);

CREATE TABLE library_design_jobs(
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    params JSON NOT NULL,
    target_region_count INT NOT NULL,
    library_design_stage_id TEXT REFERENCES library_design_stages(id),
    progress_percent INT NOT NULL,
    complete BOOL NOT NULL DEFAULT FALSE,
    error TEXT,
    warning TEXT,
    results_file TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_id INT NOT NULL REFERENCES users(id),
    last_modified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION update_library_design_job_modified()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_modified = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_library_design_job BEFORE UPDATE ON library_design_jobs
FOR EACH ROW EXECUTE PROCEDURE update_library_design_job_modified();

CREATE TABLE crispr_ots_pending (
    crispr_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(crispr_id)
);

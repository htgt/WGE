CREATE TABLE user_crisprs_human (
       crispr_id  INTEGER NOT NULL REFERENCES crisprs_human(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY(crispr_id, user_id)
);

CREATE TABLE user_crispr_pairs_human (
       crispr_pair_id  TEXT NOT NULL REFERENCES crispr_pairs_human(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY(crispr_pair_id, user_id)
);

CREATE TABLE user_crisprs_mouse (
       crispr_id  INTEGER NOT NULL REFERENCES crisprs_mouse(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY(crispr_id, user_id)
);

CREATE TABLE user_crispr_pairs_mouse (
       crispr_pair_id  TEXT NOT NULL REFERENCES crispr_pairs_mouse(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY(crispr_pair_id, user_id)
);
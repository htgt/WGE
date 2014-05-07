CREATE TABLE user_shared_designs (
       design_id  INTEGER NOT NULL REFERENCES designs(id),
       user_id    INTEGER NOT NULL REFERENCES users(id),
       PRIMARY KEY(design_id, user_id)
);

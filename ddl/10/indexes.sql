CREATE INDEX geneset_refseq_index ON geneset_refseq USING btree (chr_name, chr_start, chr_end);

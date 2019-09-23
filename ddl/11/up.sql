alter table haplotype rename column restricted to restricted_old;
alter table haplotype add column restricted text[];
update haplotype set restricted='{"*"}' where restricted_old;
update haplotype set restricted='{"chrY"}' where id=1;
alter table haplotype drop column restricted_old;

-- Owner-approved additional consumables. Apple registration is still required.
-- Apply after the existing backend sources; do not replay schema.sql.
-- No existing product, balance or transaction is changed.
begin;
insert into bibi_private.products (id, diamonds) values
 ('fyongbrslseicxya', 16800),
 ('xutwylpejsdvkwpm', 42700)
on conflict (id) do nothing;

do $$
begin
 if (select count(*) from bibi_private.products
     where (id, diamonds) in (('fyongbrslseicxya', 16800),
                             ('xutwylpejsdvkwpm', 42700))) <> 2 then
  raise exception 'Additional wallet product mapping conflicts with existing catalog';
 end if;
end;
$$;
commit;

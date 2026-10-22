-- Don't Panic Island: the owner's stats page (pages/stats.html) reads the private counters through admin_stats(key).
-- Only the sha256 of each key is stored here; the keys themselves never go into the repo. Add one (as the owner):
--   insert into public.admin_keys (hash, note) values (sha256(convert_to('<key>', 'UTF8')), 'phone');
-- Revoke one: delete from public.admin_keys where note = 'phone';

create table public.admin_keys (
  hash bytea primary key,
  note text not null default '',
  created_at timestamptz not null default now()
);
alter table public.admin_keys enable row level security;   -- no policies: not readable through the API
revoke all on public.admin_keys from anon, authenticated;

-- Everything the stats page shows, for the last p_days days (counters per day and island, the winning runs) plus the
-- all-time totals and top 10. Raises 'denied' unless p_key matches a stored key.
create function public.admin_stats(p_key text, p_days int default 90) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  since date := (now() at time zone 'utc')::date - least(greatest(coalesce(p_days, 90), 1), 366) + 1;
begin
  if p_key is null or length(p_key) < 20
     or not exists (select 1 from public.admin_keys where hash = sha256(convert_to(p_key, 'UTF8'))) then
    raise exception 'denied';
  end if;
  return jsonb_build_object(
    'now', now(),
    'since', since,
    'counts', coalesce((select jsonb_agg(jsonb_build_array(d.day, d.island, d.event, d.n) order by d.day, d.island)
                        from public.daily_counts d where d.day >= since), '[]'::jsonb),
    'totals', (select jsonb_build_object(
                 'loaded', coalesce(sum(n) filter (where event = 'loaded'), 0),
                 'played', coalesce(sum(n) filter (where event = 'played'), 0),
                 'won', coalesce(sum(n) filter (where event = 'won'), 0),
                 'lost', coalesce(sum(n) filter (where event = 'lost'), 0),
                 'first_day', min(day))
               from public.daily_counts),
    'runs', coalesce((select jsonb_agg(jsonb_build_object('nick', r.nick, 'score', r.score, 'crew', r.crew,
                        'turns', r.turns, 'island', r.island, 'created_at', r.created_at) order by r.created_at desc)
                      from public.runs r where r.created_at >= since), '[]'::jsonb),
    'runs_total', (select count(*) from public.runs),
    'top', coalesce((select jsonb_agg(t order by t.score desc, t.turns, t.created_at)
                     from (select r.nick, r.score, r.turns, r.island, r.created_at from public.runs r
                           order by r.score desc, r.turns, r.created_at, r.id limit 10) t), '[]'::jsonb)
  );
end
$$;

revoke execute on function public.admin_stats(text, int) from public;
grant execute on function public.admin_stats(text, int) to anon, authenticated;

-- Don't Panic Island: shared leaderboard (winning runs) and private play counters.
-- The game only holds the public (anon/publishable) key: every write goes through a security definer function
-- that validates it; the tables themselves accept no writes from the public roles.

-- ---------------------------------------------------------------------------
-- Nicknames: 1-5 chars A-Z 0-9, checked against a normalized blocklist
-- ---------------------------------------------------------------------------

create table public.blocked_words (
  word text primary key,
  exact boolean not null default false   -- true: blocks only this exact nick; false: any nick containing it
);
alter table public.blocked_words enable row level security;   -- no policies: not readable through the API
revoke all on public.blocked_words from anon, authenticated;

-- leetspeak digits to the letters they imitate (same table as scripts/nick_filter.gd)
create function public.normalize_nick(p text) returns text
language sql immutable
set search_path = ''
as $$ select translate(upper(coalesce(p, '')), '0134578', 'OIEASTB') $$;

create function public.nick_ok(p text) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(p, '') ~ '^[A-Z0-9]{1,5}$'
     and not exists (
       select 1 from public.blocked_words b
       where (b.exact and public.normalize_nick(p) = b.word)
          or (not b.exact and position(b.word in public.normalize_nick(p)) > 0))
$$;

-- ---------------------------------------------------------------------------
-- Runs: winning games only; the score is computed here, never sent by the client
-- ---------------------------------------------------------------------------

create table public.runs (
  id bigint generated always as identity primary key,
  nick text not null check (nick ~ '^[A-Z0-9]{1,5}$'),
  score int not null,
  gold int not null check (gold between 120 and 510),      -- 12 chests x 10-30 + up to 3 wrecks x 50 (a wreck can hide a mine)
  crew int not null check (crew between 1 and 3),           -- a win keeps at least one crewmate
  turns int not null check (turns >= 10),
  island int not null check (island between 0 and 24),
  seed bigint not null,
  created_at timestamptz not null default now()
);
create index runs_rank_idx on public.runs (score desc, turns, created_at, id);
create index runs_created_idx on public.runs (created_at);
create index runs_nick_idx on public.runs (nick, created_at);

alter table public.runs enable row level security;
create policy "runs are public" on public.runs for select to anon, authenticated using (true);
revoke insert, update, delete, truncate on public.runs from anon, authenticated;

-- start of the current week (Monday 00:00 UTC)
create function public.week_start() returns timestamptz
language sql stable
set search_path = ''
as $$ select date_trunc('week', now() at time zone 'utc') at time zone 'utc' $$;

-- Submit a won game. Errors (message): bad_nick, implausible, too_fast.
-- Returns {id, score, rank_all, rank_week}; ties: higher score, fewer turns, earlier run.
create function public.submit_run(p_nick text, p_gold int, p_crew int, p_turns int, p_island int, p_seed bigint)
returns json
language plpgsql security definer
set search_path = ''
as $$
declare
  v_nick text := upper(coalesce(p_nick, ''));
  v_score int;
  v_id bigint;
  v_created timestamptz;
  v_all int;
  v_week int;
begin
  if not public.nick_ok(v_nick) then
    raise exception 'bad_nick';
  end if;
  if p_gold is null or p_crew is null or p_turns is null or p_island is null or p_seed is null
     or p_crew not between 1 and 3 or p_gold not between 120 and 510 or p_turns < 10
     or p_island not between 0 and 24 then
    raise exception 'implausible';
  end if;
  if exists (select 1 from public.runs where nick = v_nick and created_at > now() - interval '30 seconds') then
    raise exception 'too_fast';
  end if;

  v_score := p_gold + p_crew * 100 + greatest(0, 400 - 2 * p_turns);   -- Board.score() in scripts/board.gd
  insert into public.runs (nick, score, gold, crew, turns, island, seed)
  values (v_nick, v_score, p_gold, p_crew, p_turns, p_island, p_seed)
  returning id, created_at into v_id, v_created;

  select count(*) + 1 into v_all from public.runs r
  where r.score > v_score
     or (r.score = v_score and r.turns < p_turns)
     or (r.score = v_score and r.turns = p_turns and (r.created_at, r.id) < (v_created, v_id));
  select count(*) + 1 into v_week from public.runs r
  where r.created_at >= public.week_start()
    and (r.score > v_score
     or (r.score = v_score and r.turns < p_turns)
     or (r.score = v_score and r.turns = p_turns and (r.created_at, r.id) < (v_created, v_id)));

  return json_build_object('id', v_id, 'score', v_score, 'rank_all', v_all, 'rank_week', v_week);
end
$$;

-- Top 10: p_period 'all' or 'week'
create function public.top_runs(p_period text default 'all')
returns table (id bigint, nick text, score int, turns int, island int, created_at timestamptz)
language sql stable
set search_path = ''
as $$
  select r.id, r.nick, r.score, r.turns, r.island, r.created_at
  from public.runs r
  where p_period = 'all' or r.created_at >= public.week_start()
  order by r.score desc, r.turns, r.created_at, r.id
  limit 10
$$;

-- ---------------------------------------------------------------------------
-- Play counters: per UTC day, island and event; private (dashboard / SQL only)
-- ---------------------------------------------------------------------------

create table public.daily_counts (
  day date not null,
  island int not null check (island between 0 and 24),
  event text not null check (event in ('loaded', 'played', 'won', 'lost')),
  n bigint not null default 0,
  primary key (day, island, event)
);
alter table public.daily_counts enable row level security;   -- no policies: not readable through the API
revoke all on public.daily_counts from anon, authenticated;

create function public.count_event(p_event text, p_island int) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if p_event is null or p_event not in ('loaded', 'played', 'won', 'lost')
     or p_island is null or p_island not between 0 and 24 then
    raise exception 'bad_event';
  end if;
  insert into public.daily_counts (day, island, event, n)
  values ((now() at time zone 'utc')::date, p_island, p_event, 1)
  on conflict (day, island, event) do update set n = public.daily_counts.n + 1;
end
$$;

-- per-day totals for the dashboard; abandoned = played - won - lost
create view public.stats with (security_invoker = true) as
select day,
       sum(n) filter (where event = 'loaded') as loaded,
       sum(n) filter (where event = 'played') as played,
       sum(n) filter (where event = 'won') as won,
       sum(n) filter (where event = 'lost') as lost,
       coalesce(sum(n) filter (where event = 'played'), 0) - coalesce(sum(n) filter (where event = 'won'), 0)
         - coalesce(sum(n) filter (where event = 'lost'), 0) as abandoned
from public.daily_counts
group by day
order by day desc;
revoke all on public.stats from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Function access: the three RPCs the game calls; helpers stay internal
-- ---------------------------------------------------------------------------

revoke execute on function public.nick_ok(text) from public, anon, authenticated;
revoke execute on function public.normalize_nick(text) from public, anon, authenticated;
revoke execute on function public.submit_run(text, int, int, int, int, bigint) from public;
revoke execute on function public.top_runs(text) from public;
revoke execute on function public.count_event(text, int) from public;
grant execute on function public.submit_run(text, int, int, int, int, bigint) to anon, authenticated;
grant execute on function public.top_runs(text) to anon, authenticated;
grant execute on function public.count_event(text, int) to anon, authenticated;

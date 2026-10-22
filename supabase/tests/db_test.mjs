// Local test of supabase/migrations/*.sql on PGlite (Postgres in WASM), with Supabase's anon/authenticated roles
// stubbed. Checks validation, ranks, periods, counters and what the public role can and cannot do.
// Run: npm install --prefix <dir> @electric-sql/pglite
//      PGLITE=<dir>/node_modules/@electric-sql/pglite/dist/index.js node supabase/tests/db_test.mjs
import { readFileSync, readdirSync } from "node:fs";
import { pathToFileURL } from "node:url";

const { PGlite } = await import(pathToFileURL(process.env.PGLITE).href);
const db = new PGlite();
let fails = 0;
const check = (ok, what) => { console.log((ok ? "ok   " : "FAIL ") + what); if (!ok) fails++; };

// Supabase environment stubs
await db.exec(`create role anon nologin; create role authenticated nologin;
  grant usage on schema public to anon, authenticated;
  alter default privileges in schema public grant all on tables to anon, authenticated;
  alter default privileges in schema public grant all on functions to anon, authenticated;`);
const dir = new URL("../migrations/", import.meta.url);
for (const f of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
  await db.exec(readFileSync(new URL(f, dir), "utf8"));
  console.log("applied " + f);
}

// helpers: run as the public role, catch the error message
const asAnon = async (sql, params = []) => {
  await db.exec("set role anon");
  try { return { rows: (await db.query(sql, params)).rows }; }
  catch (e) { return { error: e.message }; }
  finally { await db.exec("reset role"); }
};
const submit = (nick, gold, crew, turns, island = 0, seed = 1) =>
  asAnon("select public.submit_run($1, $2, $3, $4, $5, $6) as r", [nick, gold, crew, turns, island, seed]);
const age = (nick, secs) => db.query(
  "update public.runs set created_at = created_at - make_interval(secs => $2) where nick = $1", [nick, secs]);

// nick_ok (as owner)
const ok = async (n) => (await db.query("select public.nick_ok($1) as v", [n])).rows[0].v;
for (const n of ["HENRI", "ANNA", "A", "12345", "SPIKE", "GRAPE", "SPICE", "CUMIN", "SHORE", "TITAN", "PARSE"])
  check(await ok(n) === true, `nick_ok ${n}`);
for (const n of ["FUCK", "FVCK", "F4CK", "PHUK", "5H1T", "ASS", "455", "P1K", "PIK", "FISSE", "N4Z1", "abc", "",
                 "ABCDEF", "A B", "CUM", "RAPE", "55", "KYS"])
  check(await ok(n) === false, `nick_ok rejects '${n}'`);
check(await ok(null) === false, "nick_ok rejects null");

// submit: valid
let r = await submit("HENRI", 400, 3, 50);
check(!r.error && r.rows[0].r.score === 400 + 300 + 300, `valid submit scores 1000 (${JSON.stringify(r)})`);
check(r.rows?.[0].r.rank_all === 1 && r.rows[0].r.rank_week === 1, "first run ranks 1/1");
// server computes the score; turn bonus floors at 0
await age("HENRI", 31);
r = await submit("HENRI", 270, 1, 300);
check(r.rows?.[0].r.score === 370, `turn bonus floors at 0 (${JSON.stringify(r)})`);
check(r.rows?.[0].r.rank_all === 2, "worse run ranks 2");

// rejections
const err = async (args, want, what) => { const x = await submit(...args); check(x.error === want, `${what}: ${x.error}`); };
await err(["FUCK", 400, 3, 50], "bad_nick", "offensive nick");
await err(["ABCDEF", 400, 3, 50], "bad_nick", "6-char nick");
await err(["A B", 400, 3, 50], "bad_nick", "space in nick");
await err(["", 400, 3, 50], "bad_nick", "empty nick");
await err(["BOB", 600, 3, 50], "implausible", "gold 600");
await err(["BOB", 119, 3, 50], "implausible", "gold 119");
r = await submit("LOW", 120, 1, 77);
check(!r.error, `gold 120 (a real low win) accepted (${r.error})`);
await err(["BOB", 400, 0, 50], "implausible", "crew 0 (a loss)");
await err(["BOB", 400, 4, 50], "implausible", "crew 4");
await err(["BOB", 400, 3, 9], "implausible", "turns 9");
await err(["BOB", 400, 3, 50, 25], "implausible", "island 25");
await err(["BOB", 400, 3, 50, -1], "implausible", "island -1");
await err(["BOB", 400, 3, 50, 0, null], "implausible", "null seed");
await err(["BOB", null, 3, 50], "implausible", "null gold");

// rate limit: same nick within 30 s
await db.exec("delete from public.runs where nick = 'HENRI'");
r = await submit("TOM", 300, 2, 40);
check(!r.error, "TOM first run");
await err(["TOM", 300, 2, 40], "too_fast", "second run within 30 s");
await err(["tom", 300, 2, 40], "too_fast", "lower-case nick is the same nick");
await age("TOM", 31);
r = await submit("TOM", 300, 2, 40);
check(!r.error, "TOM again after 30 s");

// ties: higher score > fewer turns > earlier
await db.exec("delete from public.runs");
await submit("AAA", 400, 3, 50);   // 1000
await submit("BBB", 402, 3, 51);   // 1000, more turns
await submit("CCC", 400, 3, 50);   // 1000, same turns, later
await db.exec("update public.runs set created_at = now() - interval '1 minute' where nick = 'AAA'");
r = await submit("DDD", 510, 3, 10);   // 1290: top
check(r.rows?.[0].r.rank_all === 1, "best run ranks 1");
let top = (await asAnon("select * from public.top_runs('all')")).rows.map((x) => x.nick).join(",");
check(top === "DDD,AAA,CCC,BBB", `tie order (${top})`);
r = await submit("EEE", 400, 3, 50);   // 1000, same turns, latest
check(r.rows?.[0].r.rank_all === 4, `latest tie ranks after earlier ties (${r.rows?.[0].r.rank_all})`);

// weeks: an old run counts all-time, not this week
await db.exec("update public.runs set created_at = now() - interval '8 days' where nick = 'DDD'");
top = (await asAnon("select * from public.top_runs('week')")).rows.map((x) => x.nick);
check(!top.includes("DDD") && top.length === 4, `week excludes the old run (${top})`);
top = (await asAnon("select * from public.top_runs('all')")).rows.map((x) => x.nick);
check(top[0] === "DDD", "all-time keeps the old run");
r = await submit("FFF", 300, 1, 100);
check(r.rows?.[0].r.rank_week === r.rows?.[0].r.rank_all - 1, `week rank skips the old run (${JSON.stringify(r.rows?.[0].r)})`);

// top 10 limit; all runs shown (one nick can hold several places)
await db.exec("delete from public.runs");
for (let i = 0; i < 14; i++) {
  await submit("REP", 300 + i * 10, 3, 40);
  await age("REP", 31);
}
top = (await asAnon("select * from public.top_runs('all')")).rows;
check(top.length === 10 && top.every((x) => x.nick === "REP"), "top 10, same nick may repeat");
check(top[0].score > top[9].score, "sorted by score");
r = await asAnon("select * from public.top_runs('bogus')");
check(r.rows && r.rows.length === 10, "an unknown period falls back to this week");

// counters
for (const e of ["loaded", "played", "played", "won", "lost"]) {
  const x = await asAnon("select public.count_event($1, $2)", [e, 3]);
  check(!x.error, `count_event ${e}`);
}
for (const [e, i] of [["bogus", 3], ["won", 25], ["won", -1], [null, 3], ["won", null]]) {
  const x = await asAnon("select public.count_event($1, $2)", [e, i]);
  check(x.error === "bad_event", `count_event rejects (${e}, ${i}): ${x.error}`);
}
const stats = (await db.query("select * from public.stats")).rows[0];
check(Number(stats.loaded) === 1 && Number(stats.played) === 2 && Number(stats.won) === 1 &&
      Number(stats.lost) === 1 && Number(stats.abandoned) === 0, `stats view (${JSON.stringify(stats)})`);

// what the public role may not do
for (const [sql, what] of [
  ["insert into public.runs (nick, score, gold, crew, turns, island, seed) values ('X', 9999, 400, 3, 50, 0, 1)", "insert runs"],
  ["update public.runs set score = 99999", "update runs"],
  ["delete from public.runs", "delete runs"],
  ["select * from public.daily_counts", "read daily_counts"],
  ["insert into public.daily_counts values (current_date, 0, 'won', 999)", "write daily_counts"],
  ["select * from public.stats", "read stats"],
  ["select * from public.blocked_words", "read blocked_words"],
  ["delete from public.blocked_words", "delete blocked_words"],
  ["select public.nick_ok('A')", "call nick_ok"],
]) {
  const x = await asAnon(sql);
  const blocked = !!x.error;
  check(blocked, `anon cannot ${what} (${x.error ?? "rows=" + x.rows?.length})`);
}
check(Number((await db.query("select count(*) c from public.blocked_words")).rows[0].c) > 80, "blocklist intact");
const scores = (await db.query("select max(score) m from public.runs")).rows[0].m;
check(scores < 99999, "no score was tampered with");
check((await asAnon("select count(*) c from public.runs")).rows?.[0].c > 0, "anon can read runs");

console.log(fails === 0 ? "DB TESTS PASSED" : `${fails} DB TESTS FAILED`);
process.exit(fails ? 1 : 0);

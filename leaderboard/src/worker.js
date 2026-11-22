// Nudge global top 100.
//   GET  /                 the scoreboard page
//   GET  /api/top?table=   top 100 as JSON (table = all, or a table id)
//   POST /api/submit       {name, score, table, version} from the game
//   GET  /admin?key=       list recent entries; /admin/delete?key=&id= removes one
// The game is open source, so a submitted score cannot be proved genuine. The
// checks here keep out junk and rude names; the admin link removes the rest.

const TABLES = { deep_space: "Cosmic Drift", paradise_bay: "Paradise Bay", alpenglow: "Alpenglow", palace_night: "Palace Night" };
const BLOCKED = ["fuck", "shit", "cunt", "nigg", "fag", "bitch", "dick", "cock", "pussy", "rape", "nazi", "hitler", "porn", "sex", "whore", "slut", "arse", "wank"];
const PER_HOUR = 6;

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" } });

function cleanName(raw) {
  const name = String(raw || "").toUpperCase().replace(/[^A-Z0-9 ._\-]/g, "").replace(/\s+/g, " ").trim().slice(0, 12);
  if (!name) return null;
  const squashed = name.toLowerCase().replace(/[^a-z]/g, "").replace(/0/g, "o").replace(/1/g, "i").replace(/3/g, "e").replace(/4/g, "a").replace(/5/g, "s");
  const plain = name.toLowerCase().replace(/0/g, "o").replace(/1/g, "i").replace(/3/g, "e").replace(/4/g, "a").replace(/5/g, "s").replace(/[^a-z]/g, "");
  if (BLOCKED.some((w) => squashed.includes(w) || plain.includes(w))) return null;
  return name;
}

async function hashIp(ip, salt) {
  const data = new TextEncoder().encode(`${salt}|${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].slice(0, 12).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function top(env, table) {
  // each player's best score per table, highest first
  const where = table === "all" ? "" : "WHERE table_id = ?1";
  const sql = `SELECT name, table_id, MAX(score) AS score, MIN(created_at) AS created_at
               FROM scores ${where} GROUP BY name, table_id ORDER BY score DESC, created_at ASC LIMIT 100`;
  const stmt = table === "all" ? env.DB.prepare(sql) : env.DB.prepare(sql).bind(table);
  const { results } = await stmt.all();
  return results.map((r, i) => ({ rank: i + 1, name: r.name, score: r.score, table: TABLES[r.table_id] || r.table_id, at: r.created_at }));
}

async function submit(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, error: "bad request" }, 400);
  }
  const min = parseInt(env.MIN_SCORE || "100000", 10);
  const max = parseInt(env.MAX_SCORE || "50000000", 10);
  const score = Number(body.score);
  const table = String(body.table || "");
  const name = cleanName(body.name);
  if (!name) return json({ ok: false, error: "name not allowed" }, 400);
  if (!(table in TABLES)) return json({ ok: false, error: "unknown table" }, 400);
  if (!Number.isInteger(score) || score < min || score > max || score % 5 !== 0) return json({ ok: false, error: "score not accepted" }, 400);
  const ip = request.headers.get("cf-connecting-ip") || "local";
  const ipHash = await hashIp(ip, env.IP_SALT || "nudge");
  const now = Math.floor(Date.now() / 1000);
  const recent = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE ip_hash = ?1 AND created_at > ?2").bind(ipHash, now - 3600).first();
  if (recent && recent.n >= PER_HOUR) return json({ ok: false, error: "too many scores, try later" }, 429);
  await env.DB.prepare("INSERT INTO scores (name, score, table_id, version, ip_hash, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)")
    .bind(name, score, table, String(body.version || "").slice(0, 16), ipHash, now).run();
  const better = await env.DB.prepare("SELECT COUNT(*) AS n FROM (SELECT MAX(score) AS s FROM scores GROUP BY name, table_id) WHERE s > ?1").bind(score).first();
  return json({ ok: true, rank: (better ? better.n : 0) + 1 });
}

async function admin(url, env) {
  if (!env.ADMIN_KEY || url.searchParams.get("key") !== env.ADMIN_KEY) return new Response("Not found", { status: 404 });
  if (url.pathname === "/admin/delete") {
    const id = parseInt(url.searchParams.get("id") || "0", 10);
    await env.DB.prepare("DELETE FROM scores WHERE id = ?1").bind(id).run();
    return Response.redirect(`${url.origin}/admin?key=${encodeURIComponent(env.ADMIN_KEY)}`, 302);
  }
  const { results } = await env.DB.prepare("SELECT id, name, score, table_id, version, created_at FROM scores ORDER BY created_at DESC LIMIT 300").all();
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const rows = results.map((r) => `<tr><td>${r.id}</td><td>${esc(r.name)}</td><td>${r.score.toLocaleString("en-GB")}</td><td>${esc(r.table_id)}</td><td>${esc(r.version)}</td><td>${new Date(r.created_at * 1000).toISOString().slice(0, 16).replace("T", " ")}</td><td><a href="/admin/delete?key=${encodeURIComponent(env.ADMIN_KEY)}&id=${r.id}">delete</a></td></tr>`).join("");
  return new Response(`<!doctype html><meta charset="utf-8"><title>Nudge scores admin</title><style>body{font:14px system-ui;margin:24px}td,th{padding:4px 10px;text-align:left;border-bottom:1px solid #ddd}</style><h1>Nudge scores (latest 300)</h1><table><tr><th>id</th><th>name</th><th>score</th><th>table</th><th>version</th><th>when (UTC)</th><th></th></tr>${rows}</table>`,
    { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/api/top" && request.method === "GET") {
        const table = url.searchParams.get("table") || "all";
        if (table !== "all" && !(table in TABLES)) return json({ ok: false, error: "unknown table" }, 400);
        return json({ ok: true, min: parseInt(env.MIN_SCORE || "100000", 10), tables: TABLES, scores: await top(env, table) });
      }
      if (url.pathname === "/api/submit" && request.method === "POST") return await submit(request, env);
      if (url.pathname.startsWith("/admin")) return await admin(url, env);
      if (url.pathname === "/" || url.pathname === "/index.html") {
        return new Response(PAGE, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=300" } });
      }
      return new Response("Not found", { status: 404 });
    } catch (err) {
      return json({ ok: false, error: "server error" }, 500);
    }
  },
};

const PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Nudge - Global Top 100</title>
<meta name="description" content="The global top 100 players of Nudge, the arcade pinball game by QuietByte.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Audiowide&family=Bungee&display=swap" rel="stylesheet">
<style>
  :root { --ink: #eaf6ff; --dim: #8fa3c8; --pink: #ff2e88; --cyan: #29e6ff; --gold: #ffd23f; --violet: #8a5cff; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; color: var(--ink); font-family: "Audiowide", system-ui, sans-serif;
    background: radial-gradient(1200px 600px at 50% -10%, #2a1257 0%, transparent 60%),
      radial-gradient(900px 500px at 100% 100%, #062a4a 0%, transparent 55%), #070713; }
  .wrap { max-width: 880px; margin: 0 auto; padding: 36px 18px 60px; }
  header { text-align: center; }
  h1 { font-family: "Bungee", sans-serif; font-size: clamp(56px, 13vw, 120px); line-height: 0.95; margin: 0; letter-spacing: 2px;
    background: linear-gradient(180deg, #fff36b 0%, #ff9d2e 45%, #ff2e88 100%); -webkit-background-clip: text; background-clip: text; color: transparent;
    filter: drop-shadow(0 4px 0 #4b0f6b) drop-shadow(0 0 22px rgba(255, 46, 136, 0.45)); }
  .sub { font-family: "Bungee", sans-serif; font-size: clamp(16px, 3.6vw, 26px); color: var(--cyan); letter-spacing: 3px; margin-top: 6px;
    text-shadow: 0 0 14px rgba(41, 230, 255, 0.6); }
  .rule { height: 3px; border-radius: 3px; margin: 18px auto 22px; width: min(520px, 80%);
    background: linear-gradient(90deg, transparent, var(--pink), var(--gold), var(--cyan), transparent); }
  .tabs { display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; margin-bottom: 20px; }
  .tabs button { font: inherit; font-size: 14px; color: var(--ink); background: rgba(255, 255, 255, 0.05); border: 2px solid rgba(138, 92, 255, 0.55);
    padding: 9px 16px; border-radius: 999px; cursor: pointer; letter-spacing: 1px; }
  .tabs button[aria-pressed="true"] { background: linear-gradient(90deg, var(--pink), var(--violet)); border-color: transparent; box-shadow: 0 0 18px rgba(255, 46, 136, 0.5); }
  .tabs button:focus-visible { outline: 3px solid var(--gold); outline-offset: 2px; }
  ol { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
  li { display: grid; grid-template-columns: 64px 1fr auto; align-items: center; gap: 12px; padding: 10px 16px; border-radius: 14px;
    background: linear-gradient(90deg, rgba(138, 92, 255, 0.16), rgba(41, 230, 255, 0.06)); border: 1px solid rgba(138, 92, 255, 0.3); }
  .rank { font-family: "Bungee", sans-serif; font-size: 22px; color: var(--dim); }
  .who { min-width: 0; }
  .name { font-size: 20px; letter-spacing: 1px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .table { font-size: 12px; color: var(--dim); letter-spacing: 1px; margin-top: 2px; }
  .score { font-family: "Bungee", sans-serif; font-size: 24px; color: var(--cyan); font-variant-numeric: tabular-nums; text-shadow: 0 0 12px rgba(41, 230, 255, 0.45); }
  li.top1 { border-color: var(--gold); background: linear-gradient(90deg, rgba(255, 210, 63, 0.28), rgba(255, 46, 136, 0.14)); box-shadow: 0 0 26px rgba(255, 210, 63, 0.25); }
  li.top1 .rank, li.top1 .score { color: var(--gold); }
  li.top2 { border-color: #cfd8e6; } li.top2 .rank { color: #dfe7f3; }
  li.top3 { border-color: #e39a5a; } li.top3 .rank { color: #f0a868; }
  li.top1 .name { font-size: 26px; } li.top1 .score { font-size: 32px; }
  .empty, .note { text-align: center; color: var(--dim); font-size: 14px; line-height: 1.7; }
  .empty { padding: 40px 10px; font-size: 16px; }
  .note { margin-top: 30px; }
  a { color: var(--gold); }
  @media (max-width: 520px) { li { grid-template-columns: 44px 1fr auto; padding: 9px 12px; } .score { font-size: 18px; } .name { font-size: 16px; } li.top1 .score { font-size: 22px; } li.top1 .name { font-size: 19px; } }
  @media (prefers-reduced-motion: no-preference) { li.top1 { animation: glow 2.4s ease-in-out infinite; }
    @keyframes glow { 50% { box-shadow: 0 0 40px rgba(255, 210, 63, 0.45); } } }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>NUDGE</h1>
    <div class="sub">GLOBAL TOP 100</div>
    <div class="rule"></div>
  </header>
  <div class="tabs" id="tabs"></div>
  <main><ol id="list" aria-live="polite"></ol><div class="empty" id="empty" hidden></div></main>
  <p class="note" id="note"></p>
  <p class="note">Nudge is a free arcade pinball game by QuietByte for Linux and Windows.
    <a href="https://github.com/quietbytehq/nudge/releases">Download it</a> and put your name here.<br>
    Only the name a player types, their score and the table are shown.</p>
</div>
<script>
  const list = document.getElementById("list"), empty = document.getElementById("empty"), tabs = document.getElementById("tabs"), note = document.getElementById("note");
  let current = "all";
  function tab(id, label) {
    const b = document.createElement("button");
    b.textContent = label; b.dataset.id = id; b.setAttribute("aria-pressed", id === current ? "true" : "false");
    b.addEventListener("click", () => { current = id; load(); });
    return b;
  }
  async function load() {
    try {
      const res = await fetch("/api/top?table=" + encodeURIComponent(current));
      const data = await res.json();
      tabs.replaceChildren(tab("all", "ALL TABLES"), ...Object.entries(data.tables).map(([id, name]) => tab(id, name.toUpperCase())));
      list.replaceChildren(...data.scores.map((s) => {
        const li = document.createElement("li");
        if (s.rank <= 3) li.className = "top" + s.rank;
        const rank = document.createElement("div"); rank.className = "rank"; rank.textContent = "#" + s.rank;
        const who = document.createElement("div"); who.className = "who";
        const name = document.createElement("div"); name.className = "name"; name.textContent = s.name;
        const table = document.createElement("div"); table.className = "table"; table.textContent = s.table.toUpperCase();
        who.append(name, table);
        const score = document.createElement("div"); score.className = "score"; score.textContent = s.score.toLocaleString("en-GB");
        li.append(rank, who, score);
        return li;
      }));
      empty.hidden = data.scores.length > 0;
      empty.textContent = "No scores here yet. Be the first!";
      note.textContent = "Score " + data.min.toLocaleString("en-GB") + " or more in the game to get on the board.";
    } catch (e) {
      empty.hidden = false; empty.textContent = "The scoreboard could not be loaded. Please try again in a moment.";
    }
  }
  load();
  setInterval(load, 60000);
</script>
</body>
</html>`;

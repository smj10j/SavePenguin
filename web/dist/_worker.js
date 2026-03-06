/**
 * SavePenguin — Cloudflare Pages _worker.js (Advanced Mode)
 *
 * Routes:
 *   /server  → API (replaces api.savepenguin.com/server.php)
 *   *        → static assets (index.html, css, images, etc.)
 *
 * Bindings (configured in wrangler.toml):
 *   env.DB     → D1 database (savepenguin-db)
 *   env.ASSETS → static asset fetcher (auto-provided by Pages)
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/server') {
      return handleAPI(request, env);
    }

    // Fall through to static assets
    return env.ASSETS.fetch(request);
  }
};

// ---------------------------------------------------------------------------
// API routing
// ---------------------------------------------------------------------------

async function handleAPI(request, env) {
  const db = env.DB;
  try {
    if (request.method === 'POST') {
      return await handlePost(request, db);
    } else if (request.method === 'GET') {
      return await handleGet(new URL(request.url), db);
    } else {
      return jsonError('Method not allowed', 405);
    }
  } catch (err) {
    console.error(err);
    return jsonError('Internal server error: ' + err.message, 500);
  }
}

// ---------------------------------------------------------------------------
// POST handlers
// ---------------------------------------------------------------------------

async function handlePost(request, db) {
  let body;
  const contentType = request.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    body = await request.json();
  } else {
    const text = await request.text();
    body = Object.fromEntries(new URLSearchParams(text));
  }

  const action = body.action;

  if (action === 'saveUser') {
    const uuid = body.UUID;
    if (!uuid) return jsonError('Missing UUID');

    await upsertUser(db, uuid);
    const userId = await getUserId(db, uuid);
    return jsonOk({ userId, uuid });

  } else if (action === 'savePlay') {
    const { UUID: uuid, levelPackPath, levelPath } = body;
    if (!uuid || !levelPackPath || !levelPath) return jsonError('Missing fields');

    await upsertUser(db, uuid);
    await upsertLevelPack(db, levelPackPath);
    await upsertLevel(db, levelPath);

    const userId      = await getUserId(db, uuid);
    const levelPackId = await getLevelPackId(db, levelPackPath);
    const levelId     = await getLevelId(db, levelPath);

    await db.prepare(
      'INSERT INTO plays (user_id, level_pack_id, level_id) VALUES (?, ?, ?)'
    ).bind(userId, levelPackId, levelId).run();

    return jsonOk({ userId, uuid, levelPackPath, levelPath });

  } else if (action === 'saveScore') {
    const { UUID: uuid, levelPackPath, levelPath } = body;
    let score = parseInt(body.score, 10) || 0;
    if (score < 0) score = 0;

    if (!uuid || !levelPackPath || !levelPath) return jsonError('Missing fields');

    await upsertUser(db, uuid);
    await upsertLevelPack(db, levelPackPath);
    await upsertLevel(db, levelPath);

    const userId      = await getUserId(db, uuid);
    const levelPackId = await getLevelPackId(db, levelPackPath);
    const levelId     = await getLevelId(db, levelPath);

    await db.prepare(
      'INSERT INTO scores (user_id, level_pack_id, level_id, score) VALUES (?, ?, ?, ?)'
    ).bind(userId, levelPackId, levelId, score).run();

    return jsonOk({ userId, uuid, score, levelPackPath, levelPath });

  } else {
    return jsonError(`Unknown action '${action}'`);
  }
}

// ---------------------------------------------------------------------------
// GET handlers
// ---------------------------------------------------------------------------

async function handleGet(url, db) {
  const action = url.searchParams.get('action');

  if (action === 'getWorldScores') {
    const totalUsersRow = await db.prepare(
      'SELECT count(*) as count FROM users'
    ).first();
    const totalUsers = totalUsersRow?.count ?? 0;

    const levelRows = await db.prepare(
      `SELECT s.level_pack_id, s.level_id,
              lp.level_pack_path, l.level_path
       FROM scores s
       JOIN level_packs lp ON lp.level_pack_id = s.level_pack_id
       JOIN levels l ON l.level_id = s.level_id
       GROUP BY s.level_pack_id, s.level_id`
    ).all();

    const levels = {};

    for (const row of levelRows.results) {
      const key = `${row.level_pack_path}:${row.level_path}`;
      const entry = { levelPackId: row.level_pack_id, levelId: row.level_id, totalUsers };

      const summary = await db.prepare(
        `SELECT * FROM scores_summary
         WHERE level_pack_id = ? AND level_id = ?
           AND created >= datetime('now', '-24 hours')
           AND updating = 0
         ORDER BY created DESC LIMIT 1`
      ).bind(row.level_pack_id, row.level_id).first();

      if (summary) {
        entry.totalUsers  = summary.total_users;
        entry.totalPlays  = summary.total_plays;
        entry.uniquePlays = summary.unique_plays;
        entry.totalWins   = summary.total_wins;
        entry.uniqueWins  = summary.unique_wins;
        entry.scoreMean   = summary.score_mean;
        entry.scoreMedian = summary.score_median;
        entry.scoreStdDev = summary.score_std_dev;
      } else {
        await db.prepare(
          'INSERT INTO scores_summary (level_pack_id, level_id) VALUES (?, ?)'
        ).bind(row.level_pack_id, row.level_id).run();

        const summaryId = (await db.prepare(
          'SELECT last_insert_rowid() as id'
        ).first()).id;

        const plays = await db.prepare(
          `SELECT count(DISTINCT user_id) as uniquePlays, count(*) as totalPlays
           FROM plays WHERE level_pack_id = ? AND level_id = ?`
        ).bind(row.level_pack_id, row.level_id).first();

        const wins = await db.prepare(
          `SELECT count(DISTINCT user_id) as uniqueWins, count(*) as totalWins
           FROM scores WHERE level_pack_id = ? AND level_id = ?`
        ).bind(row.level_pack_id, row.level_id).first();

        const stats = await db.prepare(
          `SELECT CAST(avg(score) AS INTEGER) as scoreMean,
                  CAST(sqrt(avg(score*score) - avg(score)*avg(score)) AS INTEGER) as scoreStdDev
           FROM scores WHERE level_pack_id = ? AND level_id = ?`
        ).bind(row.level_pack_id, row.level_id).first();

        const totalWins = wins?.totalWins ?? 0;
        const offset = Math.floor(0.6 * totalWins);
        const medianRow = totalWins > 0
          ? await db.prepare(
              `SELECT score FROM scores
               WHERE level_pack_id = ? AND level_id = ?
               ORDER BY score ASC LIMIT 1 OFFSET ?`
            ).bind(row.level_pack_id, row.level_id, offset).first()
          : null;

        entry.uniquePlays = plays?.uniquePlays ?? 0;
        entry.totalPlays  = plays?.totalPlays  ?? 0;
        entry.uniqueWins  = wins?.uniqueWins   ?? 0;
        entry.totalWins   = totalWins;
        entry.scoreMean   = stats?.scoreMean   ?? 0;
        entry.scoreStdDev = stats?.scoreStdDev ?? 0;
        entry.scoreMedian = medianRow?.score ?? entry.scoreMean;

        await db.prepare(
          `UPDATE scores_summary SET
             total_users = ?, unique_plays = ?, total_plays = ?,
             unique_wins = ?, total_wins = ?, score_mean = ?,
             score_median = ?, score_std_dev = ?, updating = 0
           WHERE score_summary_id = ?`
        ).bind(
          totalUsers,
          entry.uniquePlays, entry.totalPlays,
          entry.uniqueWins,  entry.totalWins,
          entry.scoreMean,   entry.scoreMedian, entry.scoreStdDev,
          summaryId
        ).run();
      }

      levels[key] = entry;
    }

    return jsonOk({ levels });

  } else {
    return jsonError(`Unknown action '${action}'`);
  }
}

// ---------------------------------------------------------------------------
// DB helpers
// ---------------------------------------------------------------------------

async function upsertUser(db, uuid) {
  await db.prepare('INSERT OR IGNORE INTO users (uuid) VALUES (?)').bind(uuid).run();
}
async function upsertLevelPack(db, path) {
  await db.prepare('INSERT OR IGNORE INTO level_packs (level_pack_path) VALUES (?)').bind(path).run();
}
async function upsertLevel(db, path) {
  await db.prepare('INSERT OR IGNORE INTO levels (level_path) VALUES (?)').bind(path).run();
}
async function getUserId(db, uuid) {
  return (await db.prepare('SELECT user_id FROM users WHERE uuid = ?').bind(uuid).first())?.user_id ?? null;
}
async function getLevelPackId(db, path) {
  return (await db.prepare('SELECT level_pack_id FROM level_packs WHERE level_pack_path = ?').bind(path).first())?.level_pack_id ?? null;
}
async function getLevelId(db, path) {
  return (await db.prepare('SELECT level_id FROM levels WHERE level_path = ?').bind(path).first())?.level_id ?? null;
}

// ---------------------------------------------------------------------------
// Response helpers
// ---------------------------------------------------------------------------

function jsonOk(data) {
  return new Response(JSON.stringify({ status: 'ok', ...data }), {
    headers: { 'Content-Type': 'application/json' }
  });
}
function jsonError(message, status = 400) {
  return new Response(JSON.stringify({ status: 'error', message }), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

'use strict';

require('dotenv').config();

const express  = require('express');
const { Pool } = require('pg');
const jwt      = require('jsonwebtoken');
const multer   = require('multer');
const crypto   = require('crypto');

// ── App ───────────────────────────────────────────────────────────────────────
const app  = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
app.use(express.json({ limit: '1mb' }));

// ── CORS ──────────────────────────────────────────────────────────────────────
const allowedOrigins = (process.env.CORS_ALLOW_ORIGINS || '')
    .split(',')
    .map(origin => origin.trim())
    .filter(Boolean);

app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && allowedOrigins.includes(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
    }
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
});

// ── Database ──────────────────────────────────────────────────────────────────
// Reuse pool across hot invocations on the same serverless instance.
if (!global._gesturePool) {
    global._gesturePool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === 'false' ? false : { rejectUnauthorized: false },
        max: 3,
        idleTimeoutMillis: 20000,
        connectionTimeoutMillis: 5000,
    });
}
const pool = global._gesturePool;

// ── JWT ───────────────────────────────────────────────────────────────────────
const JWT_SECRET  = process.env.JWT_SECRET;
const JWT_EXPIRES = process.env.JWT_EXPIRES || '7d';
const JWT_ISSUER  = process.env.JWT_ISSUER || 'gestureapp-api';
const JWT_AUDIENCE = process.env.JWT_AUDIENCE || 'gestureapp-ios';

if (!JWT_SECRET || JWT_SECRET.length < 32) {
    throw new Error('JWT_SECRET must be set and at least 32 characters long');
}

function signJWT(vkUserId) {
    return jwt.sign(
        { sub: String(vkUserId) },
        JWT_SECRET,
        {
            expiresIn: JWT_EXPIRES,
            issuer: JWT_ISSUER,
            audience: JWT_AUDIENCE,
        }
    );
}

// ── Auth middleware ───────────────────────────────────────────────────────────
function auth(req, res, next) {
    const header = req.headers['authorization'];
    if (!header?.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
        req.claims = jwt.verify(header.slice(7), JWT_SECRET, {
            algorithms: ['HS256'],
            issuer: JWT_ISSUER,
            audience: JWT_AUDIENCE,
        });
        next();
    } catch {
        res.status(401).json({ error: 'Token expired or invalid' });
    }
}

// ── UUID derivation – MUST match iOS `UUID.fromVKUserIDString` ────────────────
function vkUserIdToUUID(vkUserId) {
    const hash  = crypto.createHash('sha256').update(`vk:${vkUserId}`).digest();
    const bytes = Buffer.from(hash.slice(0, 16));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return [
        bytes.slice(0,  4).toString('hex'),
        bytes.slice(4,  6).toString('hex'),
        bytes.slice(6,  8).toString('hex'),
        bytes.slice(8, 10).toString('hex'),
        bytes.slice(10,16).toString('hex'),
    ].join('-');
}

// ── VK ID: verify access token ────────────────────────────────────────────────
// VK ID SDK v2+ tokens are validated via id.vk.com/oauth2/user_info.
// Fallback: classic api.vk.com for legacy tokens.
// Both calls have a hard 3-second timeout so the endpoint never hangs.
async function fetchWithTimeout(url, opts = {}, ms = 3000) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), ms);
    try {
        return await fetch(url, { ...opts, signal: ctrl.signal });
    } finally {
        clearTimeout(timer);
    }
}

async function getVKUser(accessToken) {
    const VK_APP_ID = process.env.VK_CLIENT_ID || '54556592';

    // Primary: VK ID Connect userinfo (OAuth 2.0 tokens from VKID SDK v2+)
    try {
        const r1 = await fetchWithTimeout('https://id.vk.com/oauth2/user_info', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `client_id=${VK_APP_ID}&access_token=${encodeURIComponent(accessToken)}`,
        }, 3000);
        const j1 = await r1.json();
        if (j1.user && j1.user.user_id) {
            const u = j1.user;
            return {
                id:         u.user_id,
                first_name: u.first_name || '',
                last_name:  u.last_name  || '',
                photo_100:  u.avatar     || null,
            };
        }
    } catch (_) { /* fall through */ }

    // Fallback: classic VK API
    try {
        const r2 = await fetchWithTimeout(
            `https://api.vk.com/method/users.get?access_token=${encodeURIComponent(accessToken)}&fields=photo_100&v=5.199`,
            {}, 3000
        );
        const j2 = await r2.json();
        if (!j2.error && j2.response?.[0]) return j2.response[0];
    } catch (_) { /* fall through */ }

    return null;
}

function isUUID(value) {
    return typeof value === 'string'
        && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function badRequest(res, message) {
    return res.status(400).json({ error: message });
}

function cleanText(value, maxLength) {
    if (value == null) return null;
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    if (trimmed.length === 0) return '';
    return trimmed.slice(0, maxLength);
}

function sanitizeStringArray(value, { maxItems = 20, maxLength = 64 } = {}) {
    if (!Array.isArray(value)) return [];
    return value
        .filter(item => typeof item === 'string')
        .map(item => item.trim())
        .filter(Boolean)
        .slice(0, maxItems)
        .map(item => item.slice(0, maxLength));
}

function validateProfilePayload(body) {
    if (!body || typeof body !== 'object') return 'Invalid profile payload';
    if (typeof body.name !== 'string' || body.name.trim().length < 2 || body.name.trim().length > 80) {
        return 'Name must be 2-80 characters';
    }
    if (typeof body.city !== 'string' || body.city.trim().length > 120) {
        return 'City must be at most 120 characters';
    }
    if (typeof body.gender !== 'string' || !['male', 'female', 'non_binary', 'other'].includes(body.gender)) {
        return 'Invalid gender';
    }
    if (typeof body.hearing_status !== 'string'
        || !['deaf', 'hard_of_hearing', 'late_deafened', 'coda', 'hearing_ally'].includes(body.hearing_status)) {
        return 'Invalid hearing status';
    }
    if (body.birthdate != null && !/^\d{4}-\d{2}-\d{2}$/.test(body.birthdate)) {
        return 'Birthdate must be in YYYY-MM-DD format';
    }
    if (body.bio != null && (typeof body.bio !== 'string' || body.bio.length > 2000)) {
        return 'Bio must be at most 2000 characters';
    }
    if (body.video_intro_url != null && typeof body.video_intro_url !== 'string') {
        return 'Invalid video URL';
    }
    if (body.photo_urls != null) {
        if (!Array.isArray(body.photo_urls) || body.photo_urls.length > 6) return 'Too many profile photos';
        const invalidURL = body.photo_urls.some(url => typeof url !== 'string' || url.length > 2048);
        if (invalidURL) return 'Invalid profile photo URL';
    }
    return null;
}

async function requireOwnProfile(req, res) {
    const vkUserId = Number(req.claims.sub);
    const { rows: [me] } = await pool.query(
        'SELECT id, vk_user_id FROM profiles WHERE vk_user_id = $1',
        [vkUserId]
    );
    if (!me) {
        res.status(404).json({ error: 'Profile not found' });
        return null;
    }
    return me;
}

async function requireMatchMembership(matchId, profileId) {
    const { rows: [match] } = await pool.query(
        `SELECT id, user_a, user_b
         FROM matches
         WHERE id = $1 AND (user_a = $2 OR user_b = $2)`,
        [matchId, profileId]
    );
    return match || null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Routes
// ═══════════════════════════════════════════════════════════════════════════════

// ── POST /api/v1/auth/vk ──────────────────────────────────────────────────────
app.post('/api/v1/auth/vk', async (req, res) => {
    try {
        const { access_token } = req.body;
        if (!access_token) return res.status(400).json({ error: 'access_token required' });

        const vkUser = await getVKUser(access_token);

        if (!vkUser) {
            return res.status(401).json({ error: 'VK token verification failed' });
        }

        const vkUserId  = vkUser.id;
        const profileId = vkUserIdToUUID(vkUserId);
        const rawName   = `${vkUser.first_name} ${vkUser.last_name}`.trim();
        // Some schemas enforce NOT NULL / non-empty name — use a sensible placeholder.
        const name      = rawName.length > 0 ? rawName : `VK User ${vkUserId}`;

        await pool.query(
            `INSERT INTO profiles (id, vk_user_id, name)
             VALUES ($1, $2, $3)
             ON CONFLICT (id) DO UPDATE SET
               name = CASE WHEN EXCLUDED.name <> '' THEN EXCLUDED.name ELSE profiles.name END`,
            [profileId, vkUserId, name]
        );

        res.json({ token: signJWT(vkUserId), vk_user_id: vkUserId });
    } catch (err) {
        console.error('/auth/vk', err);
        res.status(500).json({ error: err.message });
    }
});

// ── GET /api/v1/profile/me ────────────────────────────────────────────────────
app.get('/api/v1/profile/me', auth, async (req, res) => {
    try {
        const vkUserId = Number(req.claims.sub);
        const { rows } = await pool.query(
            'SELECT * FROM profiles WHERE vk_user_id = $1',
            [vkUserId]
        );
        if (!rows[0]) return res.status(404).json({ error: 'Profile not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error('/profile/me GET', err);
        res.status(500).json({ error: err.message });
    }
});

// ── PUT /api/v1/profile/me ────────────────────────────────────────────────────
app.put('/api/v1/profile/me', auth, async (req, res) => {
    try {
        const validationError = validateProfilePayload(req.body);
        if (validationError) return badRequest(res, validationError);

        const vkUserId = Number(req.claims.sub);
        const b = req.body;
        const { rows } = await pool.query(
            `UPDATE profiles
             SET name=$1, birthdate=$2, gender=$3, city=$4, bio=$5,
                 hearing_status=$6, communication=$7, interests=$8,
                 photo_urls=$9, video_intro_url=$10, is_hidden=$11
             WHERE vk_user_id=$12
             RETURNING *`,
            [
                cleanText(b.name, 80),
                b.birthdate,
                b.gender,
                cleanText(b.city, 120) ?? '',
                cleanText(b.bio, 2000) ?? '',
                b.hearing_status,
                sanitizeStringArray(b.communication),
                sanitizeStringArray(b.interests, { maxItems: 30, maxLength: 64 }),
                b.photo_urls ?? [],
                cleanText(b.video_intro_url, 2048) ?? null,
                Boolean(b.is_hidden),
                vkUserId,
            ]
        );
        if (!rows[0]) return res.status(404).json({ error: 'Profile not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error('/profile/me PUT', err);
        res.status(500).json({ error: err.message });
    }
});

// ── DELETE /api/v1/profile/me ────────────────────────────────────────────────
app.delete('/api/v1/profile/me', auth, async (req, res) => {
    try {
        const me = await requireOwnProfile(req, res);
        if (!me) return;

        await pool.query('DELETE FROM profiles WHERE id = $1', [me.id]);
        res.status(204).send();
    } catch (err) {
        console.error('/profile/me DELETE', err);
        res.status(500).json({ error: err.message });
    }
});

// ── GET /api/v1/feed ──────────────────────────────────────────────────────────
app.get('/api/v1/feed', auth, async (req, res) => {
    try {
        const vkUserId = Number(req.claims.sub);
        const limit    = Math.min(Number(req.query.limit) || 20, 50);
        const { rows } = await pool.query(
            `SELECT p.*
             FROM profiles p
             WHERE p.vk_user_id <> $1
               AND p.is_hidden = false
               AND p.id NOT IN (
                   SELECT s.target_id
                   FROM   swipes s
                   JOIN   profiles me ON me.id = s.swiper_id AND me.vk_user_id = $1
               )
             ORDER BY RANDOM()
             LIMIT $2`,
            [vkUserId, limit]
        );
        res.json(rows);
    } catch (err) {
        console.error('/feed', err);
        res.status(500).json({ error: err.message });
    }
});

// ── POST /api/v1/swipes ───────────────────────────────────────────────────────
app.post('/api/v1/swipes', auth, async (req, res) => {
    try {
        const { target_id, liked } = req.body;
        if (!isUUID(target_id)) return badRequest(res, 'target_id must be a valid UUID');
        if (typeof liked !== 'boolean') return badRequest(res, 'liked must be a boolean');

        const decision = liked ? 'like' : 'pass';

        const me = await requireOwnProfile(req, res);
        if (!me) return;

        const { rows: [target] } = await pool.query(
            'SELECT id FROM profiles WHERE id = $1 AND is_hidden = false',
            [target_id]
        );
        if (!target) return res.status(404).json({ error: 'Target profile not found' });
        if (target.id === me.id) return badRequest(res, 'Cannot swipe your own profile');

        await pool.query(
            `INSERT INTO swipes (swiper_id, target_id, decision)
             VALUES ($1, $2, $3)
             ON CONFLICT (swiper_id, target_id) DO NOTHING`,
            [me.id, target.id, decision]
        );

        let matched = false;
        let match   = null;

        if (liked) {
            const { rows: [mutual] } = await pool.query(
                `SELECT id FROM swipes
                 WHERE swiper_id=$1 AND target_id=$2 AND decision='like'`,
                [target.id, me.id]
            );
            if (mutual) {
                const a = me.id < target.id ? me.id : target.id;
                const b = me.id < target.id ? target.id : me.id;
                const { rows: [m] } = await pool.query(
                    `INSERT INTO matches (user_a, user_b)
                     VALUES ($1, $2)
                     ON CONFLICT DO NOTHING
                     RETURNING *`,
                    [a, b]
                );
                if (m) { matched = true; match = m; }
            }
        }

        res.json({ matched, match });
    } catch (err) {
        console.error('/swipes', err);
        res.status(500).json({ error: err.message });
    }
});

// ── GET /api/v1/matches ───────────────────────────────────────────────────────
app.get('/api/v1/matches', auth, async (req, res) => {
    try {
        const vkUserId = Number(req.claims.sub);
        const { rows } = await pool.query(
            `SELECT
                 m.id,
                 m.created_at,
                 latest.text          AS last_message_preview,
                 latest.created_at    AS last_message_at,
                 EXISTS (
                     SELECT 1 FROM messages unread
                     WHERE  unread.match_id  = m.id
                       AND  unread.sender_id <> me.id
                       AND  unread.read_at   IS NULL
                 ) AS has_unread,
                 row_to_json(other.*) AS other_profile
             FROM matches m
             JOIN profiles me    ON (me.id = m.user_a OR me.id = m.user_b)
                                 AND me.vk_user_id = $1
             JOIN profiles other ON (other.id = m.user_a OR other.id = m.user_b)
                                 AND other.id <> me.id
             LEFT JOIN LATERAL (
                 SELECT text, created_at
                 FROM   messages
                 WHERE  match_id = m.id
                 ORDER  BY created_at DESC
                 LIMIT  1
             ) latest ON true
             ORDER BY COALESCE(latest.created_at, m.created_at) DESC`,
            [vkUserId]
        );
        res.json(rows);
    } catch (err) {
        console.error('/matches', err);
        res.status(500).json({ error: err.message });
    }
});

// ── GET /api/v1/matches/:id/messages ─────────────────────────────────────────
app.get('/api/v1/matches/:id/messages', auth, async (req, res) => {
    try {
        if (!isUUID(req.params.id)) return badRequest(res, 'Invalid match id');

        const me = await requireOwnProfile(req, res);
        if (!me) return;

        const match = await requireMatchMembership(req.params.id, me.id);
        if (!match) return res.status(403).json({ error: 'Forbidden' });

        const { rows } = await pool.query(
            `SELECT * FROM messages WHERE match_id=$1 ORDER BY created_at ASC`,
            [req.params.id]
        );
        res.json(rows);
    } catch (err) {
        console.error('/matches/:id/messages GET', err);
        res.status(500).json({ error: err.message });
    }
});

// ── POST /api/v1/matches/:id/messages ────────────────────────────────────────
app.post('/api/v1/matches/:id/messages', auth, async (req, res) => {
    try {
        if (!isUUID(req.params.id)) return badRequest(res, 'Invalid match id');

        const b = req.body;
        const me = await requireOwnProfile(req, res);
        if (!me) return;

        const match = await requireMatchMembership(req.params.id, me.id);
        if (!match) return res.status(403).json({ error: 'Forbidden' });

        const kind = ['text', 'video', 'image'].includes(b.kind) ? b.kind : 'text';
        const text = cleanText(b.text, 4000);
        const mediaURL = cleanText(b.media_url, 2048);
        const thumbnailURL = cleanText(b.thumbnail_url, 2048);
        const durationSec = typeof b.duration_sec === 'number' ? b.duration_sec : null;

        if (kind === 'text' && !text) return badRequest(res, 'Text message cannot be empty');
        if (kind !== 'text' && !mediaURL) return badRequest(res, 'media_url is required for media messages');

        const { rows: [msg] } = await pool.query(
            `INSERT INTO messages
                 (match_id, sender_id, kind, text, media_url, duration_sec, thumbnail_url)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING *`,
            [
                match.id,
                me.id,
                kind,
                text || null,
                mediaURL ?? null,
                durationSec,
                thumbnailURL ?? null,
            ]
        );
        res.json(msg);
    } catch (err) {
        console.error('/matches/:id/messages POST', err);
        res.status(500).json({ error: err.message });
    }
});

// ── Media uploads (optional – requires S3 env vars) ───────────────────────────
let s3 = null, BUCKET = null, CDN_BASE = null;
if (process.env.S3_ENDPOINT && process.env.S3_ACCESS_KEY && process.env.S3_SECRET_KEY) {
    const { S3Client } = require('@aws-sdk/client-s3');
    s3 = new S3Client({
        endpoint:    process.env.S3_ENDPOINT,
        region:      process.env.S3_REGION || 'ru-msk',
        credentials: { accessKeyId: process.env.S3_ACCESS_KEY, secretAccessKey: process.env.S3_SECRET_KEY },
        forcePathStyle: true,
    });
    BUCKET   = process.env.S3_BUCKET;
    CDN_BASE = (process.env.CDN_BASE || '').replace(/\/$/, '');
}

const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 50 * 1024 * 1024 },
});

function ensureAllowedUpload(req, allowedMimeTypes) {
    if (!req.file) return 'No file uploaded';
    if (!allowedMimeTypes.includes(req.file.mimetype)) return 'Unsupported file type';
    if (!req.file.originalname || req.file.originalname.length > 255) return 'Invalid filename';
    return null;
}

async function handleUpload(req, res, folder, contentType, allowedMimeTypes) {
    if (!s3) return res.status(503).json({ error: 'Media storage not configured' });
    try {
        const uploadError = ensureAllowedUpload(req, allowedMimeTypes);
        if (uploadError) return res.status(400).json({ error: uploadError });
        const { PutObjectCommand } = require('@aws-sdk/client-s3');
        const ext = (req.file.originalname || 'bin').split('.').pop().toLowerCase();
        const key = `${folder}/${Date.now()}-${crypto.randomUUID()}.${ext}`;
        await s3.send(new PutObjectCommand({
            Bucket: BUCKET, Key: key, Body: req.file.buffer,
            ContentType: contentType,
        }));
        res.json({ url: `${CDN_BASE}/${key}` });
    } catch (err) {
        console.error('upload', err);
        res.status(500).json({ error: err.message });
    }
}

app.post(
    '/api/v1/media/avatar',
    auth,
    upload.single('file'),
    (req, res) => handleUpload(req, res, 'avatars', 'image/jpeg', ['image/jpeg', 'image/jpg'])
);
app.post(
    '/api/v1/media/video',
    auth,
    upload.single('file'),
    (req, res) => handleUpload(req, res, 'videos', 'video/mp4', ['video/mp4', 'video/quicktime'])
);

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ ok: true, ts: Date.now() }));

// ── Standalone server entrypoint ──────────────────────────────────────────────
// Start listening only when this file is launched directly.
// When imported by a serverless platform, export the app without binding a port.
if (require.main === module) {
    app.listen(PORT, HOST, () => console.log(`GestureApp API listening on ${HOST}:${PORT}`));
}

module.exports = app;

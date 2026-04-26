-- ============================================================
-- GestureApp – PostgreSQL schema
-- Run once on a fresh database (VK Cloud / Yandex Cloud)
-- ============================================================

-- ── Profiles ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
    id              UUID        PRIMARY KEY,
    vk_user_id      BIGINT      UNIQUE NOT NULL,
    name            TEXT        NOT NULL DEFAULT '',
    birthdate       DATE        NOT NULL DEFAULT '2000-01-01',
    gender          TEXT        NOT NULL DEFAULT 'other'
                                CHECK (gender IN ('male', 'female', 'other')),
    city            TEXT        NOT NULL DEFAULT '',
    bio             TEXT        NOT NULL DEFAULT '',
    hearing_status  TEXT        NOT NULL DEFAULT 'hard_of_hearing',
    communication   TEXT[]      NOT NULL DEFAULT '{}',
    interests       TEXT[]      NOT NULL DEFAULT '{}',
    photo_urls      TEXT[]      NOT NULL DEFAULT '{}',
    video_intro_url TEXT,
    is_verified     BOOLEAN     NOT NULL DEFAULT false,
    is_hidden       BOOLEAN     NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Swipes ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS swipes (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    swiper_id   UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    target_id   UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    decision    TEXT        NOT NULL CHECK (decision IN ('like', 'super_like', 'pass')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (swiper_id, target_id)
);

-- ── Matches ───────────────────────────────────────────────────────────────────
-- user_a < user_b guarantees a unique pair regardless of order.
CREATE TABLE IF NOT EXISTS matches (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a      UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    user_b      UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_a, user_b),
    CHECK (user_a < user_b)
);

-- ── Messages ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id      UUID        NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    sender_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    kind          TEXT        NOT NULL CHECK (kind IN ('text', 'video', 'image')),
    text          TEXT,
    media_url     TEXT,
    duration_sec  FLOAT,
    thumbnail_url TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at       TIMESTAMPTZ
);

-- ── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS swipes_swiper_idx     ON swipes  (swiper_id);
CREATE INDEX IF NOT EXISTS swipes_target_idx     ON swipes  (target_id);
CREATE INDEX IF NOT EXISTS matches_user_a_idx    ON matches (user_a);
CREATE INDEX IF NOT EXISTS matches_user_b_idx    ON matches (user_b);
CREATE INDEX IF NOT EXISTS messages_match_idx    ON messages(match_id, created_at);

-- ── Trigger: auto-update updated_at ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = public AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- DalaCarbon AI — дерекқор құрылымы (PostgreSQL 14+)
-- Қайта іске қосуға қауіпсіз: run.py әр іске қосылғанда орындайды.

CREATE TABLE IF NOT EXISTS users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(254) NOT NULL,
    username      VARCHAR(32)  NOT NULL,
    full_name     VARCHAR(120),
    password_hash TEXT,                      -- тек Google арқылы кіретіндерде NULL
    google_sub    VARCHAR(255),              -- Google аккаунтының тұрақты ID-і (OpenID «sub»)
    region        VARCHAR(32)  NOT NULL,
    farm_type     VARCHAR(16)  NOT NULL,
    newsletter    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT users_username_format CHECK (username ~ '^[A-Za-z0-9_]{4,32}$')
);

-- Ескі нұсқадан жаңартылатын дерекқорлар үшін (Google арқылы кіру қосылғанда).
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255);
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_password_is_argon2id;
ALTER TABLE users ADD  CONSTRAINT users_password_is_argon2id
    CHECK (password_hash IS NULL OR password_hash LIKE '$argon2id$%');

-- Әр аккаунттың кем дегенде бір кіру тәсілі болуы тиіс.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_has_login_method;
ALTER TABLE users ADD  CONSTRAINT users_has_login_method
    CHECK (password_hash IS NOT NULL OR google_sub IS NOT NULL);

-- Логин мен email регистрге қарамай бірегей: «Dala_Fermer» және «dala_fermer» — бір логин.
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_key    ON users (LOWER(email));
CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_key ON users (LOWER(username));
CREATE UNIQUE INDEX IF NOT EXISTS users_google_sub_key     ON users (google_sub) WHERE google_sub IS NOT NULL;

COMMENT ON TABLE  users               IS 'DalaCarbon AI пайдаланушылары';
COMMENT ON COLUMN users.password_hash IS 'Argon2id хеші (тұзы ішінде). Ашық құпиясөз ешқашан сақталмайды.';
COMMENT ON COLUMN users.google_sub    IS 'Google OpenID «sub» — Google арқылы кіру үшін';

-- Фермердің алқаптары (учаскелері): басқару тақтасындағы «Алқап қосу».
CREATE TABLE IF NOT EXISTS parcels (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       VARCHAR(60)  NOT NULL,
    area_ha    NUMERIC(9,1) NOT NULL CHECK (area_ha > 0 AND area_ha <= 100000),
    crop       VARCHAR(16)  NOT NULL,
    practice   VARCHAR(16)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS parcels_user_idx ON parcels (user_id, created_at);

COMMENT ON TABLE parcels IS 'Пайдаланушы алқаптары (MRV есебіне кіретін учаскелер)';

-- Құпиясөзді қалпына келтіру. Токеннің өзі емес, тек SHA-256 хеші сақталады;
-- сілтеме бір рет қана жарамды және 30 минуттан кейін ескіреді.
ALTER TABLE users ADD COLUMN IF NOT EXISTS session_epoch INTEGER NOT NULL DEFAULT 0;  -- өссе, ескі сессиялар жабылады

CREATE TABLE IF NOT EXISTS password_resets (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash CHAR(64)    NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS password_resets_user_idx ON password_resets (user_id, created_at);

COMMENT ON TABLE password_resets IS 'Құпиясөзді қалпына келтіру сілтемелері (токен хеші, мерзімі, қолданылғаны)';

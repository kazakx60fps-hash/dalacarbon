-- DalaCarbon AI — дерекқор құрылымы (PostgreSQL 14+)
-- Қайта іске қосуға қауіпсіз: барлық нысандар IF NOT EXISTS арқылы жасалады.

CREATE TABLE IF NOT EXISTS users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(254) NOT NULL,
    username      VARCHAR(32)  NOT NULL,
    full_name     VARCHAR(120),
    password_hash TEXT         NOT NULL,
    region        VARCHAR(32)  NOT NULL,
    farm_type     VARCHAR(16)  NOT NULL,
    newsletter    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT users_username_format CHECK (username ~ '^[A-Za-z0-9_]{4,32}$'),
    CONSTRAINT users_password_is_argon2id CHECK (password_hash LIKE '$argon2id$%')
);

-- Логин мен email регистрге қарамай бірегей: «Dala_Fermer» және «dala_fermer» — бір логин.
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_key    ON users (LOWER(email));
CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_key ON users (LOWER(username));

COMMENT ON TABLE  users               IS 'DalaCarbon AI пайдаланушылары';
COMMENT ON COLUMN users.password_hash IS 'Argon2id хеші (тұзы ішінде). Ашық құпиясөз ешқашан сақталмайды.';

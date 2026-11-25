# DalaCarbon AI — веб-қосымша

Дала топырағындағы көміртегін өлшейтін MRV платформасының сайты.
**Негізгі тіл — Python.** Беттер HTML (Jinja2), CSS және JavaScript-пен үйлестірілген.

| Қабат | Технология | Не істейді |
|---|---|---|
| Сервер | **Python 3.13 + Flask** | Маршруттар, форма тексеру, сессия, CSRF |
| Дерекқор | **PostgreSQL** + psycopg 3 | Пайдаланушыларды сақтау, параметрленген сұраныстар |
| Қауіпсіздік | **argon2-cffi (Argon2id)** | Құпиясөзді хештеу (OWASP №1 ұсынысы) |
| Беттер | Jinja2 шаблондары (HTML) | Сервер жағында құрастырылатын беттер |
| Дизайн | CSS (өз стильдері) | «Түнгі дала» фоны, десктоп + телефон |
| Браузер | JavaScript | Нақты уақыттағы тексеру, құпиясөз күші, көрсету/жасыру |

## Құрылымы

```
dalacarbon/
├── run.py                  # серверді іске қосу (кестелерді де жасайды)
├── app/
│   ├── __init__.py         # create_app(): баптаулар, қате беттері
│   ├── auth.py             # /register, /login, /logout, login_required
│   ├── google_auth.py      # /auth/google — Google арқылы кіру (Authlib, OpenID Connect)
│   ├── main.py             # /dashboard — кіргеннен кейінгі негізгі бет
│   ├── validators.py       # форма тексеру ережелері (Python)
│   ├── security.py         # Argon2id, CSRF, қауіпсіздік тақырыптары
│   ├── db.py               # PostgreSQL: пайдаланушыны сақтау және іздеу
│   ├── templates/          # base, register, login, google_complete, dashboard, error, partials/
│   └── static/             # css/app.css, js/{common,register,login}.js, img/
├── db/
│   ├── schema.sql          # users кестесі
│   └── setup.sql           # негізгі серверде рөл мен дерекқор жасау
└── tests/                  # pytest: 44 тест
```

## Google арқылы кіруді баптау

Код дайын — тек Google-дан өз кілттеріңізді алу керек (тегін, ~10 минут):

1. <https://console.cloud.google.com/> → жоғарыдан **New Project** → атауы `DalaCarbon AI`.
2. **APIs & Services → OAuth consent screen** (немесе **Google Auth Platform → Branding**):
   - App name: `DalaCarbon AI`, support email — өз поштаңыз;
   - Audience: **External**, режимі **Testing**;
   - **Test users** бөліміне кіретін Gmail мекенжайларын қосыңыз.
3. **Credentials → Create credentials → OAuth client ID**:
   - Application type: **Web application**;
   - **Authorized redirect URIs** — екеуін де қосыңыз:
     - `http://127.0.0.1:5000/auth/google/callback`
     - `http://localhost:5000/auth/google/callback`
4. Шыққан **Client ID** мен **Client secret**-ті `.env` файлына қойыңыз:
   ```
   GOOGLE_CLIENT_ID=....apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=GOCSPX-...
   ```
5. `run.py` қайта іске қосыңыз — Google батырмасы шын сілтемеге айналады.

**Қалай жұмыс істейді:** Google `id_token` береді (қолтаңба, `state`, `nonce`, PKCE тексеріледі),
email расталмаған болса кіргізбейді. Сол email-мен бұрын тіркелген аккаунт болса — оған байланысады.
Жаңа пайдаланушыдан тек логин, облыс және шаруашылық түрі сұралады; оның құпиясөзі болмайды
(`password_hash = NULL`, `google_sub` толтырылады).

## Іске қосу

Жоба папкасында (`C:\Users\TechHub\Desktop\dalacarbon`):

```powershell
uv venv .venv --python 3.13
uv pip install --python .venv\Scripts\python.exe -r requirements.txt -r requirements-dev.txt
.venv\Scripts\python.exe run.py
```

Браузерде ашыңыз: <http://127.0.0.1:5000/login>

> **Windows ескертуі:** жоба папкасының жолы қысқа болсын.
> Жол 260 таңбадан ұзын болса, `argon2` пен `psycopg` DLL-дары жүктелмейді.

`brand/logo/` папкасында логотиптің барлық нұсқалары бар (SVG, PNG, брендбук).

### Негізгі PostgreSQL серверіне қосу

1. Баптаулар файлын жасаңыз: `copy .env.example .env`, сосын `SECRET_KEY` мәнін толтырыңыз.
2. `db/setup.sql` ішіндегі `ӨЗ_ПАРОЛІҢІЗ` орнына құпиясөз жазып, сол құпиясөзді `.env`-тегі
   `DATABASE_URL` пен `TEST_DATABASE_URL` жолдарына да қойыңыз.
3. `db/setup.sql` файлын `postgres` пайдаланушысымен бір рет орындаңыз
   (pgAdmin Query Tool-да жолдарды бөлек белгілеп F5, немесе psql):
   ```powershell
   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost -f db\setup.sql
   ```
4. `run.py` іске қосыңыз — `users` кестесі автоматты түрде жасалады.

> `.env` файлы git-ке қосылмайды (`.gitignore`) — құпиясөздер мен кілттер тек сіздің компьютеріңізде.

### Тесттер

```powershell
.venv\Scripts\python.exe -m pytest -q
```

`TEST_DATABASE_URL` берілмесе, дерекқор тесттері өткізіліп жіберіледі.

## Бағалау критерийлеріне сәйкестік

| № | Критерий | Қалай орындалды |
|---|---|---|
| 1 | Тартымды дизайн, түс үйлесімі | Бір акцент түсі (алтын), WCAG 4.5:1 контраст, тақырыпқа сай «түнгі дала» фоны, телефон нұсқасы |
| 2 | Логин және құпиясөз өрістері | `/login`: «Логин немесе email» + «Құпиясөз», белгілері өрістің үстінде |
| 3 | «Кіру» батырмасы | Форманы серверге жібереді, тексеру кезінде бұғатталады (екі рет басылмайды) |
| 4 | «Тіркелу» беті | `/register` → PostgreSQL → `/register/success` → кіру беті (логин толтырылған) |
| 5 | Бос өрістер мен қате хабарламалары | Браузерде (JS) **және** серверде (Python); қате өрістің астында: қызыл жиек + белгі + мәтін |
| 6 | Құпиясөз жасырын | `type="password"` + «көрсету/жасыру» батырмасы (`aria-pressed`, `aria-label`) |
| 7 | PostgreSQL, хеш | `users.password_hash` — `$argon2id$v=19$m=65536,t=3,p=4$...`; ашық құпиясөз сақталмайды |
| 8 | Дұрыс болса — негізгі бет | Argon2 тексерісі → `session["user_id"]` → `/dashboard` |
| 9 | Қате болса — кіргізбейді | HTTP 401 + бір ортақ хабарлама (логин жоқ па, құпиясөз қате ме — айырмайды, OWASP) |
| 10 | Код құрылымы | Модульдер: `db.py`, `security.py`, `validators.py`, `auth.py`, `main.py`; 44 pytest тесті |

**Қосымша қорғаныс:** CSRF токені (тіркелу, кіру, шығу), SQL-инъекцияға қарсы параметрленген
сұраныстар, логин табылмаса да Argon2 тексерісі (жауап уақыты бірдей), кіргенде сессияны жаңарту
(session fixation), `login_required` декораторы, «Мені есте сақта» (30 күн), логин мен email-ді
регистрге қарамай бірегей ету (`LOWER()` индекстері), Content-Security-Policy, Post/Redirect/Get.

## Қорғауға арналған демонстрация сценарийі

1. `/register` — жаңа пайдаланушы тіркеу (бос өрісті және сәйкес келмейтін құпиясөзді көрсету).
2. pgAdmin / psql: `SELECT username, password_hash FROM users;` — хеш `$argon2id$` деп басталады.
3. `/login` — әдейі қате құпиясөз → «Логин немесе құпиясөз сәйкес келмейді», кіргізбейді.
4. Дұрыс құпиясөз → `/dashboard` негізгі беті ашылады → «Шығу».

-- Негізгі PostgreSQL серверінде DalaCarbon дерекқорын жасау (бір рет).
-- 1) Төмендегі ӨЗ_ПАРОЛІҢІЗ орнына күшті құпиясөз жазыңыз да, сол құпиясөзді
--    .env файлындағы DATABASE_URL жолына да қойыңыз.
-- 2) postgres пайдаланушысымен іске қосыңыз (pgAdmin Query Tool немесе psql):
--      psql -U postgres -h localhost -f db/setup.sql
--    pgAdmin-де: CREATE DATABASE транзакция ішінде орындалмайды, сондықтан
--    жолдарды бөлек-бөлек белгілеп, F5 басыңыз.

CREATE ROLE dalacarbon_app LOGIN PASSWORD 'ӨЗ_ПАРОЛІҢІЗ';
CREATE DATABASE dalacarbon OWNER dalacarbon_app;
CREATE DATABASE dalacarbon_test OWNER dalacarbon_app;  -- тесттер үшін

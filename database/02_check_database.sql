-- EDS Schedule
-- Проверка структуры базы данных
-- База: eds_schedule
-- Схема: schedule

-- 1. Проверка подключения
SELECT current_database(), current_schema();

-- 2. Список прикладных таблиц
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'schedule'
    AND table_type = 'BASE TABLE'
    AND table_name <> '_prisma_migrations'
ORDER BY table_name;

-- 3. Количество прикладных таблиц
SELECT COUNT(*) AS tables_count
FROM information_schema.tables
WHERE table_schema = 'schedule'
    AND table_type = 'BASE TABLE'
    AND table_name <> '_prisma_migrations';

-- 4. Проверка количества ограничений
SELECT constraint_type,
       COUNT(*) AS constraints_count
FROM information_schema.table_constraints
WHERE table_schema = 'schedule'
    AND table_name <> '_prisma_migrations'
GROUP BY constraint_type
ORDER BY constraint_type;

-- 5. Проверка уникальных индексов
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'schedule'
    AND tablename <> '_prisma_migrations'
    AND indexdef LIKE 'CREATE UNIQUE INDEX%'
ORDER BY tablename, indexname;

-- 6. Проверка правил ссылочной целостности
SELECT constraint_name, delete_rule, update_rule
FROM information_schema.referential_constraints
WHERE constraint_schema = 'schedule'
ORDER BY constraint_name;

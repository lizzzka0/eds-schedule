-- ==================================================
-- EDS Schedule — автоматизированные SQL-тесты
-- PostgreSQL: eds_schedule; схема: schedule
-- DB-01 — DB-30. Запуск: весь файл одной командой.
-- Внимание: запускать в базе разработки, не на рабочей БД.
-- Временные записи удаляются; при неожиданной ошибке весь
-- блок откатывается. Последовательности SERIAL могут увеличиться.
-- DB-11: PostgreSQL 18+ использует 23001 вместо 23503.
-- https://www.postgresql.org/docs/release/18.0/
-- ==================================================

DO $tests$
DECLARE
    v_passed INTEGER := 0;
BEGIN
    IF current_database() <> 'eds_schedule' THEN
        RAISE EXCEPTION 'Выбрана неверная база данных: %', current_database();
    END IF;
    RAISE NOTICE 'PostgreSQL: %, база: %', current_setting('server_version'), current_database();
    RAISE NOTICE 'Начало тестирования: DB-01 — DB-30';

    -- Основные ограничения целостности: DB-01 — DB-11
    DECLARE
        v_classroom_id INTEGER;
        v_null_classroom_id INTEGER;
        v_program_id INTEGER;
        v_group_id INTEGER;
        v_prefix TEXT := 'TEST-' || txid_current();
        v_constraint TEXT;
        v_state TEXT;
        v_test RECORD;
    BEGIN
        -- ==========================================
        -- Положительные тестовые сценарии
        -- ==========================================

        -- DB-01. Корректная вместимость
        INSERT INTO schedule.classrooms (number, capacity)
        VALUES (v_prefix || '-01', 30)
        RETURNING id INTO v_classroom_id;

        v_passed := v_passed + 1;

        RAISE NOTICE 'DB-01: тест пройден';

        -- DB-04. Допустимость NULL
        INSERT INTO schedule.classrooms (number, capacity)
        VALUES (v_prefix || '-04', NULL)
        RETURNING id INTO v_null_classroom_id;

        v_passed := v_passed + 1;

        RAISE NOTICE 'DB-04: тест пройден';

        -- Подготовка образовательной программы
        INSERT INTO schedule.educational_programs (name)
        VALUES (v_prefix || '-PROGRAM')
        RETURNING id INTO v_program_id;

        -- DB-09. Корректный внешний ключ
        INSERT INTO schedule.study_groups (
            program_id,
            name,
            study_form
        )
        VALUES (
            v_program_id,
            v_prefix || '-GROUP',
            'FULL_TIME'
        )
        RETURNING id INTO v_group_id;

        v_passed := v_passed + 1;

        RAISE NOTICE 'DB-09: тест пройден';

        -- Убеждаемся, что внешний ключ действительно использует RESTRICT.
        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_constraint
            WHERE conrelid = 'schedule.study_groups'::regclass
              AND confrelid = 'schedule.educational_programs'::regclass
              AND conname = 'study_groups_program_id_fkey'
              AND contype = 'f'
              AND confdeltype = 'r'
        ) THEN
            RAISE EXCEPTION 'DB-11: отсутствует ожидаемый внешний ключ ON DELETE RESTRICT';
        END IF;

        -- Проверка доступности несуществующего ID
        IF EXISTS (
            SELECT 1
            FROM schedule.educational_programs
            WHERE id = -1
        ) THEN
            RAISE EXCEPTION 'Тестовый идентификатор занят';
        END IF;

        -- ==========================================
        -- Отрицательные тестовые сценарии
        -- ==========================================

        FOR v_test IN
            SELECT *
            FROM (VALUES

                -- DB-02. Отрицательная вместимость
                (
                    'DB-02',
                    format(
                        'INSERT INTO schedule.classrooms
                        (number, capacity) VALUES (%L, -10)',
                        v_prefix || '-02'
                    ),
                    '23514',
                    'classrooms_capacity_check'
                ),

                -- DB-03. Нулевая вместимость
                (
                    'DB-03',
                    format(
                        'INSERT INTO schedule.classrooms
                        (number, capacity) VALUES (%L, 0)',
                        v_prefix || '-03'
                    ),
                    '23514',
                    'classrooms_capacity_check'
                ),

                -- DB-05. Пустое обозначение аудитории
                (
                    'DB-05',
                    'INSERT INTO schedule.classrooms
                    (number, capacity) VALUES ('''', 30)',
                    '23514',
                    'classrooms_number_check'
                ),

                -- DB-06. Нарушение NOT NULL
                (
                    'DB-06',
                    'INSERT INTO schedule.classrooms
                    (number, capacity) VALUES (NULL, 30)',
                    '23502',
                    NULL
                ),

                -- DB-07. Повторение первичного ключа
                (
                    'DB-07',
                    format(
                        'INSERT INTO schedule.classrooms
                        (id, number, capacity)
                        VALUES (%s, %L, 40)',
                        v_classroom_id,
                        v_prefix || '-07'
                    ),
                    '23505',
                    'classrooms_pkey'
                ),

                -- DB-08. Нарушение UNIQUE
                (
                    'DB-08',
                    format(
                        'INSERT INTO schedule.classrooms
                        (number, capacity) VALUES (%L, 40)',
                        v_prefix || '-01'
                    ),
                    '23505',
                    'classrooms_number_key'
                ),

                -- DB-10. Несуществующий внешний ключ
                (
                    'DB-10',
                    'INSERT INTO schedule.study_groups
                    (program_id, name, study_form)
                    VALUES (-1, ''TEST-INVALID'', ''FULL_TIME'')',
                    '23503',
                    'study_groups_program_id_fkey'
                ),

                -- DB-11. Проверка ON DELETE RESTRICT
                (
                    'DB-11',
                    format(
                        'DELETE FROM schedule.educational_programs
                        WHERE id = %s',
                        v_program_id
                    ),
                    CASE
                        WHEN current_setting('server_version_num')::INTEGER >= 180000
                        THEN '23001'
                        ELSE '23503'
                    END,
                    'study_groups_program_id_fkey'
                )

            ) AS tests (
                test_id,
                sql_query,
                expected_state,
                expected_constraint
            )
        LOOP
            BEGIN
                EXECUTE v_test.sql_query;

                RAISE EXCEPTION
                    '%: тест не пройден. Запрос выполнен',
                    v_test.test_id;

            EXCEPTION
                WHEN OTHERS THEN

                    GET STACKED DIAGNOSTICS
                        v_state = RETURNED_SQLSTATE,
                        v_constraint = CONSTRAINT_NAME;

                    IF v_state IS DISTINCT FROM
                        v_test.expected_state
                        OR (
                            v_test.expected_constraint IS NOT NULL
                            AND v_constraint IS DISTINCT FROM
                                v_test.expected_constraint
                        )
                    THEN
                        RAISE EXCEPTION '%: тест не пройден. SQLSTATE: %, ограничение: %, ожидалось: % / %',
                            v_test.test_id, v_state, v_constraint,
                            v_test.expected_state, v_test.expected_constraint;
                    END IF;

                    v_passed := v_passed + 1;
                    RAISE NOTICE
                        '%: тест пройден. SQLSTATE: %',
                        v_test.test_id,
                        v_state;
            END;
        END LOOP;

        -- ==========================================
        -- Удаление временных тестовых данных
        -- ==========================================

        DELETE FROM schedule.study_groups
        WHERE id = v_group_id;

        DELETE FROM schedule.educational_programs
        WHERE id = v_program_id;

        DELETE FROM schedule.classrooms
        WHERE id IN (v_classroom_id, v_null_classroom_id);

        -- ==========================================
        -- Итог тестирования
        -- ==========================================

        RAISE NOTICE 'Все 11 тестов успешно пройдены';
        RAISE NOTICE 'Тестовые данные удалены';

    END;

    -- Учебные периоды: DB-12 — DB-18
    DECLARE
        v_year INTEGER;
        v_year_id INTEGER;
        v_semester_id INTEGER;
        v_week_id INTEGER;
        v_test RECORD;
        v_constraint TEXT;
    BEGIN
        -- Выбираем свободный тестовый учебный год
        SELECT y INTO v_year
        FROM generate_series(8000, 8998) AS years(y)
        WHERE NOT EXISTS (
            SELECT 1
            FROM schedule.academic_years
            WHERE name = y::TEXT || '/' || (y + 1)::TEXT
        )
        ORDER BY y
        LIMIT 1;

        IF v_year IS NULL THEN
            RAISE EXCEPTION 'Нет свободного тестового года';
        END IF;

        -- DB-12. Создание корректных учебных периодов

        INSERT INTO schedule.academic_years (
            name, start_date, end_date
        )
        VALUES (
            v_year::TEXT || '/' || (v_year + 1)::TEXT,
            make_date(v_year, 9, 1),
            make_date(v_year + 1, 8, 31)
        )
        RETURNING id INTO v_year_id;

        INSERT INTO schedule.semesters (
            academic_year_id, number,
            start_date, end_date
        )
        VALUES (
            v_year_id, 1,
            make_date(v_year, 9, 1),
            make_date(v_year, 12, 31)
        )
        RETURNING id INTO v_semester_id;

        INSERT INTO schedule.academic_weeks (
            semester_id, number,
            start_date, end_date
        )
        VALUES (
            v_semester_id, 1,
            make_date(v_year, 9, 1),
            make_date(v_year, 9, 7)
        )
        RETURNING id INTO v_week_id;

        v_passed := v_passed + 1;

        RAISE NOTICE 'DB-12: тест пройден';

        -- Отрицательные тестовые сценарии

        FOR v_test IN
            SELECT *
            FROM (VALUES

                (
                    'DB-13',
                    format(
                        'UPDATE schedule.academic_years
                         SET start_date = end_date + 1
                         WHERE id = %s', v_year_id
                    ),
                    'academic_years_dates_check'
                ),

                (
                    'DB-14',
                    format(
                        'UPDATE schedule.academic_years
                         SET name = %L
                         WHERE id = %s',
                        'INVALID', v_year_id
                    ),
                    'academic_years_name_check'
                ),

                (
                    'DB-15',
                    format(
                        'UPDATE schedule.semesters
                         SET number = 0
                         WHERE id = %s', v_semester_id
                    ),
                    'semesters_number_check'
                ),

                (
                    'DB-16',
                    format(
                        'UPDATE schedule.semesters
                         SET start_date = end_date + 1
                         WHERE id = %s', v_semester_id
                    ),
                    'semesters_dates_check'
                ),

                (
                    'DB-17',
                    format(
                        'UPDATE schedule.academic_weeks
                         SET number = -1
                         WHERE id = %s', v_week_id
                    ),
                    'academic_weeks_number_check'
                ),

                (
                    'DB-18',
                    format(
                        'UPDATE schedule.academic_weeks
                         SET start_date = end_date + 1
                         WHERE id = %s', v_week_id
                    ),
                    'academic_weeks_dates_check'
                )

            ) AS tests (
                test_id,
                sql_query,
                expected_constraint
            )
        LOOP
            BEGIN
                EXECUTE v_test.sql_query;

                RAISE EXCEPTION
                    '%: тест не пройден',
                    v_test.test_id;

            EXCEPTION
                WHEN check_violation THEN

                    GET STACKED DIAGNOSTICS
                        v_constraint = CONSTRAINT_NAME;

                    IF v_constraint IS DISTINCT FROM
                        v_test.expected_constraint
                    THEN
                        RAISE EXCEPTION '%: тест не пройден. Ограничение: %, ожидалось: %',
                            v_test.test_id, v_constraint, v_test.expected_constraint;
                    END IF;

                    v_passed := v_passed + 1;
                    RAISE NOTICE
                        '%: тест пройден. SQLSTATE: 23514',
                        v_test.test_id;
            END;
        END LOOP;

        -- Удаление временных тестовых данных

        DELETE FROM schedule.academic_weeks
        WHERE id = v_week_id;

        DELETE FROM schedule.semesters
        WHERE id = v_semester_id;

        DELETE FROM schedule.academic_years
        WHERE id = v_year_id;

        RAISE NOTICE 'Все 7 тестов учебных периодов пройдены';
        RAISE NOTICE 'Тестовые данные удалены';

    END;

    -- Занятия и версионность: DB-19 — DB-30
    DECLARE
        v_year INTEGER;
        v_year_id INTEGER;
        v_semester_id INTEGER;
        v_week_id INTEGER;
        v_program_id INTEGER;
        v_group_id INTEGER;
        v_group_year_id INTEGER;
        v_teacher_id INTEGER;
        v_discipline_id INTEGER;
        v_published_id INTEGER;
        v_draft_id INTEGER;
        v_lesson_id INTEGER;

        v_prefix TEXT := 'TEST-' || txid_current();
        v_test RECORD;
        v_state TEXT;
        v_constraint TEXT;
    BEGIN
        -- ==========================================
        -- Подготовка тестовых учебных периодов
        -- ==========================================

        SELECT y INTO v_year
        FROM generate_series(8000, 8998) AS years(y)
        WHERE NOT EXISTS (
            SELECT 1
            FROM schedule.academic_years
            WHERE name = y::TEXT || '/' || (y + 1)::TEXT
        )
        ORDER BY y
        LIMIT 1;

        IF v_year IS NULL THEN
            RAISE EXCEPTION 'Нет свободного тестового года';
        END IF;

        INSERT INTO schedule.academic_years (
            name, start_date, end_date
        )
        VALUES (
            v_year::TEXT || '/' || (v_year + 1)::TEXT,
            make_date(v_year, 9, 1),
            make_date(v_year + 1, 8, 31)
        )
        RETURNING id INTO v_year_id;

        INSERT INTO schedule.semesters (
            academic_year_id, number, start_date, end_date
        )
        VALUES (
            v_year_id, 1,
            make_date(v_year, 9, 1),
            make_date(v_year, 12, 31)
        )
        RETURNING id INTO v_semester_id;

        INSERT INTO schedule.academic_weeks (
            semester_id, number, start_date, end_date
        )
        VALUES (
            v_semester_id, 1,
            make_date(v_year, 9, 1),
            make_date(v_year, 9, 7)
        )
        RETURNING id INTO v_week_id;

        -- ==========================================
        -- Подготовка учебных ресурсов
        -- ==========================================

        INSERT INTO schedule.educational_programs (name)
        VALUES (v_prefix || '-PROGRAM')
        RETURNING id INTO v_program_id;

        INSERT INTO schedule.study_groups (
            program_id, name, study_form
        )
        VALUES (
            v_program_id,
            v_prefix || '-GROUP',
            'FULL_TIME'
        )
        RETURNING id INTO v_group_id;

        INSERT INTO schedule.group_academic_years (
            study_group_id, academic_year_id, course
        )
        VALUES (v_group_id, v_year_id, 1)
        RETURNING id INTO v_group_year_id;

        INSERT INTO schedule.teachers (
            last_name, first_name
        )
        VALUES ('Тестовый', 'Преподаватель')
        RETURNING id INTO v_teacher_id;

        INSERT INTO schedule.disciplines (name)
        VALUES (v_prefix || '-DISCIPLINE')
        RETURNING id INTO v_discipline_id;

        -- ==========================================
        -- DB-19. Создание корректного расписания
        -- ==========================================

        INSERT INTO schedule.schedules (
            academic_week_id, version,
            status, published_at
        )
        VALUES (
            v_week_id, 1,
            'PUBLISHED', CURRENT_TIMESTAMP
        )
        RETURNING id INTO v_published_id;

        INSERT INTO schedule.schedules (
            academic_week_id, version
        )
        VALUES (v_week_id, 2)
        RETURNING id INTO v_draft_id;

        INSERT INTO schedule.lessons (
            schedule_id,
            group_academic_year_id,
            teacher_id,
            discipline_id,
            lesson_date,
            start_time,
            end_time,
            lesson_type
        )
        VALUES (
            v_draft_id,
            v_group_year_id,
            v_teacher_id,
            v_discipline_id,
            make_date(v_year, 9, 1),
            '09:00',
            '10:30',
            'LECTURE'
        )
        RETURNING id INTO v_lesson_id;

        v_passed := v_passed + 1;

        RAISE NOTICE 'DB-19: тест пройден';

        -- ==========================================
        -- Отрицательные тестовые сценарии
        -- ==========================================

        FOR v_test IN
            SELECT *
            FROM (VALUES

                -- DB-20. Нулевой номер курса
                (
                    'DB-20',
                    format(
                        'UPDATE schedule.group_academic_years
                         SET course = 0 WHERE id = %s',
                        v_group_year_id
                    ),
                    '23514',
                    'group_academic_years_course_check'
                ),

                -- DB-21. Нулевая продолжительность
                (
                    'DB-21',
                    format(
                        'UPDATE schedule.lessons
                         SET end_time = start_time
                         WHERE id = %s', v_lesson_id
                    ),
                    '23514',
                    'lessons_time_check'
                ),

                -- DB-22. Некорректный интервал
                (
                    'DB-22',
                    format(
                        'UPDATE schedule.lessons
                         SET end_time = %L WHERE id = %s',
                        '08:00', v_lesson_id
                    ),
                    '23514',
                    'lessons_time_check'
                ),

                -- DB-23. Нулевой номер версии
                (
                    'DB-23',
                    format(
                        'UPDATE schedule.schedules
                         SET version = 0 WHERE id = %s',
                        v_draft_id
                    ),
                    '23514',
                    'schedules_version_check'
                ),

                -- DB-24. Черновик с датой публикации
                (
                    'DB-24',
                    format(
                        'UPDATE schedule.schedules
                         SET published_at = created_at
                         WHERE id = %s', v_draft_id
                    ),
                    '23514',
                    'schedules_status_publication_check'
                ),

                -- DB-25. Публикация без даты
                (
                    'DB-25',
                    format(
                        'UPDATE schedule.schedules
                         SET status = %L WHERE id = %s',
                        'PUBLISHED', v_draft_id
                    ),
                    '23514',
                    'schedules_status_publication_check'
                ),

                -- DB-26. Архивирование без даты публикации
                (
                    'DB-26',
                    format(
                        'UPDATE schedule.schedules
                         SET status = %L WHERE id = %s',
                        'ARCHIVED', v_draft_id
                    ),
                    '23514',
                    'schedules_status_publication_check'
                ),

                -- DB-27. Некорректная дата публикации
                (
                    'DB-27',
                    format(
                        'UPDATE schedule.schedules
                         SET published_at =
                             created_at - INTERVAL ''1 day''
                         WHERE id = %s', v_published_id
                    ),
                    '23514',
                    'schedules_publication_date_check'
                ),

                -- DB-28. Дублирование номера версии
                (
                    'DB-28',
                    format(
                        'INSERT INTO schedule.schedules
                         (academic_week_id, version)
                         VALUES (%s, 2)', v_week_id
                    ),
                    '23505',
                    'schedules_academic_week_id_version_key'
                ),

                -- DB-29. Две опубликованные версии
                (
                    'DB-29',
                    format(
                        'UPDATE schedule.schedules
                         SET status = %L,
                             published_at = created_at
                         WHERE id = %s',
                        'PUBLISHED', v_draft_id
                    ),
                    '23505',
                    'uq_schedules_published_week'
                )

            ) AS tests (
                test_id,
                sql_query,
                expected_state,
                expected_constraint
            )
        LOOP
            BEGIN
                EXECUTE v_test.sql_query;

                RAISE EXCEPTION
                    '%: тест не пройден',
                    v_test.test_id;

            EXCEPTION
                WHEN OTHERS THEN

                    GET STACKED DIAGNOSTICS
                        v_state = RETURNED_SQLSTATE,
                        v_constraint = CONSTRAINT_NAME;

                    IF v_state IS DISTINCT FROM
                        v_test.expected_state
                        OR v_constraint IS DISTINCT FROM
                            v_test.expected_constraint
                    THEN
                        RAISE EXCEPTION '%: тест не пройден. SQLSTATE: %, ограничение: %, ожидалось: % / %',
                            v_test.test_id, v_state, v_constraint,
                            v_test.expected_state, v_test.expected_constraint;
                    END IF;

                    v_passed := v_passed + 1;
                    RAISE NOTICE
                        '%: тест пройден. SQLSTATE: %',
                        v_test.test_id,
                        v_state;
            END;
        END LOOP;

        -- ==========================================
        -- DB-30. Замена опубликованной версии
        -- ==========================================

        UPDATE schedule.schedules
        SET status = 'ARCHIVED'
        WHERE id = v_published_id;

        UPDATE schedule.schedules
        SET status = 'PUBLISHED',
            published_at = CURRENT_TIMESTAMP
        WHERE id = v_draft_id;

        IF NOT EXISTS (
            SELECT 1
            FROM schedule.schedules
            WHERE id = v_published_id
              AND status = 'ARCHIVED'
        )
        OR NOT EXISTS (
            SELECT 1
            FROM schedule.schedules
            WHERE id = v_draft_id
              AND status = 'PUBLISHED'
        )
        OR (
            SELECT COUNT(*)
            FROM schedule.schedules
            WHERE academic_week_id = v_week_id
              AND status = 'PUBLISHED'
        ) <> 1 THEN
            RAISE EXCEPTION 'DB-30: тест не пройден';
        END IF;

        v_passed := v_passed + 1;

        RAISE NOTICE 'DB-30: тест пройден';

        -- ==========================================
        -- Удаление временных тестовых данных
        -- ==========================================

        DELETE FROM schedule.lessons
        WHERE id = v_lesson_id;

        DELETE FROM schedule.schedules
        WHERE id IN (v_published_id, v_draft_id);

        DELETE FROM schedule.group_academic_years
        WHERE id = v_group_year_id;

        DELETE FROM schedule.study_groups
        WHERE id = v_group_id;

        DELETE FROM schedule.educational_programs
        WHERE id = v_program_id;

        DELETE FROM schedule.teachers
        WHERE id = v_teacher_id;

        DELETE FROM schedule.disciplines
        WHERE id = v_discipline_id;

        DELETE FROM schedule.academic_weeks
        WHERE id = v_week_id;

        DELETE FROM schedule.semesters
        WHERE id = v_semester_id;

        DELETE FROM schedule.academic_years
        WHERE id = v_year_id;

        RAISE NOTICE 'Все 12 тестов успешно пройдены';
        RAISE NOTICE 'Тестовые данные удалены';

    END;

    IF v_passed <> 30 THEN
        RAISE EXCEPTION 'Неполный набор тестов: % из 30', v_passed;
    END IF;

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'ИТОГ: % из 30 тестов успешно пройдены', v_passed;
    RAISE NOTICE 'Тестовые данные удалены';
    RAISE NOTICE '==========================================';
END;
$tests$;
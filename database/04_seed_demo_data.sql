-- ==================================================
-- EDS Schedule
-- Наполнение базы демонстрационными данными
-- PostgreSQL: eds_schedule
-- Схема: schedule
--
-- Данные являются демонстрационными.
-- Повторный запуск не дублирует записи.
-- ==================================================

DO $$
DECLARE
    v_year_id INTEGER;
    v_semester_id INTEGER;
    v_id INTEGER;
    v_schedule_id INTEGER;

    v_week_ids INTEGER[] := '{}';
    v_program_ids INTEGER[] := '{}';
    v_group_ids INTEGER[] := '{}';
    v_group_year_ids INTEGER[] := '{}';
    v_subgroup_ids INTEGER[] := '{}';
    v_teacher_ids INTEGER[] := '{}';
    v_discipline_ids INTEGER[] := '{}';
    v_classroom_ids INTEGER[] := '{}';

    v_week_start DATE;
    v_name TEXT;
    v_i INTEGER;
    v_row RECORD;
    v_lesson_count INTEGER := 0;

BEGIN

    -- ==========================================
    -- 1. Проверка подключения
    -- ==========================================

    IF current_database() <> 'eds_schedule' THEN
        RAISE EXCEPTION 'Выбрана неверная база данных';
    END IF;

    -- Защита от повторного наполнения

    IF EXISTS (
        SELECT 1
        FROM schedule.educational_programs
        WHERE name IN (
            'ДЕМО — Богословие',
            'ДЕМО — Церковно-практические дисциплины'
        )
    ) THEN
        RAISE NOTICE
            'Демонстрационные данные уже обнаружены. Повторное наполнение пропущено';
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM schedule.academic_years
        WHERE name = '2026/2027'
    ) THEN
        RAISE EXCEPTION
            'Учебный год 2026/2027 уже существует. Требуется проверка данных';
    END IF;

    RAISE NOTICE 'Начало наполнения базы данных';

    -- ==========================================
    -- 2. Учебный год
    -- ==========================================

    INSERT INTO schedule.academic_years (
        name, start_date, end_date
    )
    VALUES (
        '2026/2027',
        '2026-09-01',
        '2027-08-31'
    )
    RETURNING id INTO v_year_id;

    RAISE NOTICE 'Создан учебный год';

    -- ==========================================
    -- 3. Семестры
    -- ==========================================

    INSERT INTO schedule.semesters (
        academic_year_id,
        number,
        start_date,
        end_date
    )
    VALUES (
        v_year_id,
        1,
        '2026-09-01',
        '2027-01-31'
    )
    RETURNING id INTO v_semester_id;

    INSERT INTO schedule.semesters (
        academic_year_id,
        number,
        start_date,
        end_date
    )
    VALUES (
        v_year_id,
        2,
        '2027-02-01',
        '2027-08-31'
    );

    RAISE NOTICE 'Созданы 2 семестра';

    -- ==========================================
    -- 4. Учебные недели
    -- ==========================================

    FOR v_i IN 1..4 LOOP

        v_week_start :=
            DATE '2026-11-23' + (v_i - 1) * 7;

        INSERT INTO schedule.academic_weeks (
            semester_id,
            number,
            start_date,
            end_date
        )
        VALUES (
            v_semester_id,
            12 + v_i,
            v_week_start,
            v_week_start + 6
        )
        RETURNING id INTO v_id;

        v_week_ids := array_append(v_week_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 4 учебные недели';

    -- ==========================================
    -- 5. Образовательные программы
    -- ==========================================

    FOREACH v_name IN ARRAY ARRAY[
        'ДЕМО — Богословие',
        'ДЕМО — Церковно-практические дисциплины'
    ]
    LOOP

        INSERT INTO schedule.educational_programs (name)
        VALUES (v_name)
        RETURNING id INTO v_id;

        v_program_ids :=
            array_append(v_program_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 2 образовательные программы';

    -- ==========================================
    -- 6. Учебные группы
    -- ==========================================

    FOR v_row IN
        SELECT *
        FROM (VALUES
            (1, 'ДЕМО-Б1', 'FULL_TIME', 1),
            (1, 'ДЕМО-Б2', 'FULL_TIME', 2),
            (2, 'ДЕМО-Ц1', 'FULL_TIME', 1),
            (2, 'ДЕМО-Ц2', 'PART_TIME', 2)
        ) AS groups (
            program_no,
            group_name,
            study_form,
            course
        )
    LOOP

        INSERT INTO schedule.study_groups (
            program_id,
            name,
            study_form
        )
        VALUES (
            v_program_ids[v_row.program_no],
            v_row.group_name,
            v_row.study_form::schedule."StudyForm"
        )
        RETURNING id INTO v_id;

        v_group_ids :=
            array_append(v_group_ids, v_id);

        INSERT INTO schedule.group_academic_years (
            study_group_id,
            academic_year_id,
            course
        )
        VALUES (
            v_id,
            v_year_id,
            v_row.course
        )
        RETURNING id INTO v_id;

        v_group_year_ids :=
            array_append(v_group_year_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 4 учебные группы';
    RAISE NOTICE 'Созданы 4 привязки к учебному году';

    -- ==========================================
    -- 7. Учебные подгруппы
    -- ==========================================

    FOREACH v_name IN ARRAY ARRAY[
        'Подгруппа 1',
        'Подгруппа 2'
    ]
    LOOP

        INSERT INTO schedule.subgroups (
            study_group_id,
            name
        )
        VALUES (
            v_group_ids[1],
            v_name
        )
        RETURNING id INTO v_id;

        v_subgroup_ids :=
            array_append(v_subgroup_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 2 учебные подгруппы';

    -- ==========================================
    -- 8. Преподаватели
    -- Все имена условные
    -- ==========================================

    FOR v_row IN
        SELECT *
        FROM (VALUES
            ('Иванов', 'Александр', 'Сергеевич'),
            ('Петров', 'Михаил', 'Андреевич'),
            ('Смирнова', 'Елена', 'Викторовна'),
            ('Васильев', 'Павел', 'Николаевич'),
            ('Соколов', 'Дмитрий', 'Олегович'),
            ('Кузнецова', 'Анна', 'Игоревна')
        ) AS teachers (
            last_name,
            first_name,
            middle_name
        )
    LOOP

        INSERT INTO schedule.teachers (
            last_name,
            first_name,
            middle_name
        )
        VALUES (
            v_row.last_name,
            v_row.first_name,
            v_row.middle_name
        )
        RETURNING id INTO v_id;

        v_teacher_ids :=
            array_append(v_teacher_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 6 преподавателей';

    -- ==========================================
    -- 9. Учебные дисциплины
    -- ==========================================

    FOREACH v_name IN ARRAY ARRAY[
        'Церковнославянский язык',
        'Священное Писание Ветхого Завета',
        'Священное Писание Нового Завета',
        'История Русской Православной Церкви',
        'Догматическое богословие',
        'Литургика',
        'Патрология',
        'Церковное пение'
    ]
    LOOP

        INSERT INTO schedule.disciplines (name)
        VALUES (v_name)
        RETURNING id INTO v_id;

        v_discipline_ids :=
            array_append(v_discipline_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 8 дисциплин';

    -- ==========================================
    -- 10. Учебные аудитории
    -- ==========================================

    FOR v_row IN
        SELECT *
        FROM (VALUES
            ('ДЕМО-101', 'Учебная аудитория', 30),
            ('ДЕМО-102', 'Учебная аудитория', 25),
            ('ДЕМО-201', 'Лекционная аудитория', 40),
            ('ДЕМО-202', 'Учебная аудитория', 20),
            ('ДЕМО-203', 'Аудитория церковного пения', 25)
        ) AS classrooms (
            room_number,
            room_name,
            capacity
        )
    LOOP

        INSERT INTO schedule.classrooms (
            number,
            name,
            capacity
        )
        VALUES (
            v_row.room_number,
            v_row.room_name,
            v_row.capacity
        )
        RETURNING id INTO v_id;

        v_classroom_ids :=
            array_append(v_classroom_ids, v_id);

    END LOOP;

    RAISE NOTICE 'Созданы 5 аудиторий';

    -- ==========================================
    -- 11. Расписания и учебные занятия
    -- ==========================================

    FOR v_i IN 1..2 LOOP

        v_week_start :=
            DATE '2026-11-23' + (v_i - 1) * 7;

        -- Первая неделя опубликована.
        -- Вторая неделя является черновиком.

        IF v_i = 1 THEN

            INSERT INTO schedule.schedules (
                academic_week_id,
                version,
                status,
                published_at
            )
            VALUES (
                v_week_ids[v_i],
                1,
                'PUBLISHED',
                CURRENT_TIMESTAMP
            )
            RETURNING id INTO v_schedule_id;

        ELSE

            INSERT INTO schedule.schedules (
                academic_week_id,
                version,
                status
            )
            VALUES (
                v_week_ids[v_i],
                1,
                'DRAFT'
            )
            RETURNING id INTO v_schedule_id;

        END IF;

        -- Шаблон занятий одной учебной недели:
        -- день, группа, подгруппа, преподаватель,
        -- дисциплина, аудитория, начало, конец, тип.
        --
        -- 0 — понедельник.
        -- 4 — пятница.
        -- NULL — занятие для всей группы.

        FOR v_row IN
            SELECT *
            FROM (VALUES

                -- Понедельник
                (0, 1, 1, 1, 1, 1,
                 '09:00', '10:30', 'PRACTICAL'),

                (0, 1, 2, 6, 8, 5,
                 '09:00', '10:30', 'PRACTICAL'),

                (0, 2, NULL, 2, 2, 3,
                 '10:45', '12:15', 'LECTURE'),

                -- Вторник
                (1, 1, NULL, 3, 3, 1,
                 '09:00', '10:30', 'LECTURE'),

                (1, 3, NULL, 4, 6, 2,
                 '09:00', '10:30', 'SEMINAR'),

                (1, 2, NULL, 5, 5, 3,
                 '10:45', '12:15', 'LECTURE'),

                -- Среда
                (2, 2, NULL, 4, 4, 3,
                 '09:00', '10:30', 'LECTURE'),

                (2, 1, NULL, 1, 1, 1,
                 '10:45', '12:15', 'SEMINAR'),

                (2, 4, NULL, 6, 8, 5,
                 '13:00', '14:30', 'PRACTICAL'),

                -- Четверг
                (3, 3, NULL, 5, 7, 2,
                 '09:00', '10:30', 'LECTURE'),

                (3, 2, NULL, 3, 3, 3,
                 '10:45', '12:15', 'SEMINAR'),

                (3, 4, NULL, 4, 6, 4,
                 '13:00', '14:30', 'LECTURE'),

                -- Пятница
                (4, 1, NULL, 2, 2, 1,
                 '09:00', '10:30', 'SEMINAR'),

                (4, 3, NULL, 6, 8, 5,
                 '10:45', '12:15', 'PRACTICAL'),

                (4, 4, NULL, 5, 5, 4,
                 '13:00', '14:30', 'CONSULTATION')

            ) AS template (
                day_offset,
                group_no,
                subgroup_no,
                teacher_no,
                discipline_no,
                classroom_no,
                time_start,
                time_end,
                lesson_type
            )
        LOOP

            INSERT INTO schedule.lessons (
                schedule_id,
                group_academic_year_id,
                subgroup_id,
                teacher_id,
                discipline_id,
                classroom_id,
                lesson_date,
                start_time,
                end_time,
                lesson_type
            )
            VALUES (
                v_schedule_id,
                v_group_year_ids[v_row.group_no],

                CASE
                    WHEN v_row.subgroup_no IS NULL
                    THEN NULL
                    ELSE v_subgroup_ids[v_row.subgroup_no]
                END,

                v_teacher_ids[v_row.teacher_no],
                v_discipline_ids[v_row.discipline_no],
                v_classroom_ids[v_row.classroom_no],

                v_week_start + v_row.day_offset,

                v_row.time_start::TIME,
                v_row.time_end::TIME,

                v_row.lesson_type::schedule."LessonType"
            );

            v_lesson_count := v_lesson_count + 1;

        END LOOP;

    END LOOP;

    -- ==========================================
    -- 12. Проверка результата
    -- ==========================================

    IF v_lesson_count <> 30 THEN
        RAISE EXCEPTION
            'Некорректное количество созданных занятий';
    END IF;

    RAISE NOTICE 'Созданы 2 версии расписания';
    RAISE NOTICE 'Созданы % учебных занятий',
        v_lesson_count;

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Демонстрационные данные успешно добавлены';
    RAISE NOTICE 'Опубликованных расписаний: 1';
    RAISE NOTICE 'Черновиков расписания: 1';
    RAISE NOTICE 'Свободных учебных недель: 2';
    RAISE NOTICE 'Учебных занятий: 30';
    RAISE NOTICE '==========================================';

END;
$$;

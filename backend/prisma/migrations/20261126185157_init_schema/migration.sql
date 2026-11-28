
-- ==================================================
-- EDS Schedule
-- Начальная миграция базы данных
-- СУБД: PostgreSQL
-- База данных: eds_schedule
-- Схема: schedule
-- Дата: 26.11.2026
-- ==================================================

-- ==================================================
-- 1. Создание перечислимых типов
-- ==================================================

CREATE TYPE "StudyForm" AS ENUM (
    'FULL_TIME',
    'PART_TIME'
);

CREATE TYPE "LessonType" AS ENUM (
    'LECTURE',
    'SEMINAR',
    'PRACTICAL',
    'CONSULTATION',
    'EXAM',
    'CREDIT'
);

CREATE TYPE "ScheduleStatus" AS ENUM (
    'DRAFT',
    'PUBLISHED',
    'ARCHIVED'
);

CREATE TYPE "Role" AS ENUM (
    'ADMIN'
);

-- ==================================================
-- 2. Организация учебного времени
-- ==================================================

-- Учебные годы
CREATE TABLE "academic_years" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(9) NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,

    CONSTRAINT "academic_years_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "academic_years_dates_check"
        CHECK ("start_date" <= "end_date"),

    CONSTRAINT "academic_years_name_check"
        CHECK ("name" ~ '^[0-9]{4}/[0-9]{4}$')
);

-- Семестры
CREATE TABLE "semesters" (
    "id" SERIAL NOT NULL,
    "academic_year_id" INTEGER NOT NULL,
    "number" INTEGER NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,

    CONSTRAINT "semesters_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "semesters_number_check"
        CHECK ("number" > 0),

    CONSTRAINT "semesters_dates_check"
        CHECK ("start_date" <= "end_date")
);

-- Учебные недели
CREATE TABLE "academic_weeks" (
    "id" SERIAL NOT NULL,
    "semester_id" INTEGER NOT NULL,
    "number" INTEGER NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,

    CONSTRAINT "academic_weeks_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "academic_weeks_number_check"
        CHECK ("number" > 0),

    CONSTRAINT "academic_weeks_dates_check"
        CHECK ("start_date" <= "end_date")
);

-- ==================================================
-- 3. Организация обучения
-- ==================================================

-- Образовательные программы
CREATE TABLE "educational_programs" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(255) NOT NULL,

    CONSTRAINT "educational_programs_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "educational_programs_name_check"
        CHECK ("name" ~ '[^[:space:]]')
);

-- Учебные группы
CREATE TABLE "study_groups" (
    "id" SERIAL NOT NULL,
    "program_id" INTEGER NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "study_form" "StudyForm" NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "study_groups_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "study_groups_name_check"
        CHECK ("name" ~ '[^[:space:]]')
);

-- Учебные подгруппы
CREATE TABLE "subgroups" (
    "id" SERIAL NOT NULL,
    "study_group_id" INTEGER NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "subgroups_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "subgroups_name_check"
        CHECK ("name" ~ '[^[:space:]]')
);

-- История обучения групп по учебным годам
CREATE TABLE "group_academic_years" (
    "id" SERIAL NOT NULL,
    "study_group_id" INTEGER NOT NULL,
    "academic_year_id" INTEGER NOT NULL,
    "course" INTEGER NOT NULL,

    CONSTRAINT "group_academic_years_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "group_academic_years_course_check"
        CHECK ("course" > 0)
);

-- ==================================================
-- 4. Учебные ресурсы
-- ==================================================

-- Преподаватели
CREATE TABLE "teachers" (
    "id" SERIAL NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "first_name" VARCHAR(100) NOT NULL,
    "middle_name" VARCHAR(100),
    "title" VARCHAR(150),
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "teachers_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "teachers_last_name_check"
        CHECK ("last_name" ~ '[^[:space:]]'),

    CONSTRAINT "teachers_first_name_check"
        CHECK ("first_name" ~ '[^[:space:]]')
);

-- Учебные дисциплины
CREATE TABLE "disciplines" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "short_name" VARCHAR(100),
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "disciplines_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "disciplines_name_check"
        CHECK ("name" ~ '[^[:space:]]')
);

-- Учебные аудитории
CREATE TABLE "classrooms" (
    "id" SERIAL NOT NULL,
    "number" VARCHAR(30) NOT NULL,
    "name" VARCHAR(150),
    "capacity" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "classrooms_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "classrooms_number_check"
        CHECK ("number" ~ '[^[:space:]]'),

    CONSTRAINT "classrooms_capacity_check"
        CHECK ("capacity" > 0)
);

-- ==================================================
-- 5. Управление расписанием
-- ==================================================

-- Версии расписания
CREATE TABLE "schedules" (
    "id" SERIAL NOT NULL,
    "academic_week_id" INTEGER NOT NULL,
    "version" INTEGER NOT NULL,
    "status" "ScheduleStatus" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(6) NOT NULL
        DEFAULT CURRENT_TIMESTAMP,
    "published_at" TIMESTAMPTZ(6),

    CONSTRAINT "schedules_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "schedules_version_check"
        CHECK ("version" > 0),

    CONSTRAINT "schedules_status_publication_check"
        CHECK (
            (
                "status" = 'DRAFT'
                AND "published_at" IS NULL
            )
            OR
            (
                "status" IN ('PUBLISHED', 'ARCHIVED')
                AND "published_at" IS NOT NULL
            )
        ),

    CONSTRAINT "schedules_publication_date_check"
        CHECK (
            "published_at" IS NULL
            OR "published_at" >= "created_at"
        )
);

-- Учебные занятия
CREATE TABLE "lessons" (
    "id" SERIAL NOT NULL,
    "schedule_id" INTEGER NOT NULL,
    "group_academic_year_id" INTEGER NOT NULL,
    "subgroup_id" INTEGER,
    "teacher_id" INTEGER NOT NULL,
    "discipline_id" INTEGER NOT NULL,
    "classroom_id" INTEGER,
    "lesson_date" DATE NOT NULL,
    "start_time" TIME(0) NOT NULL,
    "end_time" TIME(0) NOT NULL,
    "lesson_type" "LessonType" NOT NULL,

    CONSTRAINT "lessons_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "lessons_time_check"
        CHECK ("start_time" < "end_time")
);

-- ==================================================
-- 6. Управление доступом
-- ==================================================

-- Учётные записи администраторов
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "username" VARCHAR(100) NOT NULL,
    "password_hash" TEXT NOT NULL,
    "full_name" VARCHAR(255) NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'ADMIN',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey"
        PRIMARY KEY ("id"),

    CONSTRAINT "users_username_check"
        CHECK ("username" ~ '[^[:space:]]'),

    CONSTRAINT "users_password_hash_check"
        CHECK ("password_hash" ~ '[^[:space:]]'),

    CONSTRAINT "users_full_name_check"
        CHECK ("full_name" ~ '[^[:space:]]')
);

-- ==================================================
-- 7. Уникальные индексы
-- ==================================================

CREATE UNIQUE INDEX "academic_years_name_key"
ON "academic_years" ("name");

CREATE UNIQUE INDEX "semesters_academic_year_id_number_key"
ON "semesters" ("academic_year_id", "number");

CREATE UNIQUE INDEX "academic_weeks_semester_id_number_key"
ON "academic_weeks" ("semester_id", "number");

CREATE UNIQUE INDEX "educational_programs_name_key"
ON "educational_programs" ("name");

CREATE UNIQUE INDEX "subgroups_study_group_id_name_key"
ON "subgroups" ("study_group_id", "name");

CREATE UNIQUE INDEX "group_academic_years_study_group_id_academic_year_id_key"
ON "group_academic_years" ("study_group_id", "academic_year_id");

CREATE UNIQUE INDEX "disciplines_name_key"
ON "disciplines" ("name");

CREATE UNIQUE INDEX "classrooms_number_key"
ON "classrooms" ("number");

CREATE UNIQUE INDEX "schedules_academic_week_id_version_key"
ON "schedules" ("academic_week_id", "version");

CREATE UNIQUE INDEX "users_username_key"
ON "users" ("username");

-- Только одна опубликованная версия расписания
-- для каждой учебной недели

CREATE UNIQUE INDEX "uq_schedules_published_week"
ON "schedules" ("academic_week_id")
WHERE "status" = 'PUBLISHED';

-- ==================================================
-- 8. Внешние ключи
-- ==================================================

-- Учебные периоды

ALTER TABLE "semesters"
ADD CONSTRAINT "semesters_academic_year_id_fkey"
FOREIGN KEY ("academic_year_id")
REFERENCES "academic_years" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "academic_weeks"
ADD CONSTRAINT "academic_weeks_semester_id_fkey"
FOREIGN KEY ("semester_id")
REFERENCES "semesters" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- Организация обучения

ALTER TABLE "study_groups"
ADD CONSTRAINT "study_groups_program_id_fkey"
FOREIGN KEY ("program_id")
REFERENCES "educational_programs" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "subgroups"
ADD CONSTRAINT "subgroups_study_group_id_fkey"
FOREIGN KEY ("study_group_id")
REFERENCES "study_groups" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "group_academic_years"
ADD CONSTRAINT "group_academic_years_study_group_id_fkey"
FOREIGN KEY ("study_group_id")
REFERENCES "study_groups" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "group_academic_years"
ADD CONSTRAINT "group_academic_years_academic_year_id_fkey"
FOREIGN KEY ("academic_year_id")
REFERENCES "academic_years" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- Расписание

ALTER TABLE "schedules"
ADD CONSTRAINT "schedules_academic_week_id_fkey"
FOREIGN KEY ("academic_week_id")
REFERENCES "academic_weeks" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- Учебные занятия

ALTER TABLE "lessons"
ADD CONSTRAINT "lessons_schedule_id_fkey"
FOREIGN KEY ("schedule_id")
REFERENCES "schedules" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "lessons"
ADD CONSTRAINT "lessons_group_academic_year_id_fkey"
FOREIGN KEY ("group_academic_year_id")
REFERENCES "group_academic_years" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "lessons"
ADD CONSTRAINT "lessons_subgroup_id_fkey"
FOREIGN KEY ("subgroup_id")
REFERENCES "subgroups" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "lessons"
ADD CONSTRAINT "lessons_teacher_id_fkey"
FOREIGN KEY ("teacher_id")
REFERENCES "teachers" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "lessons"
ADD CONSTRAINT "lessons_discipline_id_fkey"
FOREIGN KEY ("discipline_id")
REFERENCES "disciplines" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "lessons"
ADD CONSTRAINT "lessons_classroom_id_fkey"
FOREIGN KEY ("classroom_id")
REFERENCES "classrooms" ("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- ==================================================
-- Конец начальной миграции
-- ==================================================

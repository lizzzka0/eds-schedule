import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';

import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { Lesson } from '../src/lessons/entities/lesson.entity';

describe('EDS Schedule — интеграционное тестирование', () => {
  let app: INestApplication<App>;
  let prisma: PrismaService;

  // Подготовка приложения перед тестированием
  beforeAll(async () => {
    const moduleFixture: TestingModule =
      await Test.createTestingModule({
        imports: [AppModule],
      }).compile();

    app = moduleFixture.createNestApplication();

    await app.init();

    prisma = app.get(PrismaService);

    // Проверка подключения к нужной базе данных
    const databases = await prisma.$queryRaw<
      { database_name: string }[]
    >`
      SELECT current_database() AS database_name
    `;

    expect(databases[0].database_name).toBe('eds_schedule');
  });

  // Завершение работы приложения после тестирования
  afterAll(async () => {
    if (app) {
      await app.close();
    }
  });

  // Вспомогательный метод получения занятий
  async function getLessons(): Promise<Lesson[]> {
    const response = await request(app.getHttpServer())
      .get('/api/lessons')
      .expect(200);

    return response.body as Lesson[];
  }

  // ==========================================
  // Проверка доступности приложения
  // ==========================================

  it('главная страница API должна быть доступна', async () => {
    await request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect('Hello World!');
  });

  // ==========================================
  // Интеграционные тесты расписания
  // ==========================================

  // INT-01
  it('INT-01: API расписания должен возвращать HTTP 200', async () => {
    await request(app.getHttpServer())
      .get('/api/lessons')
      .expect(200);
  });

  // INT-02
  it('INT-02: API должен возвращать массив занятий', async () => {
    const lessons = await getLessons();

    expect(Array.isArray(lessons)).toBe(true);
  });

  // INT-03
  it('INT-03: опубликованные занятия должны соответствовать данным PostgreSQL', async () => {
    const lessons = await getLessons();

    const publishedLessons = await prisma.$queryRaw<
      { id: number }[]
    >`
      SELECT l.id
      FROM schedule.lessons l
      JOIN schedule.schedules s
        ON s.id = l.schedule_id
      WHERE s.status = 'PUBLISHED'
      ORDER BY l.id
    `;

    expect(publishedLessons).toHaveLength(15);

    expect(lessons).toHaveLength(
      publishedLessons.length,
    );

    const actualIds = lessons
      .map((lesson) => lesson.id)
      .sort((a, b) => a - b);

    const expectedIds = publishedLessons
      .map((lesson) => lesson.id);

    expect(actualIds).toEqual(expectedIds);
  });

  // INT-04
  it('INT-04: занятия из черновиков не должны попадать в публичный API', async () => {
    const lessons = await getLessons();

    const draftLessons = await prisma.$queryRaw<
      { id: number }[]
    >`
      SELECT l.id
      FROM schedule.lessons l
      JOIN schedule.schedules s
        ON s.id = l.schedule_id
      WHERE s.status = 'DRAFT'
    `;

    expect(draftLessons).toHaveLength(15);

    const publishedIds = lessons.map(
      (lesson) => lesson.id,
    );

    for (const draftLesson of draftLessons) {
      expect(publishedIds).not.toContain(
        draftLesson.id,
      );
    }
  });

  // INT-05
  it('INT-05: занятия должны иметь корректную структуру JSON', async () => {
    const lessons = await getLessons();

    expect(lessons.length).toBeGreaterThan(0);

    for (const lesson of lessons) {
      expect(lesson).toEqual(
        expect.objectContaining({
          id: expect.any(Number),
          date: expect.any(String),
          startTime: expect.any(String),
          endTime: expect.any(String),
          discipline: expect.any(String),
          lessonType: expect.any(String),
          teacher: expect.any(String),
          studyGroup: expect.any(String),
          classroom: expect.any(String),
        }),
      );

      expect(lesson.date).toMatch(
        /^\d{4}-\d{2}-\d{2}$/,
      );

      expect(lesson.startTime).toMatch(
        /^([01]\d|2[0-3]):[0-5]\d$/,
      );

      expect(lesson.endTime).toMatch(
        /^([01]\d|2[0-3]):[0-5]\d$/,
      );

      expect(lesson.startTime < lesson.endTime)
        .toBe(true);
    }
  });

  // INT-06
  it('INT-06: занятия должны быть отсортированы по дате и времени', async () => {
    const lessons = await getLessons();

    const sortedLessons = [...lessons].sort((a, b) => {
      return (
        a.date.localeCompare(b.date) ||
        a.startTime.localeCompare(b.startTime) ||
        a.id - b.id
      );
    });

    expect(lessons).toEqual(sortedLessons);
  });

  // INT-07
  it('INT-07: связанные учебные ресурсы должны отображаться корректно', async () => {
    const lessons = await getLessons();

    const lesson = lessons.find(
      (item) =>
        item.date === '2026-11-23' &&
        item.discipline === 'Церковнославянский язык' &&
        item.startTime === '09:00',
    );

    expect(lesson).toBeDefined();

    expect(lesson).toEqual(
      expect.objectContaining({
        discipline: 'Церковнославянский язык',
        teacher: 'Иванов Александр Сергеевич',
        classroom: 'ДЕМО-101',
        studyGroup: 'ДЕМО-Б1 — Подгруппа 1',
        lessonType: 'Практическое занятие',
        startTime: '09:00',
        endTime: '10:30',
      }),
    );
  });

  // INT-08
  it('INT-08: API должен возвращать параллельные занятия разных подгрупп', async () => {
    const lessons = await getLessons();

    const subgroupLessons = lessons.filter(
      (lesson) =>
        lesson.date === '2026-11-23' &&
        lesson.startTime === '09:00' &&
        lesson.studyGroup.startsWith(
          'ДЕМО-Б1 — Подгруппа',
        ),
    );

    expect(subgroupLessons).toHaveLength(2);

    expect(
      subgroupLessons.map(
        (lesson) => lesson.studyGroup,
      ),
    ).toEqual(
      expect.arrayContaining([
        'ДЕМО-Б1 — Подгруппа 1',
        'ДЕМО-Б1 — Подгруппа 2',
      ]),
    );

    expect(
      subgroupLessons[0].teacher,
    ).not.toBe(
      subgroupLessons[1].teacher,
    );

    expect(
      subgroupLessons[0].classroom,
    ).not.toBe(
      subgroupLessons[1].classroom,
    );
  });
});

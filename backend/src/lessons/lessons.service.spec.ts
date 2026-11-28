import { Test, TestingModule } from '@nestjs/testing';
import { jest } from '@jest/globals';
import { LessonsService } from './lessons.service';
import { PrismaService } from '../prisma/prisma.service';
import { Lesson } from './entities/lesson.entity';

describe('LessonsService', () => {
  let service: LessonsService;

  // Имитация записи, полученной из PostgreSQL
  const mockDbLesson = {
    id: 1,
    lessonDate: new Date('2026-11-23T00:00:00.000Z'),
    startTime: new Date('1970-01-01T09:00:00.000Z'),
    endTime: new Date('1970-01-01T10:30:00.000Z'),
    lessonType: 'PRACTICAL',

    discipline: {
      name: 'Церковнославянский язык',
    },

    teacher: {
      lastName: 'Иванов',
      firstName: 'Александр',
      middleName: 'Сергеевич',
    },

    classroom: {
      number: 'ДЕМО-101',
    },

    subgroup: null,

    groupAcademicYear: {
      studyGroup: {
        name: 'ДЕМО-Б1',
      },
    },
  };

  // Имитация PrismaService
  const mockPrismaService = {
    lesson: {
      findMany: jest.fn<
        (query: unknown) => Promise<unknown[]>
      >(),
    },
  };

  beforeEach(async () => {
    mockPrismaService.lesson.findMany.mockReset();

    mockPrismaService.lesson.findMany.mockResolvedValue([
      mockDbLesson,
    ]);

    const module: TestingModule =
      await Test.createTestingModule({
        providers: [
          LessonsService,
          {
            provide: PrismaService,
            useValue: mockPrismaService,
          },
        ],
      }).compile();

    service = module.get<LessonsService>(LessonsService);
  });

  // BE-01
  it('сервис должен быть создан', () => {
    expect(service).toBeDefined();
  });

  // BE-02
  it('должен возвращать список занятий', async () => {
    const result = await service.findAll();

    expect(result).toHaveLength(1);

    expect(
      mockPrismaService.lesson.findMany,
    ).toHaveBeenCalledTimes(1);
  });

  // BE-03
  it('должен запрашивать только опубликованные занятия', async () => {
    await service.findAll();

    expect(
      mockPrismaService.lesson.findMany,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          schedule: {
            status: 'PUBLISHED',
          },
        },
      }),
    );
  });

  // BE-04
  it('должен запрашивать занятия в хронологическом порядке', async () => {
    await service.findAll();

    expect(
      mockPrismaService.lesson.findMany,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        orderBy: [
          { lessonDate: 'asc' },
          { startTime: 'asc' },
          { id: 'asc' },
        ],
      }),
    );
  });

  // BE-05
  it('должен преобразовывать запись БД в объект Lesson', async () => {
    const result = await service.findAll();

    expect(result[0]).toBeInstanceOf(Lesson);

    expect(result[0]).toEqual(
      new Lesson(
        1,
        '2026-11-23',
        '09:00',
        '10:30',
        'Церковнославянский язык',
        'Практическое занятие',
        'Иванов Александр Сергеевич',
        'ДЕМО-Б1',
        'ДЕМО-101',
      ),
    );
  });

  // BE-06
  it('должен отображать название подгруппы', async () => {
    mockPrismaService.lesson.findMany.mockResolvedValueOnce([
      {
        ...mockDbLesson,
        subgroup: {
          name: 'Подгруппа 1',
        },
      },
    ]);

    const result = await service.findAll();

    expect(result[0].studyGroup).toBe(
      'ДЕМО-Б1 — Подгруппа 1',
    );
  });

  // BE-07
  it('должен обрабатывать отсутствие аудитории', async () => {
    mockPrismaService.lesson.findMany.mockResolvedValueOnce([
      {
        ...mockDbLesson,
        classroom: null,
      },
    ]);

    const result = await service.findAll();

    expect(result[0].classroom).toBe('Не назначена');
  });

  // BE-08
  it('должен возвращать пустой массив при отсутствии занятий', async () => {
    mockPrismaService.lesson.findMany.mockResolvedValueOnce([]);

    const result = await service.findAll();

    expect(result).toEqual([]);
  });

  // BE-09
  it('должен передавать ошибку базы данных вызывающему коду', async () => {
    mockPrismaService.lesson.findMany.mockRejectedValueOnce(
      new Error('Ошибка подключения к базе данных'),
    );

    await expect(service.findAll()).rejects.toThrow(
      'Ошибка подключения к базе данных',
    );
  });
});

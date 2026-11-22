import { Test, TestingModule } from '@nestjs/testing';
import { jest } from '@jest/globals';
import { LessonsController } from './lessons.controller';
import { LessonsService } from './lessons.service';
import { Lesson } from './entities/lesson.entity';

describe('LessonsController', () => {
  let controller: LessonsController;

  const mockLessons: Lesson[] = [
    new Lesson(
      1,
      '2026-11-23',
      '09:00',
      '10:30',
      'Церковнославянский язык',
      'Практическое занятие',
      'Тестовый преподаватель',
      'Демонстрационная группа',
      '101',
    ),
  ];

  const mockService = {
    findAll: jest.fn(() => mockLessons),
  };

  beforeEach(async () => {
    mockService.findAll.mockClear();

    const module: TestingModule =
      await Test.createTestingModule({
        controllers: [LessonsController],
        providers: [
          {
            provide: LessonsService,
            useValue: mockService,
          },
        ],
      }).compile();

    controller =
      module.get<LessonsController>(LessonsController);
  });

  it('контроллер должен быть создан', () => {
    expect(controller).toBeDefined();
  });

  it('должен возвращать занятия из сервиса', () => {
    const result = controller.findAll();

    expect(result).toEqual(mockLessons);
    expect(mockService.findAll).toHaveBeenCalledTimes(1);
  });
});


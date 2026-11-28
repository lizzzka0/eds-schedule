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
      'Иванов Александр Сергеевич',
      'ДЕМО-Б1',
      'ДЕМО-101',
    ),
  ];

  // Имитация асинхронного сервиса
  const mockService = {
    findAll: jest.fn<() => Promise<Lesson[]>>(),
  };

  beforeEach(async () => {
    mockService.findAll.mockReset();
    mockService.findAll.mockResolvedValue(mockLessons);

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

    controller = module.get<LessonsController>(
      LessonsController,
    );
  });

  // BE-10
  it('контроллер должен быть создан', () => {
    expect(controller).toBeDefined();
  });

  // BE-11
  it('должен асинхронно возвращать занятия из сервиса', async () => {
    const result = await controller.findAll();

    expect(result).toEqual(mockLessons);

    expect(mockService.findAll).toHaveBeenCalledTimes(1);
  });
});

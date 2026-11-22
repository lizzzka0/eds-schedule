import { Test, TestingModule } from '@nestjs/testing';
import { LessonsService } from './lessons.service';

describe('LessonsService', () => {
  let service: LessonsService;

  beforeEach(async () => {
    const module: TestingModule =
      await Test.createTestingModule({
        providers: [LessonsService],
      }).compile();

    service = module.get<LessonsService>(LessonsService);
  });

  it('сервис должен быть создан', () => {
    expect(service).toBeDefined();
  });

  it('должен возвращать список занятий', () => {
    const lessons = service.findAll();

    expect(lessons).toHaveLength(1);
    expect(lessons[0].discipline).toBe(
      'Церковнославянский язык',
    );
    expect(lessons[0].studyGroup).toBe(
      'Демонстрационная группа',
    );
  });
});

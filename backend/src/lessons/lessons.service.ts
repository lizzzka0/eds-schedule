import { Injectable } from '@nestjs/common';
import { Lesson } from './entities/lesson.entity';

@Injectable()
export class LessonsService {
  private readonly lessons: Lesson[] = [
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

  findAll(): Lesson[] {
    return this.lessons;
  }
}

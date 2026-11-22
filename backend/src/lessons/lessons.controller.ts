import { Controller, Get } from '@nestjs/common';
import { LessonsService } from './lessons.service';
import { Lesson } from './entities/lesson.entity';

@Controller('api/lessons')
export class LessonsController {
  constructor(
    private readonly lessonsService: LessonsService,
  ) {}

  @Get()
  findAll(): Lesson[] {
    return this.lessonsService.findAll();
  }
}

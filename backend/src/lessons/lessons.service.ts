import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Lesson } from './entities/lesson.entity';

@Injectable()
export class LessonsService {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  async findAll(): Promise<Lesson[]> {
    const lessons = await this.prisma.lesson.findMany({
      where: {
        schedule: {
          status: 'PUBLISHED',
        },
      },

      include: {
        discipline: true,
        teacher: true,
        classroom: true,
        subgroup: true,
        groupAcademicYear: {
          include: {
            studyGroup: true,
          },
        },
      },

      orderBy: [
        { lessonDate: 'asc' },
        { startTime: 'asc' },
        { id: 'asc' },
      ],
    });

    const lessonTypes = {
      LECTURE: 'Лекция',
      SEMINAR: 'Семинар',
      PRACTICAL: 'Практическое занятие',
      CONSULTATION: 'Консультация',
      EXAM: 'Экзамен',
      CREDIT: 'Зачёт',
    } as const;

    return lessons.map((lesson) => {
      const teacherName = [
        lesson.teacher.lastName,
        lesson.teacher.firstName,
        lesson.teacher.middleName,
      ]
        .filter(Boolean)
        .join(' ');

      const groupName =
        lesson.groupAcademicYear.studyGroup.name;

      const studyGroup = lesson.subgroup
        ? `${groupName} — ${lesson.subgroup.name}`
        : groupName;

      return new Lesson(
        lesson.id,
        lesson.lessonDate.toISOString().slice(0, 10),
        lesson.startTime.toISOString().slice(11, 16),
        lesson.endTime.toISOString().slice(11, 16),
        lesson.discipline.name,
        lessonTypes[lesson.lessonType],
        teacherName,
        studyGroup,
        lesson.classroom?.number ?? 'Не назначена',
      );
    });
  }
}


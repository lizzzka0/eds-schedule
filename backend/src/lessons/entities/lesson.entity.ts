export class Lesson {
  constructor(
    public readonly id: number,
    public readonly date: string,
    public readonly startTime: string,
    public readonly endTime: string,
    public readonly discipline: string,
    public readonly lessonType: string,
    public readonly teacher: string,
    public readonly studyGroup: string,
    public readonly classroom: string,
  ) {}
}

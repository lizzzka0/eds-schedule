import type { Lesson } from '../types/lesson';

const API_URL = 'http://localhost:3000';

export async function fetchLessons(): Promise<Lesson[]> {
  const response = await fetch(`${API_URL}/api/lessons`);

  if (!response.ok) {
    throw new Error(
      `Ошибка загрузки расписания: ${response.status}`,
    );
  }

  return (await response.json()) as Lesson[];
}

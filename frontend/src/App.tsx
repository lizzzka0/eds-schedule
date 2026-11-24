
import { useEffect, useState } from 'react';
import type { Lesson } from './types/lesson';
import { fetchLessons } from './api/lessons';
import './App.css';

function App() {
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;

    async function loadLessons() {
      try {
        const data = await fetchLessons();

        if (active) {
          setLessons(data);
        }
      } catch {
        if (active) {
          setError('Не удалось загрузить расписание. Проверьте работу backend.');
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    void loadLessons();

    return () => {
      active = false;
    };
  }, []);

  return (
    <main className="schedule-page">
      <header className="schedule-header">
        <p className="schedule-eyebrow">
          Екатеринбургская духовная семинария
        </p>

        <h1>Расписание занятий</h1>

        <p>
          Демонстрационная версия электронного расписания
        </p>
      </header>

      {loading && (
        <p role="status">Загрузка расписания...</p>
      )}

      {error && (
        <p role="alert">{error}</p>
      )}

      {!loading && !error && lessons.length === 0 && (
        <p>На выбранный период занятий пока нет.</p>
      )}

      {!loading && !error && (
        <section className="lesson-list" aria-label="Список занятий">
          {lessons.map((lesson) => (
            <article className="lesson-card" key={lesson.id}>
              <p className="lesson-date">
                {lesson.date} · {lesson.startTime}–{lesson.endTime}
              </p>

              <h2>{lesson.discipline}</h2>

              <p>{lesson.lessonType} · {lesson.studyGroup}</p>
              <p>Преподаватель: {lesson.teacher}</p>
              <p>Аудитория: {lesson.classroom}</p>
            </article>
          ))}
        </section>
      )}
    </main>
  );
}

export default App;

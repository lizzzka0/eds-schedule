import { render, screen } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { fetchLessons } from './api/lessons'
import App from './App'

vi.mock('./api/lessons')

describe('App — электронное расписание', () => {
  it('отображает учебное занятие после загрузки', async () => {
    vi.mocked(fetchLessons).mockResolvedValue([
      {
        id: 1,
        date: '2026-11-23',
        startTime: '09:00',
        endTime: '10:30',
        discipline: 'Церковнославянский язык',
        lessonType: 'Практическое занятие',
        teacher: 'Тестовый преподаватель',
        studyGroup: 'Демонстрационная группа',
        classroom: '101',
      },
    ])

    render(<App />)

    expect(
      await screen.findByText('Церковнославянский язык'),
    ).toBeInTheDocument()

    expect(
      screen.getByText('Преподаватель: Тестовый преподаватель'),
    ).toBeInTheDocument()

    expect(
      screen.getByText('Аудитория: 101'),
    ).toBeInTheDocument()
  })
})

  it('отображает сообщение во время загрузки', () => {
    vi.mocked(fetchLessons).mockReturnValue(
      new Promise<never>(() => {}),
    )

    render(<App />)

    expect(screen.getByRole('status')).toHaveTextContent(
      'Загрузка расписания...',
    )
  })

  it('отображает сообщение при ошибке загрузки', async () => {
    vi.mocked(fetchLessons).mockRejectedValue(
      new Error('Ошибка сервера'),
    )

    render(<App />)

    expect(
      await screen.findByRole('alert'),
    ).toHaveTextContent('Не удалось загрузить расписание')
  })

  it('отображает сообщение при отсутствии занятий', async () => {
    vi.mocked(fetchLessons).mockResolvedValue([])

    render(<App />)

    expect(
      await screen.findByText(
        'На выбранный период занятий пока нет.',
      ),
    ).toBeInTheDocument()
  })

SELECT current_database();

-- Создание пользовательской схемы
CREATE SCHEMA IF NOT EXISTS schedule;

-- Настройка пути поиска для новых подключений
ALTER DATABASE eds_schedule
SET search_path TO schedule;

-- Настройка текущего подключения
SET search_path TO schedule;

-- Проверка настроек
SELECT current_database();
SELECT current_schema();
SHOW search_path;
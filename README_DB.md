# Домашнее задание 03: Проектирование и оптимизация реляционной базы данных
## Вариант 16 – Система заказа такси

---

## 📋 Описание

Проектирование схемы PostgreSQL для системы заказа такси с оптимизацией запросов.

---

## 🏗️ Схема базы данных

### Таблицы

| Таблица | Описание | Записей |
|---------|----------|---------|
| `users` | Пользователи (пассажиры) | 10 |
| `drivers` | Водители с данными авто | 10 |
| `orders` | Заказы/поездки | 10 |
| `payments` | Платежи за поездки | 7 |
| `reviews` | Отзывы о поездках | 5 |

### ER-диаграмма
users (1) ──┬── (1) drivers
│
│ (1)
│
▼ (N)
orders ── (1) payments
│
│ (1)
▼
reviews


---

## 🚀 Быстрый старт

### Запуск PostgreSQL через Docker

```bash
# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f postgres

# Подключение к базе:
# Через psql
docker exec -it taxi-postgres psql -U taxi -d taxi

# Или локально (если установлен psql)
psql -h localhost -U taxi -d taxi
Пароль: taxi123

# Структура файлов
lab2/
├── schema.sql          # Создание таблиц и индексов
├── data.sql            # Тестовые данные
├── queries.sql         # SQL запросы для всех операций
├── optimization.md     # EXPLAIN анализ и оптимизация
├── docker-compose.yaml # PostgreSQL + pgAdmin
└── README_DB.md        # Этот файл

# Индексы
## Созданные индексы


Индекс
Таблица
Колонки
Назначение
idx_users_login
users
login
Поиск при логине
idx_users_full_name
users
full_name
Поиск по имени
idx_drivers_status
drivers
status
Фильтр доступных водителей
idx_drivers_location
drivers
lat, lng
Гео-поиск водителей
idx_orders_passenger_id
orders
passenger_id
История поездок
idx_orders_status
orders
status
Фильтр активных заказов
idx_payments_order_id
payments
order_id
Поиск платежа по заказу

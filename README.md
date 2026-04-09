# Домашнее задание 03: Проектирование и оптимизация реляционной базы данных

**Выполнила:** Якушина Анна

## Вариант 16 — Система заказа такси

---

## Описание проекта

В рамках лабораторной работы реализован REST API сервис системы заказа такси на **Yandex userver** с подключением к **PostgreSQL**.

В проекте выполнены:

- проектирование реляционной схемы базы данных;
- создание таблиц, ограничений и индексов;
- заполнение базы тестовыми данными;
- подготовка SQL-запросов для операций варианта;
- анализ и описание оптимизации запросов;
- интеграция API из лабораторной работы 02 с PostgreSQL;
- запуск API и PostgreSQL через Docker Compose.

---

## Функциональность варианта

Система содержит следующие основные сущности:

- `users` — пользователи;
- `drivers` — водители;
- `rides` — поездки.

Реализованы следующие операции:

- создание нового пользователя;
- поиск пользователя по логину;
- поиск пользователя по маске имени и фамилии;
- регистрация водителя;
- создание заказа поездки;
- получение активных заказов;
- принятие заказа водителем;
- получение истории поездок пользователя;
- завершение поездки.

---

## Структура проекта

```text
taxi_lab3/
├── configs/
├── src/
│   ├── handlers/
│   ├── middlewares/
│   ├── models/
│   └── storage/
├── tests/
├── schema.sql
├── data.sql
├── queries.sql
├── optimization.md
├── openapi.yaml
├── Dockerfile
├── docker-compose.yaml
├── CMakeLists.txt
└── README.md
```

### Назначение основных файлов

- `schema.sql` — создание таблиц, ограничений и индексов;
- `data.sql` — заполнение базы тестовыми данными;
- `queries.sql` — SQL-запросы для основных операций варианта;
- `optimization.md` — описание индексов и анализ планов выполнения запросов;
- `openapi.yaml` — OpenAPI спецификация REST API;
- `docker-compose.yaml` — запуск PostgreSQL и API сервиса;
- `src/storage` — слой доступа к данным через PostgreSQL;
- `src/handlers` — реализация HTTP endpoint-ов;
- `src/middlewares` — middleware для Bearer-аутентификации.

---

## Схема базы данных

### Таблица `users`

Хранит пользователей системы.

**Поля:**

- `id` — идентификатор пользователя;
- `login` — уникальный логин;
- `password` — пароль;
- `full_name` — полное имя;
- `created_at` — дата создания.

### Таблица `drivers`

Хранит информацию о водителях.

**Поля:**

- `id` — идентификатор водителя;
- `user_id` — ссылка на пользователя;
- `car_model` — модель автомобиля;
- `car_number` — госномер;
- `license_number` — номер водительского удостоверения;
- `status` — статус водителя (`online`, `busy`, `offline`).

### Таблица `rides`

Хранит заказы поездок.

**Поля:**

- `id` — идентификатор поездки;
- `passenger_id` — пассажир;
- `driver_id` — водитель;
- `pickup_address` — адрес отправления;
- `destination_address` — адрес назначения;
- `status` — статус поездки (`searching`, `accepted`, `completed`, `cancelled`);
- `created_at` — дата создания;
- `completed_at` — дата завершения.

---

## Индексы

В проекте созданы индексы для ускорения типовых операций:

- поиск пользователя по имени;
- выборка водителей по статусу;
- выборка поездок по пассажиру;
- выборка поездок по водителю;
- поиск активных поездок;
- сортировка поездок по времени создания.

Подробный анализ приведён в файле `optimization.md`.

---

## Используемые технологии

- C++
- Yandex userver
- PostgreSQL
- Docker
- Docker Compose
- OpenAPI

---

## Запуск проекта

### 1. Клонирование репозитория

```bash
git clone https://github.com/AnnaYakushina1328/taxi_lab3.git
cd taxi_lab3
```

### 2. Запуск PostgreSQL и API

```bash
docker compose up -d --build
```

### 3. Проверка контейнеров

```bash
docker compose ps
```

### 4. Проверка доступности API

```bash
curl -i http://localhost:8080/ping
```

Ожидаемый ответ:

```http
HTTP/1.1 200 OK
```

---

## Подключение к базе данных

Подключение к PostgreSQL внутри контейнера:

```bash
docker exec -it taxi-postgres psql -U taxi -d taxi
```

Проверка таблиц:

```sql
\dt
```

Проверка количества записей:

```sql
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM drivers;
SELECT COUNT(*) FROM rides;
```

---

## Примеры работы с API

### Создание пользователя

```bash
curl -i -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "login": "test.user",
    "password": "pass123",
    "full_name": "Test User"
  }'
```

### Логин

```bash
curl -i -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "login": "test.user",
    "password": "pass123"
  }'
```

### Регистрация водителя

```bash
curl -i -X POST http://localhost:8080/drivers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_HERE" \
  -d '{
    "user_id": 11,
    "car_model": "Toyota Camry",
    "car_number": "K123KK77",
    "license_number": "LIC-1011"
  }'
```

### Создание поездки

```bash
curl -i -X POST http://localhost:8080/rides \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_HERE" \
  -d '{
    "passenger_id": 11,
    "pickup_address": "Lenina 1",
    "destination_address": "Tverskaya 10"
  }'
```

### Получение активных поездок

```bash
curl -i "http://localhost:8080/rides?status=active" \
  -H "Authorization: Bearer TOKEN_HERE"
```

### Получение истории поездок пользователя

```bash
curl -i "http://localhost:8080/rides?user_id=11" \
  -H "Authorization: Bearer TOKEN_HERE"
```

### Принятие поездки водителем

```bash
curl -i -X PATCH http://localhost:8080/rides/11/accept \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN_HERE" \
  -d '{
    "driver_id": 11
  }'
```

### Завершение поездки

```bash
curl -i -X PATCH http://localhost:8080/rides/11/complete \
  -H "Authorization: Bearer TOKEN_HERE"
```

---

## Проверка данных в PostgreSQL

### Проверка пользователей

```bash
docker exec -it taxi-postgres psql -U taxi -d taxi -c "SELECT id, login, full_name FROM users ORDER BY id DESC LIMIT 5;"
```

### Проверка водителей

```bash
docker exec -it taxi-postgres psql -U taxi -d taxi -c "SELECT id, user_id, car_model, car_number, status FROM drivers ORDER BY id DESC LIMIT 5;"
```

### Проверка поездок

```bash
docker exec -it taxi-postgres psql -U taxi -d taxi -c "SELECT id, passenger_id, driver_id, status FROM rides ORDER BY id DESC LIMIT 5;"
```

---

## SQL-файлы лабораторной работы

В репозитории присутствуют следующие файлы лабораторной работы 03:

- `schema.sql`
- `data.sql`
- `queries.sql`
- `optimization.md`

---

## Что было изменено по сравнению с лабораторной работой 02

Во второй лабораторной работе сервис использовал in-memory хранилище. В рамках лабораторной работы 03 выполнен переход на PostgreSQL:

- добавлен PostgreSQL component в userver;
- добавлены параметры подключения к базе в конфигурацию;
- переписан `TaxiStorage` на SQL-запросы к PostgreSQL;
- операции принятия и завершения поездки выполняются через транзакции;
- Docker Compose теперь поднимает и API, и PostgreSQL.

Bearer-токены для аутентификации в текущей реализации по-прежнему хранятся в памяти процесса.

---

## Ограничения текущей реализации

- токены аутентификации не сохраняются в базе данных;
- пароли хранятся в открытом виде без хеширования;
- не реализованы платежи и отзывы в API-слое;
- не реализовано удаление пользователей, водителей и поездок;
- проект ориентирован на учебную демонстрацию архитектуры и интеграции API с PostgreSQL.

---

## Вывод

В рамках лабораторной работы была спроектирована и реализована реляционная база данных PostgreSQL для системы заказа такси, а API из предыдущей лабораторной работы был успешно подключён к базе данных.

В результате получен рабочий сервис, который:

- запускается через Docker Compose;
- использует PostgreSQL в качестве основного хранилища;
- поддерживает основные операции варианта 16;
- содержит SQL-скрипты, документацию и описание оптимизации запросов.

Проект готов к проверке в формате:

```bash
git clone https://github.com/AnnaYakushina1328/taxi_lab3.git
cd taxi_lab3
docker compose up -d --build
```

# Оптимизация SQL-запросов

## Вариант 16 — Система заказа такси

## Общая информация

В рамках лабораторной работы была спроектирована реляционная база данных PostgreSQL для системы заказа такси.  
В финальной реализации используются три основные таблицы:

- `users` — пользователи сервиса;
- `drivers` — водители;
- `rides` — поездки.

Так как REST API из лабораторной работы 02 был подключён к PostgreSQL, при проектировании схемы базы данных были добавлены индексы для тех операций, которые чаще всего используются в API:

- поиск пользователя по логину;
- поиск пользователя по маске имени;
- регистрация и получение информации о водителе;
- получение активных поездок;
- получение истории поездок пользователя;
- принятие и завершение поездки.

# Запускать команды по анализу 'EXPLAIN ANALYZE' нужно уже после того, как попали в docker:
```bash
docker exec -it taxi-postgres psql -U taxi -d taxi
```

---

## Созданные индексы

### Таблица `users`

В таблице `users` логин пользователя должен быть уникальным:

```sql
NIKITOS (login)
```

Это ограничение автоматически создаёт индекс по полю `login`.  
Он используется для:

- поиска пользователя по логину;
- проверки уникальности логина при регистрации;
- авторизации пользователя.

Также для поиска пользователя по части имени был создан trigram-индекс:

```sql
CREATE INDEX idx_users_full_name_trgm
    ON users USING GIN (lower(full_name) gin_trgm_ops);
```

Этот индекс нужен для ускорения запросов вида:

```sql
WHERE lower(full_name) LIKE '%' || lower($1) || '%'
```

### Таблица `drivers`

В таблице `drivers` автоматически создаются индексы по уникальным ограничениям:

```sql
UNIQUE (user_id)
UNIQUE (car_number)
UNIQUE (license_number)
```

Дополнительно были созданы индексы:

```sql
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
```

Назначение индексов:

- `idx_drivers_status` ускоряет выборку водителей по статусу (`online`, `busy`, `offline`);
- `idx_drivers_user_id` ускоряет поиск водителя по пользователю.

### Таблица `rides`

Для таблицы `rides` были созданы индексы:

```sql
CREATE INDEX idx_rides_passenger_id ON rides(passenger_id);
CREATE INDEX idx_rides_driver_id ON rides(driver_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_passenger_status ON rides(passenger_id, status);
CREATE INDEX idx_rides_created_at ON rides(created_at DESC);
```

Назначение индексов:

- `idx_rides_passenger_id` ускоряет получение поездок конкретного пользователя;
- `idx_rides_driver_id` ускоряет поиск поездок конкретного водителя;
- `idx_rides_status` ускоряет выборку активных поездок;
- `idx_rides_passenger_status` полезен для выборки поездок пользователя с фильтрацией по статусу;
- `idx_rides_created_at` полезен для сортировки поездок по времени создания.

---

## Анализ типовых запросов

Ниже приведены планы выполнения `EXPLAIN ANALYZE` для ключевых запросов системы заказа такси.

### 1. Поиск пользователя по логину

Запрос:

```sql
SELECT id, login, full_name
FROM users
WHERE login = 'test.user';
```

План выполнения:

```text
Index Scan using users_login_key on users  (cost=0.14..8.16 rows=1 width=738) (actual time=0.010..0.011 rows=0 loops=1)
  Index Cond: ((login)::text = 'test.user'::text)
Planning Time: 0.383 ms
Execution Time: 0.050 ms
```

Вывод:

PostgreSQL использует индекс `users_login_key`, который был автоматически создан ограничением уникальности для поля `login`. Это означает, что поиск пользователя по логину выполняется эффективно без полного сканирования таблицы. В данном запуске найдено `0` строк, однако это не влияет на оценку плана: сам факт использования индексного доступа подтверждает корректность оптимизации.

---

### 2. Получение активных поездок

Запрос:

```sql
SELECT id, passenger_id, driver_id, pickup_address, destination_address, status
FROM rides
WHERE status IN ('searching', 'accepted')
ORDER BY id;
```

План выполнения:

```text
Sort  (cost=10.88..10.89 rows=2 width=1102) (actual time=0.022..0.023 rows=6 loops=1)
  Sort Key: id
  Sort Method: quicksort  Memory: 25kB
  ->  Seq Scan on rides  (cost=0.00..10.88 rows=2 width=1102) (actual time=0.006..0.008 rows=6 loops=1)
        Filter: ((status)::text = ANY ('{searching,accepted}'::text[]))
        Rows Removed by Filter: 5
Planning Time: 0.231 ms
Execution Time: 0.032 ms
```

Вывод:

Для выборки активных поездок PostgreSQL использует `Seq Scan` по таблице `rides`, а затем выполняет сортировку по `id`. Это нормально для небольшого тестового набора данных, где в таблице мало строк, и последовательное сканирование оказывается дешевле индексного доступа. При увеличении объёма данных индекс `idx_rides_status` будет становиться более полезным.

---

### 3. Получение истории поездок пользователя

Запрос:

```sql
SELECT id, passenger_id, driver_id, pickup_address, destination_address, status
FROM rides
WHERE passenger_id = 11
ORDER BY created_at DESC, id DESC;
```

План выполнения:

```text
Sort  (cost=8.17..8.18 rows=1 width=1110) (actual time=0.023..0.024 rows=1 loops=1)
  Sort Key: created_at DESC, id DESC
  Sort Method: quicksort  Memory: 25kB
  ->  Index Scan using idx_rides_passenger_status on rides  (cost=0.14..8.16 rows=1 width=1110) (actual time=0.008..0.009 rows=1 loops=1)
        Index Cond: (passenger_id = 11)
Planning Time: 0.118 ms
Execution Time: 0.042 ms
```

Вывод:

Для получения истории поездок пользователя PostgreSQL использует индекс `idx_rides_passenger_status`. Это подтверждает, что выборка по `passenger_id` уже оптимизирована. После этого выполняется быстрая сортировка по `created_at DESC, id DESC`, что для небольшого числа записей также является нормальным и эффективным поведением.

---

### 4. Поиск водителя по пользователю

Запрос:

```sql
SELECT id, user_id, car_model, car_number, license_number, status
FROM drivers
WHERE user_id = 11;
```

План выполнения:

```text
Index Scan using idx_drivers_user_id on drivers  (cost=0.14..8.16 rows=1 width=480) (actual time=0.018..0.019 rows=0 loops=1)
  Index Cond: (user_id = 11)
Planning Time: 0.360 ms
Execution Time: 0.032 ms
```

Вывод:

Для поиска водителя по `user_id` PostgreSQL использует индекс `idx_drivers_user_id`. Это делает запрос быстрым и избавляет от полного сканирования таблицы `drivers`. В текущем запуске найдено `0` строк, но, как и в случае с поиском пользователя по логину, это не отменяет того, что индекс выбран и используется корректно.

---

## Итог по анализу планов выполнения

Результаты `EXPLAIN ANALYZE` показывают, что оптимизация базы данных выполнена обоснованно:

- для точечных запросов по `login` и `user_id` PostgreSQL использует индексный доступ;
- для истории поездок пользователя используется индекс `idx_rides_passenger_status`;
- для активных поездок на малом объёме данных PostgreSQL выбирает `Seq Scan`, что является нормальным поведением оптимизатора;
- при росте количества записей индексы по `status`, `passenger_id` и другим ключевым полям будут давать ещё больший выигрыш по производительности.

Таким образом, созданные индексы соответствуют основным операциям API и подготавливают систему к дальнейшему увеличению объёма данных.

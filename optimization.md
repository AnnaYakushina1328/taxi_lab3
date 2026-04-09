# Оптимизация SQL-запросов

## Вариант 16 — Система заказа такси

## Общая информация

В рамках лабораторной работы для системы заказа такси были проанализированы наиболее частые запросы и созданы индексы для ускорения их выполнения.

К часто используемым операциям относятся:

- поиск пользователя по логину;
- поиск пользователя по имени;
- выборка доступных водителей;
- получение активных заказов;
- получение истории поездок пользователя;
- поиск платежей по заказу.

## Созданные индексы и их назначение

### Индексы таблицы `users`

```sql
CREATE INDEX idx_users_login ON users(login);
CREATE INDEX idx_users_full_name ON users(full_name);
CREATE INDEX idx_users_created_at ON users(created_at);
```

Назначение:

- `idx_users_login` ускоряет поиск пользователя по логину;
- `idx_users_full_name` ускоряет поиск пользователя по полному имени;
- `idx_users_created_at` полезен для выборок и сортировок по времени создания.

### Индексы таблицы `drivers`

```sql
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_rating ON drivers(rating DESC);
CREATE INDEX idx_drivers_location ON drivers(current_lat, current_lng) WHERE status = 'online';
```

Назначение:

- `idx_drivers_user_id` ускоряет связь водителя с пользователем;
- `idx_drivers_status` ускоряет выборку доступных водителей;
- `idx_drivers_rating` полезен при сортировке по рейтингу;
- `idx_drivers_location` предназначен для поиска ближайших водителей среди тех, кто сейчас онлайн.

### Индексы таблицы `orders`

```sql
CREATE INDEX idx_orders_passenger_id ON orders(passenger_id);
CREATE INDEX idx_orders_driver_id ON orders(driver_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
CREATE INDEX idx_orders_passenger_status ON orders(passenger_id, status);
```

Назначение:

- `idx_orders_passenger_id` ускоряет получение истории поездок пользователя;
- `idx_orders_driver_id` ускоряет выборку заказов водителя;
- `idx_orders_status` ускоряет поиск активных заказов;
- `idx_orders_created_at` полезен для сортировки заказов по времени;
- `idx_orders_status_created` полезен для выборок активных заказов с сортировкой по времени;
- `idx_orders_passenger_status` ускоряет выборку заказов конкретного пользователя по статусу.

### Индексы таблицы `payments`

```sql
CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);
```

Назначение:

- `idx_payments_order_id` ускоряет поиск платежа по заказу;
- `idx_payments_status` полезен для выборки платежей по статусу;
- `idx_payments_created_at` ускоряет сортировку платежей по времени.

### Индексы таблицы `reviews`

```sql
CREATE INDEX idx_reviews_order_id ON reviews(order_id);
CREATE INDEX idx_reviews_driver_id ON reviews(driver_id);
CREATE INDEX idx_reviews_passenger_id ON reviews(passenger_id);
```

Назначение:

- ускоряют выборки отзывов по заказу, водителю и пассажиру.

---

## Анализ запросов с помощью EXPLAIN ANALYZE

### 1. Поиск пользователя по логину

Запрос:

```sql
SELECT id, login, full_name, email, phone, created_at
FROM users
WHERE login = 'passenger1';
```

Команда для анализа:

```sql
EXPLAIN ANALYZE
SELECT id, login, full_name, email, phone, created_at
FROM users
WHERE login = 'passenger1';
```

План выполнения:

```text
Index Scan using idx_users_login on users  (cost=0.14..8.16 rows=1 width=624) (actual time=0.033..0.033 rows=1 loops=1)
  Index Cond: ((login)::text = 'passenger1'::text)
Planning Time: 0.645 ms
Execution Time: 0.073 ms
```

Вывод:

Для данного запроса PostgreSQL использует индекс `idx_users_login`. Это означает, что поиск пользователя по логину выполняется эффективно без полного сканирования таблицы. Такой индекс особенно важен для операций авторизации и проверки существования пользователя.

---

### 2. Получение активных заказов

Запрос:

```sql
SELECT *
FROM active_orders;
```

Команда для анализа:

```sql
EXPLAIN ANALYZE
SELECT *
FROM active_orders;
```

План выполнения:

```text
Hash Right Join  (cost=21.86..33.97 rows=4 width=1562) (actual time=0.097..0.101 rows=4 loops=1)
  Hash Cond: (d.id = o.driver_id)
  ->  Seq Scan on drivers d  (cost=0.00..11.50 rows=150 width=222) (actual time=0.012..0.013 rows=10 loops=1)
  ->  Hash  (cost=21.81..21.81 rows=4 width=1344) (actual time=0.069..0.070 rows=4 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 9kB
        ->  Hash Join  (cost=10.95..21.81 rows=4 width=1344) (actual time=0.059..0.063 rows=4 loops=1)
              Hash Cond: (u.id = o.passenger_id)
              ->  Seq Scan on users u  (cost=0.00..10.60 rows=60 width=222) (actual time=0.004..0.005 rows=10 loops=1)
              ->  Hash  (cost=10.90..10.90 rows=4 width=1126) (actual time=0.033..0.034 rows=4 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    ->  Seq Scan on orders o  (cost=0.00..10.90 rows=4 width=1126) (actual time=0.022..0.025 rows=4 loops=1)
                          Filter: ((status)::text = ANY ('{created,searching,accepted,in_progress}'::text[]))
                          Rows Removed by Filter: 6
Planning Time: 1.488 ms
Execution Time: 0.170 ms
```

Вывод:

Для выборки активных заказов PostgreSQL на текущем объёме тестовых данных использует `Seq Scan` по таблице `orders`, а затем выполняет соединения с таблицами `users` и `drivers`. Это нормально, так как в таблицах всего по 10 строк, и для такого малого объёма данных последовательное сканирование оказывается дешевле индексного доступа. При росте количества заказов индексы `idx_orders_status` и `idx_orders_status_created` станут более полезными.

---

### 3. Получение истории поездок пользователя

Запрос:

```sql
SELECT o.id, o.status, o.pickup_address, o.destination_address,
       o.final_price, o.created_at, o.completed_at,
       d.car_model, d.car_number
FROM orders o
LEFT JOIN drivers d ON o.driver_id = d.id
WHERE o.passenger_id = 1
ORDER BY o.created_at DESC;
```

Команда для анализа:

```sql
EXPLAIN ANALYZE
SELECT o.id, o.status, o.pickup_address, o.destination_address,
       o.final_price, o.created_at, o.completed_at,
       d.car_model, d.car_number
FROM orders o
LEFT JOIN drivers d ON o.driver_id = d.id
WHERE o.passenger_id = 1
ORDER BY o.created_at DESC;
```

План выполнения:

```text
Sort  (cost=16.44..16.44 rows=1 width=1402) (actual time=0.070..0.071 rows=1 loops=1)
  Sort Key: o.created_at DESC
  Sort Method: quicksort  Memory: 25kB
  ->  Nested Loop Left Join  (cost=0.29..16.43 rows=1 width=1402) (actual time=0.054..0.055 rows=1 loops=1)
        ->  Index Scan using idx_orders_passenger_status on orders o  (cost=0.14..8.16 rows=1 width=1130) (actual time=0.038..0.039 rows=1 loops=1)
              Index Cond: (passenger_id = 1)
        ->  Index Scan using drivers_pkey on drivers d  (cost=0.14..8.16 rows=1 width=280) (actual time=0.011..0.011 rows=1 loops=1)
              Index Cond: (id = o.driver_id)
Planning Time: 0.199 ms
Execution Time: 0.096 ms
```

Вывод:

Для данного запроса PostgreSQL использует индекс `idx_orders_passenger_status`, что ускоряет выборку поездок конкретного пользователя. Затем выполняется `Index Scan` по первичному ключу таблицы `drivers`, что также является эффективным способом соединения. Таким образом, получение истории поездок пользователя уже оптимизировано и выполняется без полного сканирования таблицы `orders`.

---

## Общий вывод по оптимизации

В ходе проектирования базы данных были созданы индексы для наиболее частых и критичных запросов системы заказа такси. Основное внимание было уделено следующим сценариям:

- быстрый поиск пользователя по логину;
- выборка доступных водителей;
- получение активных заказов;
- получение истории поездок пользователя;
- поиск платежей по заказу.

Результаты анализа показали, что:

- индекс `idx_users_login` действительно используется PostgreSQL при поиске пользователя по логину;
- индекс `idx_orders_passenger_status` используется для получения истории поездок пользователя;
- для запроса получения активных заказов на небольшом количестве тестовых данных PostgreSQL выбирает `Seq Scan`, так как это дешевле индексного доступа.

Таким образом, оптимизация выполнена обоснованно. База данных подготовлена не только для корректной работы на учебных данных, но и для дальнейшего роста объёма данных, при котором созданные индексы будут давать ещё больший выигрыш по производительности.

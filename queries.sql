-- Вариант 16. Система заказа такси
-- SQL-запросы для основных операций API

-- 1. Создание нового пользователя
INSERT INTO users (login, password, full_name)
VALUES ($1, $2, $3)
RETURNING id, login, full_name;

-- 2. Поиск пользователя по логину
SELECT id, login, full_name
FROM users
WHERE login = $1;

-- 3. Поиск пользователя по маске имени и фамилии
SELECT id, login, full_name
FROM users
WHERE lower(full_name) LIKE '%' || lower($1) || '%'
ORDER BY id;

-- 4. Регистрация водителя
INSERT INTO drivers (user_id, car_model, car_number, license_number, status)
VALUES ($1, $2, $3, $4, 'online')
RETURNING id, user_id, car_model, car_number, license_number, status;

-- 5. Создание заказа поездки
INSERT INTO rides (passenger_id, pickup_address, destination_address, status)
VALUES ($1, $2, $3, 'searching')
RETURNING id, passenger_id, driver_id, pickup_address, destination_address, status;

-- 6. Получение активных заказов
SELECT id, passenger_id, driver_id, pickup_address, destination_address, status
FROM rides
WHERE status IN ('searching', 'accepted')
ORDER BY id;

-- 7. Принятие заказа водителем
WITH updated_driver AS (
    UPDATE drivers
    SET status = 'busy'
    WHERE id = $2
      AND status = 'online'
    RETURNING id
),
updated_ride AS (
    UPDATE rides
    SET driver_id = $2,
        status = 'accepted'
    WHERE id = $1
      AND status = 'searching'
      AND EXISTS (SELECT 1 FROM updated_driver)
    RETURNING id, passenger_id, driver_id, pickup_address, destination_address, status
)
SELECT *
FROM updated_ride;

-- 8. Получение истории поездок пользователя
SELECT id, passenger_id, driver_id, pickup_address, destination_address, status
FROM rides
WHERE passenger_id = $1
ORDER BY created_at DESC, id DESC;

-- 9. Завершение поездки
WITH updated_ride AS (
    UPDATE rides
    SET status = 'completed',
        completed_at = NOW()
    WHERE id = $1
      AND status = 'accepted'
    RETURNING id, passenger_id, driver_id, pickup_address, destination_address, status
),
updated_driver AS (
    UPDATE drivers
    SET status = 'online'
    WHERE id = (SELECT driver_id FROM updated_ride)
    RETURNING id
)
SELECT *
FROM updated_ride;

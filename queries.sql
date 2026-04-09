-- =====================================================
-- SQL запросы для всех операций из варианта 16
-- Система заказа такси
-- =====================================================

-- =====================================================
-- 1. Создание нового пользователя
-- =====================================================
-- INSERT нового пассажира
INSERT INTO users (login, password_hash, full_name, email, phone)
VALUES ('new_user', 'hash_new_password', 'Новый Пользователь', 'new@test.ru', '+79991234567')
RETURNING id, login, full_name, created_at;

-- =====================================================
-- 2. Поиск пользователя по логину
-- =====================================================
SELECT id, login, full_name, email, phone, created_at
FROM users
WHERE login = 'passenger1';

-- =====================================================
-- 3. Поиск пользователя по маске имя и фамилии
-- =====================================================
SELECT id, login, full_name, email, phone
FROM users
WHERE full_name ILIKE '%Иван%';

-- Поиск по началу имени
SELECT id, login, full_name, email, phone
FROM users
WHERE full_name ILIKE 'Анна%';

-- =====================================================
-- 4. Регистрация водителя
-- =====================================================
INSERT INTO drivers (user_id, car_model, car_number, license_number, rating, status)
VALUES (1, 'Toyota Camry', 'А111АА777', '77AA111111', 5.00, 'online')
RETURNING id, user_id, car_model, car_number, status;

-- =====================================================
-- 5. Создание заказа поездки
-- =====================================================
INSERT INTO orders (passenger_id, pickup_lat, pickup_lng, pickup_address, 
                    destination_lat, destination_lng, destination_address, 
                    status, estimated_price, comment)
VALUES (1, 55.751244, 37.618423, 'Красная площадь', 
        55.755826, 37.617300, 'Тверская улица', 
        'created', 350.00, 'Нужно детское кресло')
RETURNING id, passenger_id, status, estimated_price, created_at;

-- =====================================================
-- 6. Получение активных заказов
-- =====================================================
-- Все активные заказы
SELECT * FROM active_orders;

-- Активные заказы конкретного пассажира
SELECT o.id, o.status, o.pickup_address, o.destination_address, 
       o.estimated_price, o.created_at
FROM orders o
WHERE o.passenger_id = 1 
  AND o.status IN ('created', 'searching', 'accepted', 'in_progress');

-- =====================================================
-- 7. Принятие заказа водителем
-- =====================================================
UPDATE orders 
SET status = 'accepted', 
    driver_id = 1,
    updated_at = CURRENT_TIMESTAMP
WHERE id = 6 AND status = 'searching'
RETURNING id, driver_id, status, updated_at;

-- =====================================================
-- 8. Получение истории поездок пользователя
-- =====================================================
-- Все поездки пассажира
SELECT o.id, o.status, o.pickup_address, o.destination_address, 
       o.final_price, o.created_at, o.completed_at,
       d.car_model, d.car_number
FROM orders o
LEFT JOIN drivers d ON o.driver_id = d.id
WHERE o.passenger_id = 1
ORDER BY o.created_at DESC;

-- Только завершённые поездки
SELECT o.id, o.pickup_address, o.destination_address, 
       o.final_price, o.completed_at,
       d.car_model, u.full_name AS driver_name
FROM orders o
JOIN drivers d ON o.driver_id = d.id
JOIN users u ON d.user_id = u.id
WHERE o.passenger_id = 1 AND o.status = 'completed'
ORDER BY o.completed_at DESC;

-- =====================================================
-- 9. Завершение поездки
-- =====================================================
UPDATE orders 
SET status = 'completed', 
    final_price = 450.00,
    completed_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE id = 8 AND status = 'in_progress'
RETURNING id, status, final_price, completed_at;

-- =====================================================
-- ДОПОЛНИТЕЛЬНЫЕ ЗАПРОСЫ
-- =====================================================

-- Поиск ближайших доступных водителей (в радиусе ~5км)
SELECT d.id, d.car_model, d.rating, d.current_lat, d.current_lng,
       ROUND((6371 * acos(
           cos(radians(55.751244)) * cos(radians(d.current_lat)) * 
           cos(radians(d.current_lng) - radians(37.618423)) + 
           sin(radians(55.751244)) * sin(radians(d.current_lat))
       ))::numeric, 2) AS distance_km
FROM drivers d
WHERE d.status = 'online'
HAVING distance_km <= 5
ORDER BY distance_km ASC
LIMIT 10;

-- Статистика по водителю
SELECT d.id, u.full_name, d.car_model, d.rating,
       COUNT(o.id) AS total_orders,
       COUNT(CASE WHEN o.status = 'completed' THEN 1 END) AS completed_orders,
       SUM(o.final_price) AS total_earnings
FROM drivers d
JOIN users u ON d.user_id = u.id
LEFT JOIN orders o ON d.id = o.driver_id
WHERE d.id = 1
GROUP BY d.id, u.full_name, d.car_model, d.rating;

-- Обновление рейтинга водителя после отзыва
UPDATE drivers d
SET rating = (
    SELECT COALESCE(AVG(r.rating), d.rating)
    FROM reviews r
    WHERE r.driver_id = d.id
)
WHERE d.id = 1
RETURNING id, rating;

-- Удаление заказа (отмена)
UPDATE orders 
SET status = 'cancelled', 
    updated_at = CURRENT_TIMESTAMP
WHERE id = 9 AND status IN ('created', 'searching')
RETURNING id, status;

-- Получение платежа по заказу
SELECT p.id, p.order_id, p.amount, p.status, p.transaction_id, p.created_at
FROM payments p
WHERE p.order_id = 1;

-- Создание платежа после завершения поездки
INSERT INTO payments (order_id, amount, payment_method, status)
VALUES (8, 450.00, 'card', 'pending')
RETURNING id, order_id, amount, status;

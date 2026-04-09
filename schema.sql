-- =====================================================
-- Схема базы данных для системы заказа такси
-- Вариант 16
-- =====================================================

-- Включаем расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =====================================================
-- Таблица: Пользователи (пассажиры)
-- =====================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    login VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_login_length CHECK (LENGTH(login) >= 3),
    CONSTRAINT check_password_length CHECK (LENGTH(password_hash) >= 8)
);

-- =====================================================
-- Таблица: Водители
-- =====================================================
CREATE TABLE drivers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    car_model VARCHAR(100) NOT NULL,
    car_number VARCHAR(20) NOT NULL UNIQUE,
    license_number VARCHAR(50) NOT NULL,
    rating DECIMAL(3,2) DEFAULT 4.50 CHECK (rating >= 0 AND rating <= 5),
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'busy')),
    current_lat DECIMAL(9,6),
    current_lng DECIMAL(9,6),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Таблица: Заказы (поездки)
-- =====================================================
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    passenger_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_id INTEGER REFERENCES drivers(id) ON DELETE SET NULL,
    pickup_lat DECIMAL(9,6) NOT NULL,
    pickup_lng DECIMAL(9,6) NOT NULL,
    pickup_address VARCHAR(255),
    destination_lat DECIMAL(9,6) NOT NULL,
    destination_lng DECIMAL(9,6) NOT NULL,
    destination_address VARCHAR(255),
    status VARCHAR(20) DEFAULT 'created' CHECK (status IN ('created', 'searching', 'accepted', 'in_progress', 'completed', 'cancelled')),
    estimated_price DECIMAL(10,2),
    final_price DECIMAL(10,2),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT check_price_positive CHECK (estimated_price >= 0 AND final_price >= 0)
);

-- =====================================================
-- Таблица: Платежи
-- =====================================================
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(20) DEFAULT 'card' CHECK (payment_method IN ('card', 'cash', 'wallet')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    transaction_id VARCHAR(100) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Таблица: Отзывы о поездках
-- =====================================================
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    passenger_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_id INTEGER NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ИНДЕКСЫ
-- =====================================================

-- Индексы для пользователей (поиск по логину и имени)
CREATE INDEX idx_users_login ON users(login);
CREATE INDEX idx_users_full_name ON users(full_name);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Индексы для водителей (поиск доступных, по статусу)
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_rating ON drivers(rating DESC);
CREATE INDEX idx_drivers_location ON drivers(current_lat, current_lng) WHERE status = 'online';

-- Индексы для заказов (основная таблица для запросов)
CREATE INDEX idx_orders_passenger_id ON orders(passenger_id);
CREATE INDEX idx_orders_driver_id ON orders(driver_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
CREATE INDEX idx_orders_passenger_status ON orders(passenger_id, status);

-- Индексы для платежей
CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);

-- Индексы для отзывов
CREATE INDEX idx_reviews_order_id ON reviews(order_id);
CREATE INDEX idx_reviews_driver_id ON reviews(driver_id);
CREATE INDEX idx_reviews_passenger_id ON reviews(passenger_id);

-- =====================================================
-- ФУНКЦИИ И ТРИГГЕРЫ
-- =====================================================

-- Функция для обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ПРЕДСТАВЛЕНИЯ (VIEWS)
-- =====================================================

-- Представление: Активные заказы
CREATE VIEW active_orders AS
SELECT 
    o.id,
    o.passenger_id,
    u.full_name AS passenger_name,
    o.driver_id,
    d.car_model AS driver_car,
    o.status,
    o.estimated_price,
    o.pickup_address,
    o.destination_address,
    o.created_at
FROM orders o
JOIN users u ON o.passenger_id = u.id
LEFT JOIN drivers d ON o.driver_id = d.id
WHERE o.status IN ('created', 'searching', 'accepted', 'in_progress');

-- Представление: Рейтинг водителей
CREATE VIEW driver_ratings AS
SELECT 
    d.id,
    d.user_id,
    u.full_name,
    d.car_model,
    d.rating,
    COUNT(r.id) AS review_count,
    AVG(r.rating) AS avg_review_rating
FROM drivers d
JOIN users u ON d.user_id = u.id
LEFT JOIN reviews r ON d.id = r.driver_id
GROUP BY d.id, d.user_id, u.full_name, d.car_model, d.rating;

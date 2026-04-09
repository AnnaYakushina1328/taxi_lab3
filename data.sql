BEGIN;

INSERT INTO users (login, password, full_name) VALUES
    ('passenger1', 'pass123', 'Ivan Petrov'),
    ('passenger2', 'pass123', 'Anna Smirnova'),
    ('passenger3', 'pass123', 'Elena Ivanova'),
    ('passenger4', 'pass123', 'Dmitry Sokolov'),
    ('passenger5', 'pass123', 'Maria Kuznetsova'),
    ('driveruser1', 'pass123', 'Pavel Popov'),
    ('driveruser2', 'pass123', 'Olga Lebedeva'),
    ('driveruser3', 'pass123', 'Sergey Kozlov'),
    ('driveruser4', 'pass123', 'Natalia Novikova'),
    ('driveruser5', 'pass123', 'Alexey Morozov');

INSERT INTO drivers (user_id, car_model, car_number, license_number, status) VALUES
    ((SELECT id FROM users WHERE login = 'driveruser1'), 'Hyundai Solaris', 'A111AA77', 'LIC-0001', 'online'),
    ((SELECT id FROM users WHERE login = 'driveruser2'), 'Kia Rio', 'B222BB77', 'LIC-0002', 'online'),
    ((SELECT id FROM users WHERE login = 'driveruser3'), 'Skoda Octavia', 'C333CC77', 'LIC-0003', 'busy'),
    ((SELECT id FROM users WHERE login = 'driveruser4'), 'Toyota Camry', 'D444DD77', 'LIC-0004', 'online'),
    ((SELECT id FROM users WHERE login = 'driveruser5'), 'Volkswagen Polo', 'E555EE77', 'LIC-0005', 'offline'),
    ((SELECT id FROM users WHERE login = 'passenger1'), 'Lada Vesta', 'F666FF77', 'LIC-0006', 'online'),
    ((SELECT id FROM users WHERE login = 'passenger2'), 'Renault Logan', 'G777GG77', 'LIC-0007', 'busy'),
    ((SELECT id FROM users WHERE login = 'passenger3'), 'Ford Focus', 'H888HH77', 'LIC-0008', 'online'),
    ((SELECT id FROM users WHERE login = 'passenger4'), 'Nissan Almera', 'I999II77', 'LIC-0009', 'online'),
    ((SELECT id FROM users WHERE login = 'passenger5'), 'Chevrolet Aveo', 'J101JJ77', 'LIC-0010', 'offline');

INSERT INTO rides (passenger_id, driver_id, pickup_address, destination_address, status, completed_at) VALUES
    ((SELECT id FROM users WHERE login = 'passenger1'), NULL, 'Lenina 10', 'Tverskaya 5', 'searching', NULL),
    ((SELECT id FROM users WHERE login = 'passenger2'), (SELECT id FROM drivers WHERE car_number = 'A111AA77'), 'Arbat 15', 'Mira 20', 'accepted', NULL),
    ((SELECT id FROM users WHERE login = 'passenger3'), (SELECT id FROM drivers WHERE car_number = 'C333CC77'), 'Nevsky 1', 'Ligovsky 8', 'completed', NOW()),
    ((SELECT id FROM users WHERE login = 'passenger4'), NULL, 'Pushkina 3', 'Sadovaya 17', 'searching', NULL),
    ((SELECT id FROM users WHERE login = 'passenger5'), (SELECT id FROM drivers WHERE car_number = 'D444DD77'), 'Prospekt 12', 'Center Mall', 'accepted', NULL),
    ((SELECT id FROM users WHERE login = 'passenger1'), (SELECT id FROM drivers WHERE car_number = 'G777GG77'), 'Airport', 'Hotel', 'completed', NOW()),
    ((SELECT id FROM users WHERE login = 'passenger2'), NULL, 'Station', 'University', 'searching', NULL),
    ((SELECT id FROM users WHERE login = 'passenger3'), (SELECT id FROM drivers WHERE car_number = 'H888HH77'), 'Park', 'Office', 'completed', NOW()),
    ((SELECT id FROM users WHERE login = 'passenger4'), NULL, 'Home', 'Cinema', 'searching', NULL),
    ((SELECT id FROM users WHERE login = 'passenger5'), (SELECT id FROM drivers WHERE car_number = 'I999II77'), 'Market', 'Airport', 'completed', NOW());

COMMIT;

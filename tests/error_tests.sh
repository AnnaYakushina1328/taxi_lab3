#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

echo "[1] users without params -> 400"
STATUS=$(curl -s -o /tmp/taxi_err_1.txt -w "%{http_code}" "$BASE_URL/users")
test "$STATUS" = "400"
cat /tmp/taxi_err_1.txt
echo

echo "[2] login with invalid password -> 401"
curl -s -X POST "$BASE_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"login":"passenger1","password":"secret123","full_name":"Ivan Ivanov"}' >/dev/null

STATUS=$(curl -s -o /tmp/taxi_err_2.txt -w "%{http_code}" -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login":"passenger1","password":"wrong"}')
test "$STATUS" = "401"
cat /tmp/taxi_err_2.txt
echo

echo "[3] protected endpoint without token -> 401"
STATUS=$(curl -s -o /tmp/taxi_err_3.txt -w "%{http_code}" -X POST "$BASE_URL/drivers" \
  -H "Content-Type: application/json" \
  -d '{"user_id":1,"car_model":"Toyota Camry","car_number":"A123BC777","license_number":"77AB123456"}')
test "$STATUS" = "401"
cat /tmp/taxi_err_3.txt
echo

echo "[4] protected endpoint with invalid token -> 401"
STATUS=$(curl -s -o /tmp/taxi_err_4.txt -w "%{http_code}" -X POST "$BASE_URL/rides" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer bad-token" \
  -d '{"passenger_id":1,"pickup_address":"A","destination_address":"B"}')
test "$STATUS" = "401"
cat /tmp/taxi_err_4.txt
echo

echo "ERROR TESTS PASSED"

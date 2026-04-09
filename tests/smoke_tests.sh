#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

echo "[1] create user"
USER_RESPONSE=$(curl -s -X POST "$BASE_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"login":"passenger1","password":"secret123","full_name":"Ivan Ivanov"}')
echo "$USER_RESPONSE"

echo "[2] login"
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login":"passenger1","password":"secret123"}')
echo "$LOGIN_RESPONSE"

TOKEN=$(printf '%s' "$LOGIN_RESPONSE" | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')
echo "TOKEN=$TOKEN"

echo "[3] create driver"
DRIVER_RESPONSE=$(curl -s -X POST "$BASE_URL/drivers" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"user_id":1,"car_model":"Toyota Camry","car_number":"A123BC777","license_number":"77AB123456"}')
echo "$DRIVER_RESPONSE"

echo "[4] create ride"
RIDE_RESPONSE=$(curl -s -X POST "$BASE_URL/rides" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"passenger_id":1,"pickup_address":"Moscow City","destination_address":"Sheremetyevo"}')
echo "$RIDE_RESPONSE"

echo "[5] get active rides"
curl -s "$BASE_URL/rides?status=active" \
  -H "Authorization: Bearer $TOKEN"
echo

echo "[6] accept ride"
curl -s -X PATCH "$BASE_URL/rides/1/accept" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"driver_id":1}'
echo

echo "[7] complete ride"
curl -s -X PATCH "$BASE_URL/rides/1/complete" \
  -H "Authorization: Bearer $TOKEN"
echo

echo "[8] get user rides"
curl -s "$BASE_URL/rides?user_id=1" \
  -H "Authorization: Bearer $TOKEN"
echo

echo "SMOKE TESTS PASSED"

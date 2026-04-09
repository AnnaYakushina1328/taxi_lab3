#include "taxi_storage.hpp"

#include <userver/storages/postgres/exceptions.hpp>

namespace taxi {

namespace {

using userver::storages::postgres::ClusterHostType;
namespace pg = userver::storages::postgres;

constexpr auto kInsertUser = R"sql(
    INSERT INTO users (login, password, full_name)
    VALUES ($1, $2, $3)
    RETURNING id, login, password, full_name
)sql";

constexpr auto kSelectUserById = R"sql(
    SELECT id, login, password, full_name
    FROM users
    WHERE id = $1
)sql";

constexpr auto kSelectUserByLogin = R"sql(
    SELECT id, login, password, full_name
    FROM users
    WHERE login = $1
)sql";

constexpr auto kFindUsersByMask = R"sql(
    SELECT id, login, password, full_name
    FROM users
    WHERE lower(full_name) LIKE '%' || lower($1) || '%'
    ORDER BY id
)sql";

constexpr auto kInsertDriver = R"sql(
    INSERT INTO drivers (user_id, car_model, car_number, license_number, status)
    VALUES ($1, $2, $3, $4, 'online')
    RETURNING id, user_id, car_model, car_number, license_number, status
)sql";

constexpr auto kSelectDriverById = R"sql(
    SELECT id, user_id, car_model, car_number, license_number, status
    FROM drivers
    WHERE id = $1
)sql";

constexpr auto kSelectDriverByUserId = R"sql(
    SELECT id, user_id, car_model, car_number, license_number, status
    FROM drivers
    WHERE user_id = $1
)sql";

constexpr auto kSelectActiveDrivers = R"sql(
    SELECT id, user_id, car_model, car_number, license_number, status
    FROM drivers
    WHERE status = 'online'
    ORDER BY id
)sql";

constexpr auto kUpdateDriverStatus = R"sql(
    UPDATE drivers
    SET status = $2
    WHERE id = $1
    RETURNING id, user_id, car_model, car_number, license_number, status
)sql";

constexpr auto kInsertRide = R"sql(
    INSERT INTO rides (passenger_id, pickup_address, destination_address, status)
    VALUES ($1, $2, $3, 'searching')
    RETURNING id,
              passenger_id,
              COALESCE(driver_id, 0) AS driver_id,
              pickup_address,
              destination_address,
              status
)sql";

constexpr auto kSelectRideById = R"sql(
    SELECT id,
           passenger_id,
           COALESCE(driver_id, 0) AS driver_id,
           pickup_address,
           destination_address,
           status
    FROM rides
    WHERE id = $1
)sql";

constexpr auto kSelectRidesByUserId = R"sql(
    SELECT id,
           passenger_id,
           COALESCE(driver_id, 0) AS driver_id,
           pickup_address,
           destination_address,
           status
    FROM rides
    WHERE passenger_id = $1
    ORDER BY created_at DESC, id DESC
)sql";

constexpr auto kSelectActiveRides = R"sql(
    SELECT id,
           passenger_id,
           COALESCE(driver_id, 0) AS driver_id,
           pickup_address,
           destination_address,
           status
    FROM rides
    WHERE status IN ('searching', 'accepted')
    ORDER BY id
)sql";

constexpr auto kAcceptRide = R"sql(
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
        RETURNING id,
                  passenger_id,
                  COALESCE(driver_id, 0) AS driver_id,
                  pickup_address,
                  destination_address,
                  status
    )
    SELECT *
    FROM updated_ride
)sql";

constexpr auto kCompleteRide = R"sql(
    WITH updated_ride AS (
        UPDATE rides
        SET status = 'completed',
            completed_at = NOW()
        WHERE id = $1
          AND status = 'accepted'
        RETURNING id,
                  passenger_id,
                  COALESCE(driver_id, 0) AS driver_id,
                  pickup_address,
                  destination_address,
                  status
    ),
    updated_driver AS (
        UPDATE drivers
        SET status = 'online'
        WHERE id = (SELECT driver_id FROM updated_ride)
        RETURNING id
    )
    SELECT *
    FROM updated_ride
)sql";

std::string MakeToken(int user_id, int token_id) {
  return "token-" + std::to_string(user_id) + "-" + std::to_string(token_id);
}

User ParseUser(const pg::Row& row) {
  User user;
  user.id = row["id"].As<int>();
  user.login = row["login"].As<std::string>();
  user.password = row["password"].As<std::string>();
  user.full_name = row["full_name"].As<std::string>();
  return user;
}

Driver ParseDriver(const pg::Row& row) {
  Driver driver;
  driver.id = row["id"].As<int>();
  driver.user_id = row["user_id"].As<int>();
  driver.car_model = row["car_model"].As<std::string>();
  driver.car_number = row["car_number"].As<std::string>();
  driver.license_number = row["license_number"].As<std::string>();
  driver.status = row["status"].As<std::string>();
  return driver;
}

Ride ParseRide(const pg::Row& row) {
  Ride ride;
  ride.id = row["id"].As<int>();
  ride.passenger_id = row["passenger_id"].As<int>();
  ride.driver_id = row["driver_id"].As<int>();
  ride.pickup_address = row["pickup_address"].As<std::string>();
  ride.destination_address = row["destination_address"].As<std::string>();
  ride.status = row["status"].As<std::string>();
  return ride;
}

}  // namespace

TaxiStorage::TaxiStorage(pg::ClusterPtr pg_cluster)
    : pg_cluster_(std::move(pg_cluster)) {}

std::optional<User> TaxiStorage::CreateUser(const std::string& login,
                                            const std::string& password,
                                            const std::string& full_name) {
  try {
    const auto res = pg_cluster_->Execute(ClusterHostType::kMaster, kInsertUser,
                                          login, password, full_name);
    if (res.IsEmpty()) {
      return std::nullopt;
    }
    return ParseUser(res[0]);
  } catch (const pg::UniqueViolation&) {
    return std::nullopt;
  }
}

std::optional<User> TaxiStorage::GetUserById(int user_id) const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectUserById, user_id);
  if (res.IsEmpty()) {
    return std::nullopt;
  }
  return ParseUser(res[0]);
}

std::optional<User> TaxiStorage::GetUserByLogin(const std::string& login) const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectUserByLogin, login);
  if (res.IsEmpty()) {
    return std::nullopt;
  }
  return ParseUser(res[0]);
}

std::vector<User> TaxiStorage::FindUsersByNameMask(
    const std::string& name_mask) const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kFindUsersByMask, name_mask);

  std::vector<User> result;
  result.reserve(res.Size());
  for (const auto& row : res) {
    result.push_back(ParseUser(row));
  }
  return result;
}

std::optional<std::string> TaxiStorage::Login(const std::string& login,
                                              const std::string& password) {
  const auto user = GetUserByLogin(login);
  if (!user || user->password != password) {
    return std::nullopt;
  }

  std::lock_guard<std::mutex> lock(token_mutex_);
  const std::string token = MakeToken(user->id, next_token_id_++);
  tokens_[token] = user->id;
  return token;
}

bool TaxiStorage::IsTokenValid(const std::string& token) const {
  std::lock_guard<std::mutex> lock(token_mutex_);
  return tokens_.find(token) != tokens_.end();
}

std::optional<Driver> TaxiStorage::CreateDriver(
    int user_id, const std::string& car_model, const std::string& car_number,
    const std::string& license_number) {
  try {
    const auto res = pg_cluster_->Execute(ClusterHostType::kMaster, kInsertDriver,
                                          user_id, car_model, car_number,
                                          license_number);
    if (res.IsEmpty()) {
      return std::nullopt;
    }
    return ParseDriver(res[0]);
  } catch (const pg::UniqueViolation&) {
    return std::nullopt;
  } catch (const pg::ForeignKeyViolation&) {
    return std::nullopt;
  }
}

std::optional<Driver> TaxiStorage::GetDriverById(int driver_id) const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectDriverById, driver_id);
  if (res.IsEmpty()) {
    return std::nullopt;
  }
  return ParseDriver(res[0]);
}

std::optional<Driver> TaxiStorage::GetDriverByUserId(int user_id) const {
  const auto res = pg_cluster_->Execute(ClusterHostType::kSlave,
                                        kSelectDriverByUserId, user_id);
  if (res.IsEmpty()) {
    return std::nullopt;
  }
  return ParseDriver(res[0]);
}

std::vector<Driver> TaxiStorage::GetActiveDrivers() const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectActiveDrivers);

  std::vector<Driver> result;
  result.reserve(res.Size());
  for (const auto& row : res) {
    result.push_back(ParseDriver(row));
  }
  return result;
}

std::optional<Driver> TaxiStorage::UpdateDriverStatus(int driver_id,
                                                      const std::string& status) {
  const auto res = pg_cluster_->Execute(ClusterHostType::kMaster,
                                        kUpdateDriverStatus, driver_id, status);
  if (res.IsEmpty()) {
    return std::nullopt;
  }
  return ParseDriver(res[0]);
}

std::optional<Ride> TaxiStorage::CreateRide(
    int passenger_id, const std::string& pickup_address,
    const std::string& destination_address) {
  try {
    const auto res = pg_cluster_->Execute(ClusterHostType::kMaster, kInsertRide,
                                          passenger_id, pickup_address,
                                          destination_address);
    if (res.IsEmpty()) {
      return std::nullopt;
    }
    return ParseRide(res[0]);
  } catch (const pg::ForeignKeyViolation&) {
    return std::nullopt;
  }
}

std::optional<Ride> TaxiStorage::GetRideById(int ride_id) const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectRideById, ride_id);
  if (res.IsEmpty()) {
    return std::nullopt;
  }
  return ParseRide(res[0]);
}

std::vector<Ride> TaxiStorage::GetRidesByUserId(int user_id) const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectRidesByUserId, user_id);

  std::vector<Ride> result;
  result.reserve(res.Size());
  for (const auto& row : res) {
    result.push_back(ParseRide(row));
  }
  return result;
}

std::vector<Ride> TaxiStorage::GetActiveRides() const {
  const auto res =
      pg_cluster_->Execute(ClusterHostType::kSlave, kSelectActiveRides);

  std::vector<Ride> result;
  result.reserve(res.Size());
  for (const auto& row : res) {
    result.push_back(ParseRide(row));
  }
  return result;
}

std::optional<Ride> TaxiStorage::AcceptRide(int ride_id, int driver_id) {
  auto transaction =
      pg_cluster_->Begin("taxi_accept_ride", ClusterHostType::kMaster, {});

  const auto res = transaction.Execute(kAcceptRide, ride_id, driver_id);
  if (res.IsEmpty()) {
    transaction.Rollback();
    return std::nullopt;
  }

  const auto ride = ParseRide(res[0]);
  transaction.Commit();
  return ride;
}

std::optional<Ride> TaxiStorage::CompleteRide(int ride_id) {
  auto transaction =
      pg_cluster_->Begin("taxi_complete_ride", ClusterHostType::kMaster, {});

  const auto res = transaction.Execute(kCompleteRide, ride_id);
  if (res.IsEmpty()) {
    transaction.Rollback();
    return std::nullopt;
  }

  const auto ride = ParseRide(res[0]);
  transaction.Commit();
  return ride;
}

}  // namespace taxi

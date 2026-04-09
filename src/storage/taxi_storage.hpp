#pragma once

#include <mutex>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

#include <userver/storages/postgres/cluster.hpp>

#include "../models/driver.hpp"
#include "../models/ride.hpp"
#include "../models/user.hpp"

namespace taxi {

class TaxiStorage {
 public:
  explicit TaxiStorage(userver::storages::postgres::ClusterPtr pg_cluster);

  std::optional<User> CreateUser(const std::string& login,
                                 const std::string& password,
                                 const std::string& full_name);

  std::optional<User> GetUserById(int user_id) const;
  std::optional<User> GetUserByLogin(const std::string& login) const;
  std::vector<User> FindUsersByNameMask(const std::string& name_mask) const;

  std::optional<std::string> Login(const std::string& login,
                                   const std::string& password);
  bool IsTokenValid(const std::string& token) const;

  std::optional<Driver> CreateDriver(int user_id,
                                     const std::string& car_model,
                                     const std::string& car_number,
                                     const std::string& license_number);

  std::optional<Driver> GetDriverById(int driver_id) const;
  std::optional<Driver> GetDriverByUserId(int user_id) const;
  std::vector<Driver> GetActiveDrivers() const;
  std::optional<Driver> UpdateDriverStatus(int driver_id,
                                           const std::string& status);

  std::optional<Ride> CreateRide(int passenger_id,
                                 const std::string& pickup_address,
                                 const std::string& destination_address);

  std::optional<Ride> GetRideById(int ride_id) const;
  std::vector<Ride> GetRidesByUserId(int user_id) const;
  std::vector<Ride> GetActiveRides() const;
  std::optional<Ride> AcceptRide(int ride_id, int driver_id);
  std::optional<Ride> CompleteRide(int ride_id);

 private:
  userver::storages::postgres::ClusterPtr pg_cluster_;

  mutable std::mutex token_mutex_;
  int next_token_id_{1};
  std::unordered_map<std::string, int> tokens_;
};

}  // namespace taxi

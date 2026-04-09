#pragma once

#include <string>

namespace taxi {

struct Ride {
  int id{};
  int passenger_id{};
  int driver_id{};
  std::string pickup_address;
  std::string destination_address;
  std::string status{"searching"};
};

}  // namespace taxi

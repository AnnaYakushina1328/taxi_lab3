#pragma once

#include <string>

namespace taxi {

struct Driver {
  int id{};
  int user_id{};
  std::string car_model;
  std::string car_number;
  std::string license_number;
  std::string status{"online"};
};

}  // namespace taxi

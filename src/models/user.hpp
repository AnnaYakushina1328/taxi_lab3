#pragma once

#include <string>

namespace taxi {

struct User {
  int id{};
  std::string login;
  std::string password;
  std::string full_name;
};

}  // namespace taxi

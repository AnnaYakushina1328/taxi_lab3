#pragma once

#include <userver/components/component_config.hpp>
#include <userver/components/component_context.hpp>
#include <userver/components/loggable_component_base.hpp>
#include <userver/yaml_config/schema.hpp>

#include "taxi_storage.hpp"

namespace taxi {

class TaxiStorageComponent final
    : public userver::components::LoggableComponentBase {
 public:
  static constexpr std::string_view kName = "taxi-storage";

  TaxiStorageComponent(const userver::components::ComponentConfig& config,
                       const userver::components::ComponentContext& context);

  TaxiStorage& GetStorage();
  const TaxiStorage& GetStorage() const;

  static userver::yaml_config::Schema GetStaticConfigSchema();

 private:
  TaxiStorage storage_;
};

}  // namespace taxi

#include "taxi_storage_component.hpp"

#include <userver/storages/postgres/component.hpp>
#include <userver/yaml_config/merge_schemas.hpp>

namespace taxi {

TaxiStorageComponent::TaxiStorageComponent(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context)
    : userver::components::LoggableComponentBase(config, context),
      storage_(context.FindComponent<userver::components::Postgres>("postgres-db")
                   .GetCluster()) {}

TaxiStorage& TaxiStorageComponent::GetStorage() {
  return storage_;
}

const TaxiStorage& TaxiStorageComponent::GetStorage() const {
  return storage_;
}

userver::yaml_config::Schema TaxiStorageComponent::GetStaticConfigSchema() {
  return userver::yaml_config::MergeSchemas<
      userver::components::LoggableComponentBase>(R"(
type: object
description: PostgreSQL-backed taxi storage component
additionalProperties: false
properties: {}
)");
}

}  // namespace taxi

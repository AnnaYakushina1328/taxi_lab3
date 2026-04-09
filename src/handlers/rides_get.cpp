#include "rides_get.hpp"

#include <userver/formats/json/serialize.hpp>
#include <userver/formats/json/value_builder.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/yaml_config/merge_schemas.hpp>

namespace taxi {

RidesGet::RidesGet(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context)
    : HttpHandlerBase(config, context),
      storage_(context.FindComponent<TaxiStorageComponent>().GetStorage()) {
}

std::string RidesGet::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto user_id_arg = request.GetArg("user_id");
  const auto status = request.GetArg("status");

  userver::formats::json::ValueBuilder result(userver::formats::common::Type::kArray);

  if (!user_id_arg.empty()) {
    const int user_id = std::stoi(user_id_arg);
    const auto rides = storage_.GetRidesByUserId(user_id);

    for (const auto& ride : rides) {
      userver::formats::json::ValueBuilder item;
      item["id"] = ride.id;
      item["passenger_id"] = ride.passenger_id;
      item["driver_id"] = ride.driver_id;
      item["pickup_address"] = ride.pickup_address;
      item["destination_address"] = ride.destination_address;
      item["status"] = ride.status;
      result.PushBack(item.ExtractValue());
    }

    return userver::formats::json::ToString(result.ExtractValue());
  }

  if (status == "active") {
    const auto rides = storage_.GetActiveRides();

    for (const auto& ride : rides) {
      userver::formats::json::ValueBuilder item;
      item["id"] = ride.id;
      item["passenger_id"] = ride.passenger_id;
      item["driver_id"] = ride.driver_id;
      item["pickup_address"] = ride.pickup_address;
      item["destination_address"] = ride.destination_address;
      item["status"] = ride.status;
      result.PushBack(item.ExtractValue());
    }

    return userver::formats::json::ToString(result.ExtractValue());
  }

  response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
  userver::formats::json::ValueBuilder error;
  error["error"] = "user_id or status=active query parameter is required";
  return userver::formats::json::ToString(error.ExtractValue());
}

userver::yaml_config::Schema RidesGet::GetStaticConfigSchema() {
  return userver::yaml_config::MergeSchemas<
      userver::server::handlers::HttpHandlerBase>(R"(
type: object
description: get rides handler
additionalProperties: false
properties: {}
)");
}

}  // namespace taxi

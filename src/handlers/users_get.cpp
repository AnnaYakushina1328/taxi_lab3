#include "users_get.hpp"

#include <userver/formats/json/serialize.hpp>
#include <userver/formats/json/value_builder.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/yaml_config/merge_schemas.hpp>

namespace taxi {

UsersGet::UsersGet(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context)
    : HttpHandlerBase(config, context),
      storage_(context.FindComponent<TaxiStorageComponent>().GetStorage()) {
}

std::string UsersGet::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto login = request.GetArg("login");
  const auto name_mask = request.GetArg("name_mask");

  if (!login.empty()) {
    const auto user = storage_.GetUserByLogin(login);
    if (!user) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      userver::formats::json::ValueBuilder error;
      error["error"] = "user not found";
      return userver::formats::json::ToString(error.ExtractValue());
    }

    userver::formats::json::ValueBuilder result;
    result["id"] = user->id;
    result["login"] = user->login;
    result["full_name"] = user->full_name;
    return userver::formats::json::ToString(result.ExtractValue());
  }

  if (!name_mask.empty()) {
    const auto users = storage_.FindUsersByNameMask(name_mask);

    userver::formats::json::ValueBuilder result(userver::formats::common::Type::kArray);
    for (const auto& user : users) {
      userver::formats::json::ValueBuilder item;
      item["id"] = user.id;
      item["login"] = user.login;
      item["full_name"] = user.full_name;
      result.PushBack(item.ExtractValue());
    }

    return userver::formats::json::ToString(result.ExtractValue());
  }

  response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
  userver::formats::json::ValueBuilder error;
  error["error"] = "login or name_mask query parameter is required";
  return userver::formats::json::ToString(error.ExtractValue());
}

userver::yaml_config::Schema UsersGet::GetStaticConfigSchema() {
  return userver::yaml_config::MergeSchemas<
      userver::server::handlers::HttpHandlerBase>(R"(
type: object
description: get users handler
additionalProperties: false
properties: {}
)");
}

}  // namespace taxi

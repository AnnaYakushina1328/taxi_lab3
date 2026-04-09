#include "auth_login.hpp"

#include <userver/formats/json.hpp>
#include <userver/formats/json/serialize.hpp>
#include <userver/formats/json/value_builder.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/yaml_config/merge_schemas.hpp>

namespace taxi {

AuthLogin::AuthLogin(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context)
    : HttpHandlerBase(config, context),
      storage_(context.FindComponent<TaxiStorageComponent>().GetStorage()) {
}

std::string AuthLogin::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto json = userver::formats::json::FromString(request.RequestBody());

  const auto login = json["login"].As<std::string>();
  const auto password = json["password"].As<std::string>();

  if (login.empty() || password.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    userver::formats::json::ValueBuilder error;
    error["error"] = "login and password are required";
    return userver::formats::json::ToString(error.ExtractValue());
  }

  const auto token = storage_.Login(login, password);
  if (!token) {
    response.SetStatus(userver::server::http::HttpStatus::kUnauthorized);
    userver::formats::json::ValueBuilder error;
    error["error"] = "invalid credentials";
    return userver::formats::json::ToString(error.ExtractValue());
  }

  userver::formats::json::ValueBuilder result;
  result["token"] = *token;
  return userver::formats::json::ToString(result.ExtractValue());
}

userver::yaml_config::Schema AuthLogin::GetStaticConfigSchema() {
  return userver::yaml_config::MergeSchemas<
      userver::server::handlers::HttpHandlerBase>(R"(
type: object
description: auth login handler
additionalProperties: false
properties: {}
)");
}

}  // namespace taxi

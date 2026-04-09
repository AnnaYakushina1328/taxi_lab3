#pragma once

#include <memory>
#include <string_view>

#include <userver/components/component_config.hpp>
#include <userver/components/component_context.hpp>
#include <userver/server/handlers/http_handler_base.hpp>
#include <userver/server/middlewares/http_middleware_base.hpp>

#include "../storage/taxi_storage_component.hpp"

namespace taxi {

class AuthMiddleware final : public userver::server::middlewares::HttpMiddlewareBase {
 public:
  AuthMiddleware(const userver::server::handlers::HttpHandlerBase&,
                 TaxiStorage& storage);

 private:
  void HandleRequest(userver::server::http::HttpRequest& request,
                     userver::server::request::RequestContext& context) const override;

  bool IsPublicRequest(const userver::server::http::HttpRequest& request) const;

  TaxiStorage& storage_;
};

class AuthMiddlewareFactory final
    : public userver::server::middlewares::HttpMiddlewareFactoryBase {
 public:
  static constexpr std::string_view kName{"auth-middleware"};

  AuthMiddlewareFactory(const userver::components::ComponentConfig& config,
                        const userver::components::ComponentContext& context);

 private:
  std::unique_ptr<userver::server::middlewares::HttpMiddlewareBase> Create(
      const userver::server::handlers::HttpHandlerBase& handler,
      userver::yaml_config::YamlConfig middleware_config) const override;

  TaxiStorage& storage_;
};

}  // namespace taxi

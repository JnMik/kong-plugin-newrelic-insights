-- load the base plugin object and create a subclass
local plugin = require("kong.plugins.base_plugin"):extend()

-- local debug = require "kong.plugins.newrelic-insights.debug"
local http = require "resty.http"
local JSON = require "kong.plugins.newrelic-insights.json"
local basic_serializer = require "kong.plugins.log-serializers.basic"

-- constructor
function plugin:new()
  plugin.super.new(self, "newrelic-insights")
end

---[[ runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
  plugin.super.access(self)

  local requestEnvelop = basic_serializer.serialize(ngx)
  local client = http.new()
  ngx.req.read_body() -- Populate get_body_data()

  -- debug.log_r("==============================================================");
  -- debug.log_r(requestEnvelop);
  -- debug.log_r("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");

  local params = {
    eventType = "kong_api_gateway_request",
    headers_host =  requestEnvelop.request.headers.host,
    headers_contentLength = requestEnvelop.request.headers["content-length"],
    headers_userAgent = requestEnvelop.request.headers["user-agent"],
    headers_accept = requestEnvelop.request.headers["accept"],
    headers_contentType = requestEnvelop.request.headers["content-type"],
    request_method = requestEnvelop.request.method,
    request_route =  requestEnvelop.request["request_uri"],
    request_size =  requestEnvelop.request["size"],
    client_ip =  requestEnvelop["client_ip"],
    config_api_name = requestEnvelop.api["name"],
    config_api_https_only = requestEnvelop.api["https_only"],
    config_api_preserve_host = requestEnvelop.api["preserve_host"],
    config_api_upstream_connect_timeout = requestEnvelop.api["upstream_connect_timeout"],
    config_api_upstream_read_timeout = requestEnvelop.api["api_upstream_read_timeout"],
    config_api_upstream_send_timeout = requestEnvelop.api["api_upstream_send_timeout"],
    config_api_strip_uri = requestEnvelop.api["strip_uri"],
    config_api_upstream_url = requestEnvelop.api["upstream_url"],
    latencies_request = requestEnvelop.latencies["request"],
    latencies_kong = requestEnvelop.latencies["kong"],
    latencies_proxy = requestEnvelop.latencies["proxy"],
    response_status = requestEnvelop.response["status"],
    response_size = requestEnvelop.response["size"],
    started_at = requestEnvelop["started_at"],
    bodyData = ngx.req.get_body_data()
  };

  -- Add querystring variables as data column
  for key,value in pairs(requestEnvelop.request.querystring) do
    params[key] = value
  end

  if plugin_conf.environment_name ~= nil then
    params['environment_name'] = plugin_conf.environment_name
  end

  if ngx.ctx.authenticated_consumer == nil then
    params['authenticated_user'] = "NOT AUTHENTICATED";
  else
    params['authenticated_user'] = ngx.ctx.authenticated_consumer;
  end

  if plugin_conf.account_id ~= nil and plugin_conf.api_key ~= nil then

    client:set_timeout(30000)

    local ok, err = client:connect("insights-collector.newrelic.com", 443);
    if not ok then
      ngx.log(ngx.STDERR, "Could not connect to newrelic insights API", err);
    else

      local ok, err = client:ssl_handshake(false, "insights-collector.newrelic.com", false)
      if not ok then
        ngx.log(ngx.STDERR, "Could not perform SSL handshake with Newrelic Insight", err);
        return
      end

      local res, err = client:request {
        method = "POST",
        path = "/v1/accounts/" .. plugin_conf.account_id .. "/events",
        body = JSON.stringify(params),
        headers = {
          ["Content-Type"] = "application/json",
          ["X-Insert-Key"] = plugin_conf.api_key
        }
      }

      if not res then
        ngx.log(ngx.STDERR, "Could not send http logs to Newrelic Insights", err);
      end
    end
  end

end

---[[ runs in the 'header_filter_by_lua_block'
function plugin:header_filter(plugin_conf)
  plugin.super.access(self)
end


-- set the plugin priority, which determines plugin execution order
plugin.PRIORITY = 1000

-- return our plugin object
return plugin
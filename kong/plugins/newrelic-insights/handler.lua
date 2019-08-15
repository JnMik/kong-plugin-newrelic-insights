-- load the base plugin object and create a subclass
local plugin = require("kong.plugins.base_plugin"):extend()

-- local debug = require "kong.plugins.newrelic-insights.debug"
local http = require "resty.http"
local JSON = require "kong.plugins.newrelic-insights.json"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local body_data;
local authenticated_consumer;

-- constructor
function plugin:new()
  plugin.super.new(self, "newrelic-insights")
end

---[[ runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
  plugin.super.access(self)

  ngx.req.read_body(); -- Populate get_body_data()
  -- Fetch body data while API cosockets are enabled
  plugin.body_data = ngx.req.get_body_data();

  if ngx.ctx.authenticated_consumer == nil then
    plugin.authenticated_consumer = "NOT AUTHENTICATED";
  else
    plugin.authenticated_consumer = ngx.ctx.authenticated_consumer.username;
  end

end

local function recordEvent(premature, plugin_conf, requestEnvelop)

  if premature then
    return
  end

  local client = http.new()

  local params = {
    eventType = "kong_api_gateway_request",
    headers_host =  requestEnvelop.request.headers.host,
    headers_contentLength = requestEnvelop.request.headers["content-length"],
    headers_userAgent = requestEnvelop.request.headers["user-agent"],
    headers_accept = requestEnvelop.request.headers["accept"],
    headers_contentType = requestEnvelop.request.headers["content-type"],
    request = requestEnvelop.request,
    config_route = requestEnvelop.route,
    config_service = requestEnvelop.service,
    latencies = requestEnvelop.latencies,
    response = requestEnvelop.response,
    started_at = requestEnvelop["started_at"],
    body_data = plugin.body_data,
    authenticated_consumer = plugin.authenticated_consumer
  };

  -- Add querystring variables as data column
  for key,value in pairs(requestEnvelop.request.querystring) do
    -- Don't record the api_key in newrelic_insights
    if(key ~= 'api_key') then
      params[key] = value;
    end
  end

  if plugin_conf.environment_name ~= nil then
    params['environment_name'] = plugin_conf.environment_name
  end

  -- debug.log_r("==============================================================");
  -- debug.log_r(params);
  -- debug.log_r("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");


  if plugin_conf.account_id ~= nil and plugin_conf.api_key ~= nil then

    client:set_timeout(30000)

    local ok, err = client:connect(plugin_conf.api_endpoint_hostname, 443);
    if not ok then
      ngx.log(ngx.STDERR, "Could not connect to newrelic insights API at host " .. plugin_conf.api_endpoint_hostname, err);
    else

      local ok, err = client:ssl_handshake(false, plugin_conf.api_endpoint_hostname, false)
      if not ok then
        ngx.log(ngx.STDERR, "Could not perform SSL handshake with Newrelic Insight at host " .. plugin_conf.api_endpoint_hostname, err);
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

function plugin:log(plugin_conf)
  plugin.super.log(self)

  local requestEnvelop = basic_serializer.serialize(ngx);

  -- trigger logging method with ngx_timer, a workaround to enable API
  local ok, err = ngx.timer.at(0, recordEvent, plugin_conf, requestEnvelop)
  if not ok then
    ngx.log(ngx.STDERR, "Fail to create timer", err);
  end

end

-- set the plugin priority, which determines plugin execution order
plugin.PRIORITY = 1000

-- return our plugin object
return plugin
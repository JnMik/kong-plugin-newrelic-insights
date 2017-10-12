-- local find = string.find
-- local function check_for_value(value)
--   for i, entry in ipairs(value) do
--     local ok = find(entry, ":")
--     if not ok then
--       return false, "key '" .. entry .. "' has no value"
--     end
--   end
--   return true
-- end
--
return {
  no_consumer = false, -- this plugin is available on APIs as well as on Consumers,
  fields = {
    -- Describe your plugin's configuration's schema here.
    api_key = { type = "string", default = {} },
    account_id = { type = "string", default = {} },
    environment_name = { type = "string", required = false, default = nil }
  },
  -- self_check = function(schema, plugin_t, dao, is_updating)
  --   -- perform any custom verification
  --   return true
  -- end
}

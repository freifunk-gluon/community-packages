local function authorize(http)
  local addr = http:getenv('REMOTE_ADDR')

  if addr == '127.0.0.1' or addr == '::1' then
    return nil, { identity = addr }
  end

  return 'not using localhost ip'
end

local function detect (http)
  local err, _ = authorize(http)
  if not err then
    return true
  end
end

return {
  name = 'local',
  display = 'Local',
  detect = detect,
  authorize = authorize,
}

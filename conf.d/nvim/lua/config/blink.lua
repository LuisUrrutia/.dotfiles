local M = {}

function M.ensure()
  local blink = require("blink.cmp")
  if blink.library_available() then
    return true
  end

  local ok, built = pcall(function()
    return blink.build({ force = true }):pwait(120000)
  end)

  return ok and built == true and blink.library_available()
end

return M

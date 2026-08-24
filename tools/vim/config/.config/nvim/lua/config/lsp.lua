local M = {}

local function load_packages()
  require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim" } })

  local registry = require("mason-registry")
  local refreshed, refresh_error = registry.refresh()
  if refreshed == false then
    error(("Mason registry refresh failed: %s"):format(refresh_error))
  end

  local mappings = require("mason-lspconfig").get_mappings().lspconfig_to_package
  local servers = require("mason-lspconfig.settings").current.ensure_installed
  local packages = {}
  for _, server in ipairs(servers) do
    local server_name, version = server:match("^([^@]+)@?(.*)$")
    local package_name = mappings[server_name]
    if not package_name then
      error(("Mason has no package mapping for LSP server %q"):format(server_name))
    end

    packages[#packages + 1] = {
      name = package_name,
      specifier = version == "" and package_name or package_name .. "@" .. version,
    }
  end

  return registry, packages
end

local function install(packages)
  if #packages == 0 then
    return true
  end

  local specifiers = vim.tbl_map(function(package)
    return package.specifier
  end, packages)
  vim.cmd("MasonInstall --quiet " .. table.concat(specifiers, " "))

  local registry = require("mason-registry")
  for _, package in ipairs(packages) do
    if not registry.is_installed(package.name) then
      return false
    end
  end

  return true
end

local function run(action)
  local ok, result = pcall(action)
  if not ok then
    vim.api.nvim_err_writeln(tostring(result))
    return false
  end

  return result
end

function M.ensure()
  return run(function()
    local registry, packages = load_packages()
    local missing = vim.tbl_filter(function(package)
      return not registry.is_installed(package.name)
    end, packages)

    return install(missing)
  end)
end

function M.update()
  return run(function()
    local registry, packages = load_packages()
    local outdated = vim.tbl_filter(function(package)
      local mason_package = registry.get_package(package.name)
      return not mason_package:is_installed()
        or mason_package:get_installed_version() ~= mason_package:get_latest_version()
    end, packages)

    return install(outdated)
  end)
end

return M

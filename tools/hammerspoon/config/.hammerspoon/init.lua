hs.logger.defaultLogLevel = 'info'

local bluetooth_sleep_manager = require('modules.bluetooth_sleep_manager')
bluetooth_sleep_manager.start()

local caffeinate_at_home = require('modules.caffeinate_at_home')
caffeinate_at_home.start({ 'Shadow', 'Monarch' })

hs.shutdownCallback = function()
    caffeinate_at_home.stop()
end

local bindings = require('bindings')
bindings.bind()

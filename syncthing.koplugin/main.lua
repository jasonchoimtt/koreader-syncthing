local DataStorage = require("datastorage")
local Device =  require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")  -- luacheck:ignore
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = ffiutil.template

local path = DataStorage:getFullDataDir()
if not util.pathExists("dropbear") then
    return { disabled = true, }
end

local Syncthing = WidgetContainer:extend{
    name = "Syncthing",
    is_doc_only = false,
}

local pid_path = "/tmp/syncthing_koreader.pid"

function Syncthing:init()
    self.syncthing_port = G_reader_settings:readSetting("syncthing_port") or "8384"
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

function Syncthing:start()
    local cmd = string.format("%s %s",
        "./plugins/syncthing.koplugin/start-syncthing",
        self.syncthing_port)

    -- Make a hole in the Kindle's firewall
    if Device:isKindle() then
        os.execute(string.format("%s %s %s",
            "iptables -A INPUT -p tcp --dport", self.syncthing_port,
            "-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"))
        os.execute(string.format("%s %s %s",
            "iptables -A OUTPUT -p tcp --sport", self.syncthing_port,
            "-m conntrack --ctstate ESTABLISHED -j ACCEPT"))
    end

    if not util.pathExists(path.."/settings/syncthing/") then
        os.execute("mkdir "..path.."/settings/syncthing")
    end
    logger.dbg("[Syncthing] Launching Syncthing : ", cmd)
    if os.execute(cmd) == 0 then
        local info = InfoMessage:new{
                timeout = 10,
                -- @translators: %1 is the Syncthing port, %2 is the network info.
                text = T(_("Syncthing started.\n\nSyncthing port: %1\n%2"),
                    self.syncthing_port,
                    Device.retrieveNetworkInfo and Device:retrieveNetworkInfo() or _("Could not retrieve network info.")),
        }
        UIManager:show(info)
    else
        local info = InfoMessage:new{
                icon = "notice-warning",
                text = _("Failed to start Syncthing."),
        }
        UIManager:show(info)
    end
end

function Syncthing:isRunning()
    return util.pathExists(pid_path)
end

function Syncthing:stop()
    os.execute("cat "..pid_path.." | xargs kill")
    UIManager:show(InfoMessage:new {
        text = T(_("Syncthing stopped.")),
        timeout = 2,
    })

    if self:isRunning() then
        os.remove(pid_path)
    end

    -- Plug the hole in the Kindle's firewall
    if Device:isKindle() then
        os.execute(string.format("%s %s %s",
            "iptables -D INPUT -p tcp --dport", self.syncthing_port,
            "-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"))
        os.execute(string.format("%s %s %s",
            "iptables -D OUTPUT -p tcp --sport", self.syncthing_port,
            "-m conntrack --ctstate ESTABLISHED -j ACCEPT"))
    end
end

function Syncthing:onToggleSyncthingServer()
    if self:isRunning() then
        self:stop()
    else
        self:start()
    end
end

function Syncthing:show_port_dialog(touchmenu_instance)
    self.port_dialog = InputDialog:new{
        title = _("Choose Syncthing port"),
        input = self.syncthing_port,
        input_type = "number",
        input_hint = self.syncthing_port,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(self.port_dialog)
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        local value = tonumber(self.port_dialog:getInputText())
                        if value and value >= 0 then
                            self.syncthing_port = value
                            G_reader_settings:saveSetting("syncthing_port", self.syncthing_port)
                            UIManager:close(self.port_dialog)
                            touchmenu_instance:updateItems()
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(self.port_dialog)
    self.port_dialog:onShowKeyboard()
end

function Syncthing:addToMainMenu(menu_items)
    menu_items.syncthing = {
        text = _("Syncthing"),
        sub_item_table = {
            {
                text = _("Syncthing"),
                keep_menu_open = true,
                checked_func = function() return self:isRunning() end,
                callback = function(touchmenu_instance)
                    self:onToggleSyncthingServer()
                    touchmenu_instance:updateItems()
                end,
            },
            {
                text_func = function()
                    return T(_("Syncthing port (%1)"), self.syncthing_port)
                end,
                keep_menu_open = true,
                enabled_func = function() return not self:isRunning() end,
                callback = function(touchmenu_instance)
                    self:show_port_dialog(touchmenu_instance)
                end,
            },
            {
                text = _("Syncthing web GUI"),
                keep_menu_open = true,
                enabled_func = function() return self:isRunning() end,
                callback = function()
                    local info = InfoMessage:new{
                        timeout = 60,
                        text = T(_("Connect to port %1 for web GUI\n%2"),
                            self.syncthing_port,
                            Device.retrieveNetworkInfo and Device:retrieveNetworkInfo() or _("Could not retrieve network info.")),
                    }
                    UIManager:show(info)
                end,
            },
       }
    }
end

function Syncthing:onDispatcherRegisterActions()
    Dispatcher:registerAction("toggle_syncthing_server", { category = "none", event = "ToggleSyncthingServer", title = _("Toggle Syncthing"), general=true})
end

require("insert_menu")

return Syncthing

local DataStorage = require("datastorage")
local Device =  require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")  -- luacheck:ignore
local QRMessage = require("ui/widget/qrmessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")
local socketutil = require("socketutil")
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
local config_path = "settings/syncthing/config.xml"
local device_id_path = "settings/syncthing/device-id"

function Syncthing:init()
    self.syncthing_port = G_reader_settings:readSetting("syncthing_port") or "8384"
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

function Syncthing:start()
    local cmd = string.format("%s %s",
        "./plugins/syncthing.koplugin/start-syncthing",
        self.syncthing_port)

    -- Start loopback interface so that we can access the Syncthing API later
    if Device:isKobo() then
        if os.execute("ifconfig lo up") ~= 0 then
            local info = InfoMessage:new{
                    icon = "notice-warning",
                    text = _("Failed to start Syncthing."),
            }
            UIManager:show(info)
            return
        end
    end

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

-- Function copied from newsdownloader.plugin
function Syncthing:deserializeXMLString(xml_str)
    -- uses LuaXML https://github.com/manoelcampos/LuaXML
    -- The MIT License (MIT)
    -- Copyright (c) 2016 Manoel Campos da Silva Filho
    -- see: koreader/plugins/newsdownloader.koplugin/lib/LICENSE_LuaXML
    local treehdl = require("lib/handler")
    local libxml = require("lib/xml")
    -- Instantiate the object that parses the XML file as a Lua table.
    local xmlhandler = treehdl.simpleTreeHandler()

    -- Remove UTF-8 byte order mark, as it will cause LuaXML to fail
    xml_str = xml_str:gsub("^\xef\xbb\xbf", "", 1)

    -- Instantiate the object that parses the XML to a Lua table.
    local ok = pcall(function()
            libxml.xmlParser(xmlhandler):parse(xml_str)
    end)
    if not ok then return end
    return xmlhandler.root
end

function Syncthing:readConfig()
    local file = io.open(config_path, "r")
    if not file then return nil end
    local xml_str = file:read("a")
    file:close()

    return self:deserializeXMLString(xml_str)
end

function Syncthing:getDeviceId()
    local file = io.open(device_id_path, "r")
    if not file then return nil end
    local device_id = file:read("l")
    file:close()

    return device_id
end

function Syncthing:apiCall(api_path, method, source)
    local config = self:readConfig()
    if not config then
        error("Cannot extract API key")
    end
    local apiKey = config["configuration"]["gui"]["apikey"]

    if not method then
        method = "GET"
    end

    local url = string.format("http://127.0.0.1:8384/rest/%s", api_path)

    logger.dbg("Syncthing: url:", url)
    local sink = {}
    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    local code, headers, status = socket.skip(1, http.request({
        url     = url,
        method  = method,
        source  = source,
        sink    = ltn12.sink.table(sink),
        headers = {
            ["X-API-Key"] = apiKey
        }
    }))
    socketutil:reset_timeout()

    if code ~= 200 then
        logger.dbg("Syncthing: HTTP response code <> 200. Response status:", status or code)
        logger.dbg("Syncthing: Response headers:", headers)
        return nil
    end
    return table.concat(sink)
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
                    return T(_("Syncthing port: %1"), self.syncthing_port)
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
                        text = T(_("Connect to port %1 for web GUI\n\n%2"),
                            self.syncthing_port,
                            Device.retrieveNetworkInfo and Device:retrieveNetworkInfo() or _("Could not retrieve network info.")),
                    }
                    UIManager:show(info)
                end,
            },
            {
                text_func = function()
                    local device_id = self:getDeviceId()
                    return T(_("Device ID: %1"), device_id or "Unknown")
                end,
                keep_menu_open = true,
                callback = function()
                    local device_id = self:getDeviceId()

                    local info = InfoMessage:new{
                        timeout = 60,
                        text = device_id or "Unknown"
                    }
                    UIManager:show(info)
                end,
            },
            {
                text = _("Show QR Code"),
                keep_menu_open = true,
                callback = function()
                    local device_id = self:getDeviceId()

                    if device_id then
                        local info = QRMessage:new{
                            text = device_id,
                            width = Device.screen:getWidth(),
                            height = Device.screen:getHeight()
                        }
                        UIManager:show(info)
                    end
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

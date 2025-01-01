local utils = require("utils")

local tw, th = term.getSize()

local protocol = "email"
local hostname = "tuah"

local server_utc_hour_offset = -6
local server_timezone = "CDT"

local destruct = function (tbl, ...)
    local insert = table.insert
    local values = {}
    for _, name in ipairs {...} do
        insert (values, tbl[name])
    end
    return unpack(values)
end

local load_libs = function(lib_paths, ...)
    local _libs = {}
    for k, v in pairs(lib_paths) do
        if not fs.exists(shell.resolve("./" .. k .. ".lua")) then
            shell.run("wget", v)
        end
        _libs[k] = require(k)
    end
    return destruct(_libs, ...)
end

local parse_msg = function(evt)
    local msg, sender = evt[3], evt[2]
    local evt_sep_idx = string.find(msg, "|")
    if evt_sep_idx == nil then error("Invalid message format") end
    local parsed = {
        ["evt"] = string.sub(msg, 1, evt_sep_idx),
        ["data"] = textutils.unserialise(string.sub(msg, evt_sep_idx + 1)),
        ["sender"] = sender
    }
    return parsed
end

local clean_exit = function()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    return 0
end

local events = {
    hello = "hello|",
    list_emails = "list|",
    delete_email = "delete|",
    mark_email_read = "read|",
    mark_email_unread = "unread|",
    new_email = "newemail|"
}

local events_valuemapped = {}
for k, v in pairs(events) do
    events_valuemapped[v] = k
end

local send_msg = function(event, payload, id)
    if not events_valuemapped[event] then error("Unrecognized event type " .. event) end
    rednet.send(id, event .. textutils.serialise(payload), protocol)
end

if not rednet.isOpen() then
    peripheral.find("modem", rednet.open)
end

return {
    protocol = protocol,
    hostname = hostname,
    server_utc_hour_offset = server_utc_hour_offset,
    server_timezone = server_timezone,
    destruct = destruct,
    load_libs = load_libs,
    parse_msg = parse_msg,
    send_msg = send_msg,
    events = events,
    clean_exit = clean_exit,
    tw = tw,
    th = th,
    round = utils.round,
    clamp = utils.clamp,
    pagify = utils.pagify,
    get_sorted_keys = utils.get_sorted_keys,
    first_to_upper = utils.first_to_upper,
    random_id = utils.random_id
}

package.path = package.path .. ";/auth/?.lua"

local utils = require("email_utils")
local auth = require("auth_client")

local client_paste = "pastebin run LSdUFXvx client"
local server_paste = "pastebin run LSdUFXvx server"
local version_file = "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/version"
local update_check = function(is_client)
    print("checking for updates")
    local version = http.get(version_file).readLine()
    local check_file = shell.resolve("/email/version")
    local need_update = false
    if not fs.exists(check_file) then
        need_update = true
    else
        local f = fs.open(check_file, "r")
        if f.readLine() ~= version then
            need_update = true
        end
        f.close()
    end
    if need_update then
        print("need to update")
        local pwd = shell.dir()
        if string.find(pwd, "/email") then
            fs.move(pwd, shell.resolve("../_email"))
            shell.setDir(shell.resolve(".."))
            if is_client then
                print("downloading client files" .. client_paste)
                shell.run(client_paste)
            else
                print("downloading client files" .. server_paste)
                shell.run(server_paste)
                if fs.isDir(shell.resolve("../_email/persistence")) then
                    fs.move(shell.resolve("../_email/persistence"), shell.resolve("."))
                end
            end
            fs.delete(shell.resolve("../_email"))
        else
            shell.setDir(shell.resolve("/"))
            if is_client then
                shell.run(client_paste)
            else
                shell.run(server_paste)
                if fs.isDir(shell.resolve(pwd .. "/persistence")) then
                    fs.move(shell.resolve(pwd .. "/persistence"), shell.resolve("."))
                    fs.delete(shell.resolve(pwd .. "/persistence"))
                end
            end
        end
        print("writing new version")
        local f = fs.open(check_file, "w+")
        f.write(version)
        f.close()
        print("update done")
    else
        print("no update needed")
    end
end

local tw, th = term.getSize()

local protocol = "email"
local hostname = "tuah"

local server_utc_hour_offset = -6
local server_timezone = "CDT"

local destruct = function(tbl, ...)
    local insert = table.insert
    local values = {}
    for _, name in ipairs { ... } do
        insert(values, tbl[name])
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
    new_email = "newemail|",
    stale_session = "stale_session|"
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
    update_check = update_check,
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
    random_id = utils.random_id,
    auth = auth
}

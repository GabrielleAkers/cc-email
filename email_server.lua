local shared = require("email_shared")
local events = shared.events
local auth = shared.auth

shared.update_check(false)

local lib_paths = {
    ["deque"] = "https://raw.githubusercontent.com/catwell/cw-lua/refs/heads/master/deque/deque.lua"
}

local deque = shared.load_libs(lib_paths, "deque")

local poll_rate = 10 -- 100ths of second

local evt_queue = deque.new()

local run_server = true

local process_os_events = function()
    local evt
    while true do
        evt = { os.pullEvent() }
        if evt[1] == "rednet_message" then
            if evt[4] == shared.protocol then
                local parsed = shared.parse_msg(evt)
                evt_queue:push_right(parsed)
            end
        elseif evt[1] == "key" then
            if keys.getName(evt[2]) == "q" then
                run_server = false
                rednet.unhost(shared.protocol)
                return shared.clean_exit()
            end
        end
    end
end

local emails

local save_to_disk = function()
    local backups_dir = shell.resolve("./persistence")
    if not fs.isDir(backups_dir) then
        fs.makeDir(backups_dir)
    end
    local email_file = fs.open(backups_dir .. "/emails", "w")
    email_file.write(textutils.serialise(emails))
    email_file.close()
end

local read_from_disk = function()
    local backups_dir = shell.resolve("./persistence")
    if not fs.exists(backups_dir .. "/emails") then return {} end
    local email_file = fs.open(backups_dir .. "/emails", "r")
    local contents = email_file.readAll()
    email_file.close()
    return textutils.unserialise(contents)
end

emails = read_from_disk()

local handle_hello = function(evt)
    print(os.time() .. " got hello from " .. evt.data.sender)
    if not emails[evt.data.sender] then
        emails[evt.data.sender] = {
            ["received"] = {},
            ["sent"] = {}
        }
    end
    save_to_disk()
end

local handle_list_emails = function(evt)
    if not auth.check_token(evt.data.user, evt.data.token, function() print("user doesnt exist in auth system") end) then
        return shared.send_msg(events.stale_session, {}, evt.sender)
    end

    print(os.time() .. " got list_emails from " .. evt.data.sender)
    local _emails = {}
    if emails[evt.data.sender] then
        for _, v in pairs(emails[evt.data.sender]["received"]) do
            if not v.deleted then
                _emails[#_emails + 1] = v
            end
        end
    end
    shared.send_msg(events.list_emails, _emails, evt.sender)
end

local handle_delete_email = function(evt)
    if not auth.check_token(evt.data.user, evt.data.token, function() print("user doesnt exist in auth system") end) then
        return shared.send_msg(events.stale_session, {}, evt.sender)
    end

    local email_id = evt.data.id
    print(os.time() .. " got delete_email id " .. email_id .. " from " .. evt.data.sender)
    if emails[evt.data.sender] then
        for _, v in pairs(emails[evt.data.sender]["received"]) do
            if v.id == email_id then
                v.deleted = true
            end
        end
    end
    save_to_disk()
end

local handle_mark_email_read = function(evt)
    if not auth.check_token(evt.data.user, evt.data.token, function() print("user doesnt exist in auth system") end) then
        return shared.send_msg(events.stale_session, {}, evt.sender)
    end

    local email_id = evt.data.id
    print(os.time() .. " got mark_read id " .. email_id .. " from " .. evt.data.sender)
    if emails[evt.data.sender] then
        for _, v in pairs(emails[evt.data.sender]["received"]) do
            if v.id == email_id then
                v.read = true
            end
        end
    end
    save_to_disk()
end

local handle_mark_email_unread = function(evt)
    if not auth.check_token(evt.data.user, evt.data.token, function() print("user doesnt exist in auth system") end) then
        return shared.send_msg(events.stale_session, {}, evt.sender)
    end

    local email_id = evt.data.id
    print(os.time() .. " got mark_unread id " .. email_id .. " from " .. evt.data.sender)
    if emails[evt.data.sender] then
        for _, v in pairs(emails[evt.data.sender]["received"]) do
            if v.id == email_id then
                v.read = false
            end
        end
    end
    save_to_disk()
end

local handle_new_email = function(evt)
    if not auth.check_token(evt.data.user, evt.data.token, function() print("user doesnt exist in auth system") end) then
        return shared.send_msg(events.stale_session, {}, evt.sender)
    end

    local er = {
        id = shared.random_id(10),
        to = evt.data.to,
        from = evt.data.sender,
        subject = evt.data.subject,
        body = evt.data.body,
        utc_timestamp = os.epoch("utc"),
        read = false,
        deleted = false
    }
    local es = {
        id = shared.random_id(10),
        to = evt.data.to,
        from = evt.data.sender,
        subject = evt.data.subject,
        body = evt.data.body,
        utc_timestamp = os.epoch("utc"),
    }
    print(os.time() .. " got new mail from " .. evt.data.sender .. " to " .. evt.data.to)
    if emails[evt.data.sender] then
        emails[evt.data.sender]["sent"][#emails[evt.data.sender]["sent"] + 1] = es
    end
    if emails[evt.data.to] then
        emails[evt.data.to]["received"][#emails[evt.data.to]["received"] + 1] = er
    end
    save_to_disk()
end

local event_handlers = {
    [events.hello] = handle_hello,
    [events.list_emails] = handle_list_emails,
    [events.delete_email] = handle_delete_email,
    [events.mark_email_read] = handle_mark_email_read,
    [events.mark_email_unread] = handle_mark_email_unread,
    [events.new_email] = handle_new_email
}

local process_events = function()
    local evt, timer
    while true do
        if evt_queue:is_empty() then
            sleep(poll_rate / 100)
        else
            local next_event = evt_queue:pop_left()
            if event_handlers[next_event.evt] then
                event_handlers[next_event.evt](next_event)
            end
        end
    end
end

while run_server do
    rednet.host(shared.protocol, shared.hostname)
    parallel.waitForAny(
        process_os_events,
        process_events
    )
end

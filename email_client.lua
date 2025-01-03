local shared = require("email_shared")
local ui = require("email_ui")
local events = shared.events
local auth = shared.auth

shared.update_check(true)

local tw, th = shared.destruct(shared, "tw", "th")

local server_id = rednet.lookup(shared.protocol, shared.hostname)

if server_id then
    print("Connected to server " .. shared.protocol .. "@" .. shared.hostname)
else
    return error("cannot find server")
end

local client_states = {
    main = {},
    exiting = {}
}
local client_state = client_states.main

-- override orange to be red since its unused in the theme
term.setPaletteColor(colors.orange, 0xCC0000)

local format_email_date = function(ts)
    local time_delta_seconds = (os.epoch("utc") - ts) / 1000
    local date
    if time_delta_seconds >= 86400 then
        date = os.date("%D", (ts / 1000) + (shared.server_utc_hour_offset * 3600)) -- 04/27/33
    else
        date = os.date("%R", (ts / 1000) + (shared.server_utc_hour_offset * 3600)) ..
            " " ..
            shared.server_timezone -- 14:33 CDT
    end
    return date
end

local format_email_string = function(email)
    if not email then return "" end
    -- we have 44 pixels to display email minus 2 for end padding and 4 for inter is 38
    local from_size = 8
    local subject_size = 18
    local sliced_from = string.sub(email.from, 1, from_size)
    local sliced_subject = string.sub(email.subject, 1, subject_size)
    local date = format_email_date(email.utc_timestamp)
    return " " ..
        sliced_from ..
        string.rep(" ", from_size - string.len(sliced_from) + 2) ..
        sliced_subject .. string.rep(" ", subject_size - string.len(sliced_subject) + 2) .. date .. " "
end

local unread_email_color = colors.lightGray
local read_email_color = colors.gray

local emails = {}

local emails_data = {}

local build_emails_data = function()
    local sorted_email_ids = shared.get_sorted_keys(emails, function(a, b) return a.utc_timestamp > b.utc_timestamp end)
    for _, key in ipairs(sorted_email_ids) do
        emails_data[#emails_data + 1] = {
            id = emails[key].id,
            btn_str = format_email_string(emails[key]),
            btn_color = emails[key].read and read_email_color or unread_email_color
        }
    end
end

local get_email_address = function()
    if auth.get_identity() then
        return auth.get_identity()["email"]
    else
        return error("not authed")
    end
end

local emails_updated, need_login

local selected_email_id = nil

local fetch_emails = function()
    emails = {}
    shared.send_msg(events.list_emails,
        { sender = get_email_address(), user = auth.get_identity().user, token = auth.get_identity().token }, server_id)
    emails_updated = false
end

if auth.get_identity() then
    fetch_emails()
end

local gui = function()
    term.clear()
    local needs_return = false

    if auth.get_identity() then
        shared.send_msg(events.hello, { sender = get_email_address() }, server_id)
    end

    local change_view, current_view

    local back_btn = function()
        ui.button(
            "back_btn",
            1, 1,
            3, 2,
            colors.lime, colors.green,
            2, 2,
            "<", colors.black,
            function()
                change_view("inbox")
                fetch_emails()
            end
        )
    end

    local login_view = function()
        ui.text(
            tw / 2 - 9, 2,
            "Login/Create Account", colors.white,
            colors.black
        )
        ui.horizontal_line(0, tw, 4, colors.white)
        ui.text(
            tw / 2 - 4, 6,
            "Username", colors.white,
            colors.black
        )
        ui.textbox(
            "username_textbox",
            tw / 2 - 7, 8, tw / 2 + 7, 8,
            colors.lightGray,
            tw / 2 - 7, 8, "", colors.black,
            false
        )
        ui.text(
            tw / 2 - 4, 10,
            "Password", colors.white,
            colors.black
        )
        ui.textbox(
            "password_textbox",
            tw / 2 - 7, 12, tw / 2 + 7, 12,
            colors.lightGray,
            tw / 2 - 7, 12, "", colors.black,
            false
        )
        local handle_bad_login = function()
            term.setCursorPos(tw / 2 - 7, 18)
            term.setTextColor(colors.white)
            term.write("Wrong user/pass")
        end
        ui.button(
            "login_btn",
            tw / 2 - 7, 14,
            tw / 2 + 7, 16,
            colors.lightBlue, colors.blue,
            tw / 2 - 3, 15,
            "Login", colors.black,
            function()
                local i = auth.login(
                    ui.get_textbox_value("username_textbox"),
                    ui.get_textbox_value("password_textbox"),
                    handle_bad_login
                )
                if i then
                    shared.send_msg(events.hello, { sender = get_email_address() }, server_id)
                    fetch_emails()
                    change_view("inbox")
                end
            end
        )
    end

    local inbox_view = function()
        local page_offset_override = 1
        ui.text(
            1, 2,
            get_email_address(), colors.green,
            colors.black
        )
        ui.text(
            tw / 2 - 3, 2,
            "Inbox", colors.white,
            colors.black
        )
        ui.horizontal_line(0, tw, 4, colors.white)
        local btn_col_x0, btn_col_x1, btn_col_y0, btn_col_y1 = 1, 6, 5, 7
        local render_scrollbox = function()
            ui.scrollbox(
                "emails_scrollbox",
                8, 5, tw, th,
                colors.lightGray, colors.purple, colors.black,
                colors.lightBlue, colors.blue,
                colors.black,
                emails_data,
                page_offset_override,
                function(data_id)
                    selected_email_id = data_id
                end,
                function(offset)
                    page_offset_override = offset
                end
            )
        end
        ui.button(
            "new_email_btn",
            btn_col_x0, btn_col_y0,
            btn_col_x1, btn_col_y1,
            colors.lightBlue, colors.blue,
            2, 6,
            "New", colors.black,
            function()
                change_view("compose")
            end
        )
        ui.button(
            "read_email_btn",
            btn_col_x0, btn_col_y0 + 3,
            btn_col_x1, btn_col_y1 + 3,
            colors.lightBlue, colors.blue,
            2, 9,
            "Read", colors.black,
            function()
                if selected_email_id then
                    shared.send_msg(events.mark_email_read,
                        {
                            sender = get_email_address(),
                            id = selected_email_id,
                            user = auth.get_identity().user,
                            token =
                                auth.get_identity().token
                        },
                        server_id)
                    change_view("read")
                end
            end
        )
        ui.button(
            "mark_read_email_btn",
            btn_col_x0, btn_col_y0 + 6,
            btn_col_x1, btn_col_y1 + 6,
            colors.lightBlue, colors.blue,
            2, 12,
            "Mark\n Read", colors.black,
            function()
                if selected_email_id then
                    shared.send_msg(events.mark_email_read,
                        {
                            sender = get_email_address(),
                            id = selected_email_id,
                            user = auth.get_identity().user,
                            token =
                                auth.get_identity().token
                        },
                        server_id)
                    fetch_emails()
                end
            end
        )
        ui.button(
            "refresh_email_btn",
            btn_col_x0, btn_col_y0 + 9,
            btn_col_x1, btn_col_y1 + 9,
            colors.lightBlue, colors.blue,
            2, 15,
            "Fetch", colors.black,
            function()
                fetch_emails()
            end
        )
        ui.button(
            "delete_email_btn",
            btn_col_x0, btn_col_y0 + 12,
            btn_col_x1, btn_col_y1 + 12,
            colors.lightBlue, colors.blue,
            2, 18,
            "Del", colors.black,
            function()
                if selected_email_id then
                    shared.send_msg(events.delete_email,
                        {
                            sender = get_email_address(),
                            id = selected_email_id,
                            user = auth.get_identity().user,
                            token =
                                auth.get_identity().token
                        },
                        server_id)
                    fetch_emails()
                end
            end
        )
        ui.vertical_line(7, 4, th, colors.white)
        render_scrollbox()
    end

    local compose_view = function()
        back_btn()
        ui.text(
            tw / 2 - 4, 2,
            "New Email", colors.white,
            colors.black
        )
        ui.horizontal_line(0, tw, 4, colors.white)
        ui.text(
            tw / 4 - 4, 6,
            "To", colors.white,
            colors.black
        )
        ui.textbox(
            "to_textbox",
            tw / 4 - 10, 8, tw / 4 + 4, 8,
            colors.lightGray,
            tw / 4 - 10, 8, "", colors.black,
            false
        )
        ui.text(
            tw / 4 - 7, 10,
            "Subject", colors.white,
            colors.black
        )
        ui.textbox(
            "subject_textbox",
            tw / 4 - 10, 12, tw / 4 + 4, 12,
            colors.lightGray,
            tw / 4 - 10, 12, "", colors.black,
            false
        )
        ui.button(
            "send_new_email_btn",
            tw / 4 - 10, 15, tw / 4 + 4, 17,
            colors.lightBlue, colors.blue,
            tw / 4 - 5, 16, "Send", colors.black,
            function()
                local to = ui.get_textbox_value("to_textbox") .. "@tuah"
                local sender = get_email_address()
                local sub = ui.get_textbox_value("subject_textbox")
                local body = ui.get_textbox_value("body_scrolltextbox")
                shared.send_msg(events.new_email,
                    { to = to, sender = sender, subject = sub, body = body, user = auth.get_identity().user, token = auth
                    .get_identity().token }, server_id)
            end
        )
        ui.vertical_line(18, 4, th, colors.white)
        ui.scrolltextbox(
            "body_scrolltextbox",
            19, 5, tw - 2, th, colors.lightGray, "", colors.black, colors.lightBlue, colors.blue
        )
    end

    local read_view = function()
        local page_offset_override = 1
        if not selected_email_id then
            change_view("inbox")
        end
        local email
        for _, v in pairs(emails) do
            if v.id == selected_email_id then
                email = v
            end
        end
        ui.text(
            tw / 2 - 20, 2,
            format_email_string(email), colors.white,
            colors.black
        )
        ui.horizontal_line(0, tw, 4, colors.white)
        local btn_col_x0, btn_col_x1, btn_col_y0, btn_col_y1 = 1, 7, 5, 7
        ui.button(
            "reply_email_btn",
            btn_col_x0, btn_col_y0,
            btn_col_x1, btn_col_y1,
            colors.lightBlue, colors.blue,
            2, 6,
            "Reply", colors.black,
            function()
                change_view("compose")
                ui.set_textbox_value("to_textbox", string.sub(email.from, 1, string.find(email.from, "@") - 1))
                local sub = email.subject
                local reply_idx = string.find(sub, "REPLY: ")
                if reply_idx then
                    sub = string.sub(sub, reply_idx)
                else
                    sub = "REPLY: " .. sub
                end
                ui.set_textbox_value("subject_textbox", sub)
            end
        )
        ui.vertical_line(8, 4, th, colors.white)

        ui.scrolltext(
            "read_email_scrolltext",
            10, 6, tw, th, colors.black, colors.white, email.body,
            colors.lightBlue, colors.blue,
            page_offset_override, function(offset) page_offset_override = offset end
        )

        back_btn()
    end

    current_view = auth.get_identity() ~= nil and "inbox" or "login"

    change_view = function(viewname)
        paintutils.drawFilledBox(0, 0, tw, th, colors.black)
        ui.clean()

        ui.button(
            "exit_btn",
            tw - 2, 1,
            tw, 2,
            colors.red, colors.orange,
            tw - 1, 2,
            "X", colors.black,
            function()
                client_state = client_states.exiting
                needs_return = true
            end
        )
        current_view = viewname
        if viewname == "login" then
            login_view()
        elseif viewname == "compose" then
            compose_view()
        elseif viewname == "read" then
            read_view()
        elseif viewname == "inbox" then
            inbox_view()
        end
    end

    change_view(current_view)

    local modifiers_held = {
        ["leftShift"] = false,
    }
    local special_key_handlers = {
        ["backspace"] = ui.backspace_focused_text,
        ["space"] = function() ui.update_focused_text(" ") end,
        ["leftShift"] = function(is_held) modifiers_held["leftShift"] = is_held end,
        ["leftCtrl"] = function() end,
        ["leftAlt"] = function() end,
        ["left"] = function() ui.shift_left_focused_text(1) end,
        ["right"] = function() ui.shift_right_focused_text(1) end,
        ["enter"] = ui.enter_focused_text,
    }
    local number_keys = {
        ["zero"] = 0,
        ["one"] = 1,
        ["two"] = 2,
        ["three"] = 3,
        ["four"] = 4,
        ["five"] = 5,
        ["six"] = 6,
        ["seven"] = 7,
        ["eight"] = 8,
        ["nine"] = 9
    }
    local punctuation_keys = {
        ["comma"] = ",",
        ["period"] = ".",
        ["slash"] = "/",
        ["backslash"] = "\\",
        ["minus"] = "-",
        ["equals"] = "=",
        ["tab"] = "    ",
        ["leftBracket"] = "[",
        ["rightBracket"] = "]",
    }

    local evt
    while true do
        if emails_updated then
            change_view(current_view)
            emails_updated = false
        end
        if need_login then
            change_view("login")
            need_login = false
        end
        evt = { os.pullEvent() }
        if evt[1] == "mouse_click" then
            ui.mousedown(evt[3], evt[4])
        elseif evt[1] == "mouse_up" then
            ui.mouseup(evt[3], evt[4])
        elseif evt[1] == "paste" then
            if ui.is_focused() then
                ui.set_focused_text(evt[2])
            end
        elseif evt[1] == "key" then
            local keyname = keys.getName(evt[2])
            if not ui.is_focused() then
                ui.keypress(keyname)
            else
                if special_key_handlers[keyname] then
                    special_key_handlers[keyname](true)
                else
                    local _keyname = keyname
                    if modifiers_held["leftShift"] then
                        _keyname = shared.first_to_upper(_keyname)
                    end
                    if number_keys[keyname] then
                        _keyname = number_keys[keyname]
                    end
                    if punctuation_keys[keyname] then
                        _keyname = punctuation_keys[keyname]
                    end
                    ui.update_focused_text(_keyname)
                end
            end
        elseif evt[1] == "keyup" then
            local keyname = keys.getName(evt[2])
            modifiers_held[keyname] = false
        end
        if needs_return then
            break
        end
    end
end

local handle_list_emails = function(evt)
    emails = {}
    emails = evt.data

    emails_data = {}
    build_emails_data()
    emails_updated = true
end

local handle_stale_session = function(evt)
    auth.logout(auth.get_identity().user, auth.get_identity().token)
    need_login = true
end

local event_handlers = {
    [events.list_emails] = handle_list_emails,
    [events.stale_session] = handle_stale_session
}

local process_rednet = function()
    local evt
    while true do
        evt = { os.pullEvent() }
        if evt[1] == "rednet_message" then
            if evt[4] == shared.protocol then
                local parsed = shared.parse_msg(evt)
                if event_handlers[parsed.evt] then
                    event_handlers[parsed.evt](parsed)
                    os.queueEvent("redraw") -- fake event to make the gui redraw
                end
            end
        end
    end
end

while true do
    if client_state == client_states.main then
        parallel.waitForAny(
            gui,
            process_rednet
        )
    elseif client_state == client_states.exiting then
        return shared.clean_exit()
    end
end

local utils = require("email_utils")

local clickables = {}

local registered_keys = {}

local focused = nil

local clear_clickables = function()
    clickables = {}
end

local clear_registeredkeys = function()
    registered_keys = {}
end

local outline_clickable = function(clickable_name, color)
    if not clickables[clickable_name] then return end

    local clickable = clickables[clickable_name]
    paintutils.drawBox(clickable.x0, clickable.y0, clickable.x1, clickable.y1, color)
end


local clean = function()
    clear_clickables()
    clear_registeredkeys()
    focused = nil
end

local text = function(
    tx, ty, txt, txt_color, bg_color
)
    term.setBackgroundColor(bg_color)
    term.setCursorPos(tx, ty)
    term.setTextColor(txt_color)
    write(txt)
end

local _render_box_with_txt = function(x0, y0, x1, y1, color, tx, ty, txt_color, txt)
    paintutils.drawFilledBox(x0, y0, x1, y1, color)
    text(tx, ty, txt, txt_color, color)
end

local textbox = function(
    name,
    x0, y0, x1, y1,
    bg_color,
    tx, ty, txt, txt_color,
    no_click
)
    local render = function()
        if clickables[name] then
            _render_box_with_txt(x0, y0, x1, y1, bg_color, tx, ty, txt_color,
                clickables[name].lvalue .. clickables[name].rvalue)
        else
            _render_box_with_txt(x0, y0, x1, y1, bg_color, tx, ty, txt_color, txt)
        end
    end
    local on_mousedown = function()
        if no_click then return end
        render()
    end
    local on_mouseup = function()
        if no_click then return end
        render()
        term.setCursorPos(tx, ty)
        term.setCursorBlink(true)
        focused = name
    end

    clickables[name] = {
        render = render,
        on_mousedown = on_mousedown,
        on_mouseup = on_mouseup,
        x0 = x0,
        y0 = y0,
        x1 = x1,
        y1 = y1,
        lvalue = txt,
        rvalue = ""
    }
    render()
end

local button = function(
    name,
    x0, y0, x1, y1,
    bg_color, click_color,
    tx, ty, txt, txt_color,
    onclick
)
    local render = function()
        _render_box_with_txt(x0, y0, x1, y1, bg_color, tx, ty, txt_color, txt)
    end
    local on_mousedown = function()
        _render_box_with_txt(x0, y0, x1, y1, click_color, tx, ty, txt_color, txt)
    end
    local on_mouseup = function()
        render()
        onclick()
    end

    clickables[name] = {
        render = render,
        on_mousedown = on_mousedown,
        on_mouseup = on_mouseup,
        x0 = x0,
        y0 = y0,
        x1 = x1,
        y1 = y1,
    }
    render()
end

local horizontal_line = function(
    x0, x1, y, color
)
    paintutils.drawFilledBox(x0, y, x1, y, color)
end

local vertical_line = function(
    x, y0, y1, color
)
    paintutils.drawFilledBox(x, y0, x, y1, color)
end

local scrollbox = function(
    name,
    x0, y0, x1, y1,
    bg_color, click_color, sep_color,
    scroll_bg_color, scroll_click_color,
    txt_color,
    data,
    page_offset_override,
    onselect,
    on_pageoffsetchange
)
    local height = y1 - y0
    local half_height = utils.round(height / 2)
    local el_height = 3
    local sep_height = 1
    local num_fit_no_sep = math.floor(height / el_height)
    -- number of elemnts including separators
    local els_per_page = math.floor((height - num_fit_no_sep - 1) / el_height)
    local scroll_x, scroll_y = x1 - 2, y0 + half_height

    local page_offset = page_offset_override

    local list_x0, list_x1 = x0, scroll_x
    local render = function()
        local render_scrollbox = function()
            paintutils.drawFilledBox(list_x0, y0, list_x1, y1, sep_color)
            for i = 0, els_per_page - 1 do
                clickables[name .. "_list_btn_" .. i] = nil
            end

            for i = 0, els_per_page - 1 do
                if not data[page_offset + i] then break end

                local sep = i ~= 0 and 1 or 0
                local ix0, iy0, ix1, iy1 = list_x0, y0 + i * el_height + i + sep * i, list_x1,
                    y0 + el_height + i * el_height + i + sep * i
                local btn_data_params = data[page_offset + i]
                button(
                    name .. "_list_btn_" .. i,
                    ix0, iy0, ix1, iy1,
                    btn_data_params.btn_color, click_color,
                    ix0 + 1, iy0 + 1, btn_data_params.btn_str, colors.black,
                    function()
                        onselect(btn_data_params.id)
                    end
                )
            end
        end

        button(
            name .. "_scroll_up",
            scroll_x + 1, y0, scroll_x + 2, scroll_y - 1,
            scroll_bg_color, scroll_click_color,
            scroll_x + 1, y0 + half_height / 2,
            "/\\", txt_color,
            function()
                if page_offset <= 1 then return end
                page_offset = utils.clamp(page_offset - els_per_page, 1, #data)
                on_pageoffsetchange(page_offset)
                onselect(nil)
                render_scrollbox()
            end
        )
        button(
            name .. "_scroll_down",
            scroll_x + 1, scroll_y + 1, scroll_x + 2, y1,
            scroll_bg_color, scroll_click_color,
            scroll_x + 1, y1 - half_height / 2 + 1,
            "\\/", txt_color,
            function()
                if page_offset >= #data then return end
                page_offset = utils.clamp(page_offset + els_per_page, 1, #data)
                on_pageoffsetchange(page_offset)
                onselect(nil)
                render_scrollbox()
            end
        )
        render_scrollbox()
    end

    render()
end

local scrolltext = function(
    name,
    x0, y0, x1, y1, bg_color, txt_color, data,
    scroll_bg_color, scroll_click_color, page_offset_override,
    on_pageoffsetchange
)
    local height = y1 - y0
    local half_height = utils.round(height / 2)
    -- number of elemnts including separators
    local els_per_page = height - 1
    local scroll_x, scroll_y = x1 - 2, y0 + half_height

    local page_offset = page_offset_override or 1

    local list_x0, list_x1 = x0, scroll_x
    local list_width = list_x1 - list_x0
    local paged_text = utils.pagify(data, list_width - 1)

    local render = function()
        local render_scrolltext
        render_scrolltext = function()
            paintutils.drawFilledBox(list_x0, y0, list_x1, y1, bg_color)
            for i = 0, els_per_page - 1 do
                if not paged_text[page_offset + i] then break end

                local ix0, iy0 = list_x0, y0 + (2 * i)
                text(
                    ix0, iy0, paged_text[page_offset + i], txt_color, bg_color
                )
            end
        end
        button(
            name .. "_scroll_up",
            scroll_x + 1, y0, scroll_x + 2, scroll_y - 1,
            scroll_bg_color, scroll_click_color,
            scroll_x + 1, y0 + half_height / 2,
            "/\\", txt_color,
            function()
                if page_offset == 1 then return end
                page_offset = utils.clamp(page_offset - 1, 1, #paged_text)
                on_pageoffsetchange(page_offset)
                render_scrolltext()
            end
        )
        button(
            name .. "_scroll_down",
            scroll_x + 1, scroll_y + 1, scroll_x + 2, y1,
            scroll_bg_color, scroll_click_color,
            scroll_x + 1, y1 - half_height / 2 + 1,
            "\\/", txt_color,
            function()
                if page_offset == #paged_text then return end
                page_offset = utils.clamp(page_offset + 1, 1, #paged_text)
                on_pageoffsetchange(page_offset)
                render_scrolltext()
            end
        )
        render_scrolltext()
    end

    render()
end

local scrolltextbox = function(
    name,
    x0, y0, x1, y1, bg_color, txt, txt_color,
    scroll_bg_color, scroll_click_color
)
    local page_offset_override = 1 or 1
    local on_pageoffsetchange = function(offset)
        page_offset_override = offset
    end
    local render = function()
        local _txt = clickables[name] ~= nil and clickables[name].lvalue .. clickables[name].rvalue or txt
        scrolltext(
            name .. "_scrolltext",
            x0, y0, x1 + 2, y1,
            bg_color,
            txt_color, _txt,
            scroll_bg_color, scroll_click_color,
            page_offset_override, on_pageoffsetchange
        )
    end
    local on_mousedown = function()
        render()
    end
    local on_mouseup = function()
        render()
        focused = name
    end

    clickables[name] = {
        render = render,
        on_mousedown = on_mousedown,
        on_mouseup = on_mouseup,
        x0 = x0,
        y0 = y0,
        x1 = x1,
        y1 = y1,
        lvalue = txt,
        rvalue = txt
    }
    render()
end

local last_mousedown = nil

local mousedown = function(mouse_x, mouse_y)
    for k, v in pairs(clickables) do
        if mouse_x >= v.x0 and mouse_x <= v.x1 and mouse_y >= v.y0 and mouse_y <= v.y1 then
            last_mousedown = k
            v.on_mousedown()
        end
    end
end

local mouseup = function(mouse_x, mouse_y)
    focused = nil
    term.setCursorBlink(false)
    for k, v in pairs(clickables) do
        if mouse_x >= v.x0 and mouse_x <= v.x1 and mouse_y >= v.y0 - 1 and mouse_y <= v.y1 then
            if last_mousedown == k then
                v.on_mouseup()
            end
        else
            if last_mousedown and clickables[last_mousedown] then
                clickables[last_mousedown].render()
            end
        end
    end
    last_mousedown = nil
end

local get_focused_cursor_pos = function()
    if not focused and not clickables[focused] then return end

    local c = clickables[focused]
    local paged_lval = utils.pagify(c.lvalue, (c.x1 - 2) - c.x0)
    return {
        x = c.x0 + string.len(c.lvalue),
        y = c.y0 + #paged_lval - 1
    }
end

local set_focused_cursor_pos = function()
    local p = get_focused_cursor_pos()
    term.setCursorPos(p.x, p.y)
    term.setCursorBlink(true)
end

local register_key = function(keyname, clickable_name)
    registered_keys[keyname] = clickable_name
end

local unregister_key = function(keyname)
    registered_keys[keyname] = nil
end

local keypress = function(keyname)
    if registered_keys[keyname] then
        local btn = clickables[registered_keys[keyname]]
        btn.on_mouseup()
    end
end

local set_focused_text = function(value)
    if not focused and not clickables[focused] then return end

    clickables[focused].lvalue = value
    clickables[focused].render()
    set_focused_cursor_pos()
end

local update_focused_text = function(value)
    if not focused and not clickables[focused] then return end

    clickables[focused].lvalue = clickables[focused].lvalue .. value
    clickables[focused].render()
    set_focused_cursor_pos()
end

local backspace_focused_text = function()
    if not focused and not clickables[focused] then return end

    set_focused_text(string.sub(clickables[focused].lvalue, 1, string.len(clickables[focused].lvalue) - 1))
end

local shift_left_focused_text = function(amount)
    if not focused and not clickables[focused] then return end

    local len_lval = string.len(clickables[focused].lvalue)
    local _amount = utils.clamp(amount, 0, len_lval)
    local lval = string.sub(clickables[focused].lvalue, 0, len_lval - _amount)
    local rval = string.sub(clickables[focused].lvalue, len_lval - _amount + 1) .. clickables[focused].rvalue
    clickables[focused].lvalue = lval
    clickables[focused].rvalue = rval
    set_focused_cursor_pos()
end

local shift_right_focused_text = function(amount)
    if not focused and not clickables[focused] then return end

    local len_rval = string.len(clickables[focused].rvalue)
    local _amount = utils.clamp(amount, 0, len_rval)
    local lval = clickables[focused].lvalue .. string.sub(clickables[focused].rvalue, 0, _amount)
    local rval = string.sub(clickables[focused].rvalue, _amount + 1)
    clickables[focused].lvalue = lval
    clickables[focused].rvalue = rval
    set_focused_cursor_pos()
end

local enter_focused_text = function()
    if not focused and not clickables[focused] then return end

    local c = clickables[focused]
    local lw = (c.x1 - 2) - c.x0
    update_focused_text(string.rep(" ", lw - string.len(c.lvalue) - 1))
end

local set_textbox_value = function(textbox_name, value)
    if not clickables[textbox_name] then return end

    clickables[textbox_name].lvalue = value
    clickables[textbox_name].render()
end

local get_textbox_value = function(textbox_name)
    if not clickables[textbox_name] then return nil end

    return clickables[textbox_name].lvalue .. clickables[textbox_name].rvalue
end

local is_focused = function()
    return focused ~= nil
end

local set_focused = function(clickable_name)
    focused = clickable_name
end

return {
    text = text,
    button = button,
    textbox = textbox,
    scrollbox = scrollbox,
    scrolltext = scrolltext,
    scrolltextbox = scrolltextbox,
    mousedown = mousedown,
    mouseup = mouseup,
    clear_clickables = clear_clickables,
    register_key = register_key,
    unregister_key = unregister_key,
    keypress = keypress,
    set_focused_text = set_focused_text,
    update_focused_text = update_focused_text,
    backspace_focused_text = backspace_focused_text,
    shift_left_focused_text = shift_left_focused_text,
    shift_right_focused_text = shift_right_focused_text,
    enter_focused_text = enter_focused_text,
    get_textbox_value = get_textbox_value,
    set_textbox_value = set_textbox_value,
    clean = clean,
    horizontal_line = horizontal_line,
    vertical_line = vertical_line,
    outline_clickable = outline_clickable,
    is_focused = is_focused,
    set_focused = set_focused
}

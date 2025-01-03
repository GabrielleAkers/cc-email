local round = function(x)
    return math.floor(x+0.5)
end

local clamp = function(x, min, max)
    if min > max then
        error("Min must be <= max", 0)
    end
    return math.max(min, math.min(x, max))
end

local pagify = function(text, width)
    if not text then return {} end
    local offset = 1
    local pages = {[1]=string.sub(text, offset, offset + width)}
    while true do
        if string.len(text) <= offset + width then
            return pages
        end
        offset = offset + width
        pages[#pages+1] = string.sub(text, offset, offset + width)
    end
end

local get_sorted_keys = function(tbl, sort_func)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b) return sort_func(tbl[a], tbl[b]) end)
    return keys
end

function first_to_upper(str)
    return (str:gsub("^%l", string.upper))
end

function random_id(len)
    math.randomseed(os.clock()) 
    local template = string.rep("x", len)
    return string.gsub(
        template,
        '[xy]',
        function(c)
            local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
            return string.format("%x", v)
        end
    )
end

return {
    round = round,
    clamp = clamp,
    pagify = pagify,
    get_sorted_keys = get_sorted_keys,
    first_to_upper = first_to_upper,
    random_id = random_id
}

local M = {}

local _cache = { dir = nil, entries = nil, err = nil }

local function fnmatch(name, pattern)
    if not (pattern:find('*', 1, true) or pattern:find('?', 1, true)) then
        return name == pattern
    end
    local re = {}
    local i = 1
    while i <= #pattern do
        local c = pattern:sub(i, i)
        if c == '*' then
            re[#re + 1] = '.*'
        elseif c == '?' then
            re[#re + 1] = '.'
        else
            re[#re + 1] = vim.pesc(c)
        end
        i = i + 1
    end
    return name:match('^' .. table.concat(re) .. '$') ~= nil
end

local function list_entries(libuv)
    local cwd = vim.loop.cwd()
    local entries = {}
    if libuv and libuv.fs_scandir then
        local handle = libuv.fs_scandir(cwd)
        if handle then
            local name
            while true do
                name = libuv.fs_scandir_next(handle)
                if not name then
                    break
                end
                -- Some builds return the name directly; others return a table.
                if type(name) == "table" and name.name ~= nil then
                    name = name.name
                end
                if name ~= nil and type(name) == "string" and name ~= "" then
                    entries[#entries + 1] = name
                end
            end
        else
            -- Fallback for builds without fs_scandir / fs_scandir_next.
            local seen, merged = {}, {}
            local function merge(list)
                for _, v in ipairs(list) do
                    if not seen[v] and v ~= "." and v ~= ".." then
                        seen[v] = true
                        merged[#merged + 1] = v
                    end
                end
            end
            merge(vim.fn.glob("*", false, true))
            merge(vim.fn.glob(".*", false, true))
            entries = merged
        end
    else
        local seen, merged = {}, {}
        local function merge(list)
            for _, v in ipairs(list) do
                if not seen[v] and v ~= "." and v ~= ".." then
                    seen[v] = true
                    merged[#merged + 1] = v
                end
            end
        end
        merge(vim.fn.glob("*", false, true))
        merge(vim.fn.glob(".*", false, true))
        entries = merged
    end
    return cwd, entries, nil
end

function M.list_cwd_entries()
    local cwd = vim.loop.cwd()
    if _cache.dir ~= cwd then
        local dir, entries, err = list_entries(vim.uv)
        _cache.dir = dir
        _cache.entries = entries or {}
        _cache.err = err
    end
    return _cache.entries, _cache.err
end

function M.is_directory_with_indicators(indicators)
    local entries = M.list_cwd_entries()
    if not entries then return false end
    for _, name in ipairs(entries) do
        for _, indicator in ipairs(indicators) do
            if fnmatch(name, indicator) then
                return true
            end
        end
    end
    return false
end

return M

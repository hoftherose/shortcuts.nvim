local json = require('shortcuts.utils.json')

local FileManager = {
    plugin_path = ''
}

function FileManager.setup(path)
    FileManager.plugin_path = path
end

local function full_path(fn)
    return FileManager.plugin_path .. fn
end

local function ensure_parent(full_fn)
    local dir = vim.fn.fnamemodify(full_fn, ':h')
    if dir ~= '' and dir ~= vim.fn.getcwd() and vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, 'p')
    end
end

function FileManager.touch(fn)
    local full_fn = full_path(fn)
    if vim.fn.filereadable(full_fn) == 1 then
        return full_fn
    end
    ensure_parent(full_fn)
    local f, err = io.open(full_fn, 'a')
    if f == nil then
        vim.api.nvim_err_writeln('Unable to create file: ' .. (err or 'unknown'))
        return nil
    end
    f:close()
    return full_fn
end

function FileManager.delete(fn)
    local full_fn = full_path(fn)
    if vim.fn.filereadable(full_fn) == 1 then
        vim.fn.delete(full_fn)
    end
end

function FileManager.read_file(fn)
    local full_fn = full_path(fn)
    if vim.fn.filereadable(full_fn) ~= 1 then
        return ''
    end
    return table.concat(vim.fn.readfile(full_fn), '\n')
end

function FileManager.write_file(fn, content)
    local full_fn = full_path(fn)
    ensure_parent(full_fn)
    local f, err = io.open(full_fn, 'w')
    if f == nil then
        vim.api.nvim_err_writeln('Unable to write to file: ' .. (err or 'unknown'))
        return
    end
    f:write(content)
    f:close()
end

function FileManager.is_empty(fn)
    local content = FileManager.read_file(fn)
    return content == '' or content == nil
end

function FileManager.fill_template(fn, content)
    FileManager.write_file(fn, json.encode(content))
end

function FileManager.is_invalid_json(fn)
    local content = FileManager.read_file(fn)
    return not xpcall(
        function()
            json.decode(content)
        end,
        function(err)
            vim.api.nvim_err_writeln('File ' .. full_path(fn) .. ' is invalid: ' .. tostring(err))
        end
    )
end

function FileManager.get_json(fn)
    local content = FileManager.read_file(fn)
    return json.decode(content)
end

return FileManager

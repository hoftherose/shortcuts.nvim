local template = require('shortcuts.templates')
local ui = require('shortcuts.ui')

local Shortcuts = {
    shortcuts = {},
    defaults_table = template.defaults,
    plugin_path = vim.fn.expand('$HOME/.local/share/nvim/shortcuts/'),
    prefix = '<leader>a'
}

local default_cache = {
    cached = false,
    value = nil
}

local commands_registered = false

function Shortcuts.is_invalid_shortcut(mode, keybind, shortcut)
    -- maparg is a single C call; no Ex-command spawn needed.
    -- Returns '' (truthy in Lua!) when absent, so compare explicitly.
    if vim.fn.maparg(Shortcuts.prefix .. keybind, mode) ~= '' then
        return true
    end
    if shortcut == nil then
        return true
    end
    if type(keybind) ~= 'string' then
        return true
    end
    return false
end

function Shortcuts.ensure_default_shortcuts()
    if not default_cache.cached then
        default_cache.value = template.generate_defaults(Shortcuts.defaults_table)
        default_cache.cached = true
    end
    return default_cache.value
end

function Shortcuts.get_project_shortcuts()
    local fm = require('shortcuts.utils.files')
    local fn = Shortcuts.get_current_project() .. '.json'
    if vim.fn.filereadable(Shortcuts.plugin_path .. fn) ~= 1 then
        -- First run in this project: materialize the defaults on disk.
        local defaults = Shortcuts.ensure_default_shortcuts()
        fm.touch(fn)
        fm.fill_template(fn, defaults)
        return defaults
    end
    if fm.is_invalid_json(fn) then
        return Shortcuts.ensure_default_shortcuts()
    end
    return fm.get_json(fn)
end

function Shortcuts.reset_project_shortcuts()
    local fn = Shortcuts.get_current_project() .. '.json'
    require('shortcuts.utils.files').delete(fn)
    return Shortcuts.get_project_shortcuts()
end

function Shortcuts.get_current_project()
    local cwd = vim.loop.cwd()
    local root = vim.fn.system('git rev-parse --show-toplevel')
    if vim.v.shell_error == 0 and root ~= nil and root ~= '' then
        local project = root:gsub('\n', ''):gsub('/', '.')
        return project
    end
    return string.gsub(cwd, '/', '.')
end

function Shortcuts.add_shortcut(mode, keybind, shortcut)
    if Shortcuts.is_invalid_shortcut(mode, keybind, shortcut) then
        vim.api.nvim_err_writeln('INVALID SHORTCUT: ' .. vim.inspect(shortcut))
        return
    end

    -- Command type mapping for keymap construction
    local command_map = {
        lua = ':lua ' .. shortcut.command .. '<CR>',
        nvim = ':' .. shortcut.command .. '<CR>',
        vim = ':' .. shortcut.command .. '<CR>',
        bash = ':lua vim.fn.system("' .. shortcut.command .. '")<CR>',
        keyinject = shortcut.command,
        background = ':AsyncRun ' .. shortcut.command .. '<CR>',
        terminal = ':AsyncRun -mode=term -focus=0 -pos=right -cols=50 -close ' .. shortcut.command .. '<CR>'
    }

    -- Handle backward compatibility for async commands
    if shortcut.command_type == 'async' then
        local notify_msg = '; notify-send "Warning" "Using async is now deprecated, use terminal or background instead" --icon=nvim --app-name="Nvim Alerts"'
        if shortcut.notify then
            notify_msg = '; notify-send "Async Runner" "Task finished: ' .. shortcut.command .. '" --icon=nvim --app-name="Nvim Alerts"' .. notify_msg
        end
        if shortcut.async_type == 'run' then
            vim.keymap.set(mode, Shortcuts.prefix .. keybind, ':AsyncRun ' .. shortcut.command .. notify_msg .. '<CR>')
        elseif shortcut.async_type == 'term' then
            vim.keymap.set(mode, Shortcuts.prefix .. keybind, ':AsyncRun -mode=term -focus=0 -pos=right -cols=50 -close ' .. shortcut.command .. '<CR>')
        else
            vim.api.nvim_err_writeln(shortcut.async_type .. ' is not a valid async type, defaulting to run')
            vim.keymap.set(mode, Shortcuts.prefix .. keybind, ':AsyncRun ' .. shortcut.command .. '<CR>')
        end
    elseif command_map[shortcut.command_type] then
        vim.keymap.set(mode, Shortcuts.prefix .. keybind, command_map[shortcut.command_type])
    else
        vim.api.nvim_err_writeln(shortcut.command_type .. ' is not a valid command type, defaulting to lua')
        vim.keymap.set(mode, Shortcuts.prefix .. keybind, ':lua ' .. shortcut.command .. '<CR>')
    end
end

function Shortcuts.show_ui()
    ui.ShowMenu()
end

function Shortcuts.hide_ui()
    ui.HideMenu()
end

function Shortcuts.setup(opts)
    require('shortcuts.utils.files').setup(Shortcuts.plugin_path)
    ui.setup(Shortcuts.plugin_path .. Shortcuts.get_current_project() .. '.json')

    if opts and opts.defaults then
        local new_defaults = template.generate_defaults(opts.defaults)
        if opts.override then
            Shortcuts.defaults_table = new_defaults
        else
            Shortcuts.defaults_table = vim.tbl_deep_extend(
                "force",
                Shortcuts.defaults_table,
                new_defaults
            )
        end
    end
    default_cache.cached = false
    default_cache.value = nil
    Shortcuts.set_shortcuts()
end

function Shortcuts.set_shortcuts()
    Shortcuts.shortcuts = Shortcuts.get_project_shortcuts()
    for mode, shortcut in pairs(Shortcuts.shortcuts) do
        for keybind, command in pairs(shortcut) do
            Shortcuts.add_shortcut(mode, keybind, command)
        end
    end
end

function Shortcuts.print_tools()
    local languages = require("shortcuts.directory.all")
    print(vim.inspect(languages.get_project_languages()))
end

local function register_commands()
    if commands_registered then
        return
    end
    commands_registered = true
    vim.api.nvim_create_user_command('ShortcutsToggle', 'lua require"shortcuts".show_ui()', {})
    vim.api.nvim_create_user_command('ShortcutsSetDefaults', 'lua require"shortcuts".reset_project_shortcuts()', {})
    vim.api.nvim_create_user_command('ShortcutsReset', 'lua require"shortcuts".set_shortcuts()', {})
    vim.api.nvim_create_user_command('ShortcutsListTools', 'lua require"shortcuts".print_tools()', {})
end

Shortcuts.register_commands = register_commands
register_commands()

return Shortcuts

local M = {
    layout_params = {
        position = "50%",
        size = {
            width = 80,
            height = "60%",
        },
    },
    project = '',
}

function M.setup(project)
    -- Lazy-load nui only when the UI is actually configured.
    local Popup = require("nui.popup")
    local Layout = require("nui.layout")
    local event = require("nui.utils.autocmd").event

    M.project = project
    M.popup = Popup({ enter = true, border = "single" })
    M.popup:on(event.BufLeave, function()
        vim.cmd(':silent write! ' .. M.project)
        vim.cmd(':ShortcutsReset')
        M.popup:unmount()
    end)
    M.popup:on(event.BufWinEnter, function()
        local lines = {}
        if vim.fn.filereadable(M.project) == 1 then
            lines = vim.fn.readfile(M.project)
        end
        vim.api.nvim_buf_set_lines(M.popup.bufnr, 0, -1, false, lines)
    end)
    M.layout = Layout(
        M.layout_params,
        Layout.Box({
            Layout.Box(M.popup, { size = "100%" }),
        }, { dir = "row" })
    )
    M.popup:map("n", "q", function()
        M.layout:hide()
    end, {})
end

function M.ShowMenu()
    if M.layout == nil then
        vim.api.nvim_err_writeln('Shortcuts UI is not set up; call require"shortcuts".setup() first.')
        return
    end
    M.layout:show()
end

function M.HideMenu()
    if M.layout == nil then
        return
    end
    M.layout:hide()
end

return M

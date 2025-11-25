local config = require("codecompanion.config")
local api = vim.api

local ok, MiniCompletion = pcall(require, "mini.completion")
if not ok then
    return vim.notify("[CodeCompanion]\nmini.completion is not installed", vim.log.levels.ERROR)
end

-- Create autocommand group for CodeCompanion completion triggers
local group = api.nvim_create_augroup("CodeCompanionMiniCompletion", { clear = true })

-- Set up auto-trigger on trigger characters
api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "codecompanion",
    callback = function(args)
        local bufnr = args.buf

        -- Auto-trigger completion when trigger characters are typed
        api.nvim_create_autocmd("TextChangedI", {
            group = group,
            buffer = bufnr,
            callback = function()
                -- Don't trigger if completion is already visible
                if vim.fn.pumvisible() == 1 then
                    return
                end

                local pos = api.nvim_win_get_cursor(0)
                local line = api.nvim_get_current_line()
                local col = pos[2]

                -- Check if we just typed a trigger character
                if col > 0 then
                    local char = line:sub(col, col)
                    local acp_trigger = config.strategies.chat.slash_commands.opts.acp.trigger or "\\"

                    -- Trigger characters: /, #, @, and ACP trigger (default \)
                    if char == "/" or char == "#" or char == "@" or char == acp_trigger then
                        -- Trigger completion after a short delay to ensure the character is inserted
                        vim.schedule(function()
                            if api.nvim_get_mode().mode == "i" then
                                local provider = require("codecompanion.providers.completion.mini")
                                provider.complete({})
                            end
                        end)
                    end
                end
            end,
        })
    end,
})

return true

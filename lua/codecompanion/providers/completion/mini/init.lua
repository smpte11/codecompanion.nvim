local api = vim.api
local config = require("codecompanion.config")

local M = {}

M.group = "CodeCompanionMiniCompletion"
M.source = nil

---Setup the completion source
---@return nil
function M.setup()
    require("codecompanion.providers.completion.mini.setup")
end

---Is the completion menu visible?
---@return boolean
function M.visible()
    return vim.fn.pumvisible() == 1
end

---Trigger a completion
---@param opts table
---@return nil
function M.complete(opts)
    opts = opts or {}

    local pos = api.nvim_win_get_cursor(0)
    local line = api.nvim_get_current_line()
    local line_to_cursor = line:sub(1, pos[2])

    -- Determine what type of completion to show based on trigger character
    local trigger_char = nil
    local acp_trigger = config.strategies.chat.slash_commands.opts.acp.trigger or "\\"

    -- Check for trigger characters
    for i = #line_to_cursor, math.max(1, #line_to_cursor - 10), -1 do
        local char = line_to_cursor:sub(i, i)
        if char == "/" or char == "#" or char == "@" or char == acp_trigger then
            trigger_char = char
            break
        elseif char:match("%s") then
            -- Stop at whitespace
            break
        end
    end

    if trigger_char then
        local completion = require("codecompanion.providers.completion")
        local items = {}

        if trigger_char == "/" then
            items = completion.slash_commands()
        elseif trigger_char == "#" then
            items = completion.variables()
        elseif trigger_char == "@" then
            items = completion.tools()
        elseif trigger_char == acp_trigger then
            items = completion.acp_commands(api.nvim_get_current_buf())
        end

        M.set_completions(items, { trigger = trigger_char })
    else
        -- Fallback to standard completion trigger
        local keys = api.nvim_replace_termcodes("<C-Space>", true, false, true)
        api.nvim_feedkeys(keys, "n", false)
    end
end

---Hide the completion menu
---@return nil
function M.hide()
    local MiniCompletion = require("mini.completion")
    MiniCompletion.stop()
end

---Accept a completion
---@param opts? table
---@return nil
function M.accept(opts)
    opts = opts or {}

    if not M.visible() then
        return
    end

    -- Simulate Ctrl-Y to accept completion
    local keys = api.nvim_replace_termcodes("<C-y>", true, false, true)
    api.nvim_feedkeys(keys, "n", false)
end

---Get the selected completion item
---@return table|nil
function M.get_selected()
    if not M.visible() then
        return nil
    end

    local info = vim.fn.complete_info({ "selected", "items" })
    if info.selected ~= -1 and info.items and info.items[info.selected + 1] then
        return info.items[info.selected + 1]
    end

    return nil
end

---Navigate to the next completion item
---@return nil
function M.next()
    if not M.visible() then
        M.complete()
        return
    end

    local keys = api.nvim_replace_termcodes("<C-n>", true, false, true)
    api.nvim_feedkeys(keys, "n", false)
end

---Navigate to the previous completion item
---@return nil
function M.prev()
    if not M.visible() then
        M.complete()
        return
    end

    local keys = api.nvim_replace_termcodes("<C-p>", true, false, true)
    api.nvim_feedkeys(keys, "n", false)
end

---Manually set completion items
---@param items table List of completion items
---@param opts? table Options for completion
---@return nil
function M.set_completions(items, opts)
    opts = opts or {}

    if not items or #items == 0 then
        return
    end

    -- Convert items to vim completion format
    local vim_items = vim.tbl_map(function(item)
        return {
            word = item.label or "",
            abbr = item.label or "",
            kind = item.type or "",
            menu = item.detail or "",
            info = item.detail or "",
            user_data = vim.fn.json_encode(item),
        }
    end, items)

    -- Get cursor position
    local pos = api.nvim_win_get_cursor(0)
    local line = api.nvim_get_current_line()
    local line_to_cursor = line:sub(1, pos[2])

    -- Find the start position (after the trigger character)
    local start_col = pos[2]
    local acp_trigger = config.strategies.chat.slash_commands.opts.acp.trigger or "\\"

    for i = #line_to_cursor, 1, -1 do
        local char = line_to_cursor:sub(i, i)
        if char == "/" or char == "#" or char == "@" or char == acp_trigger then
            start_col = i
            break
        end
    end

    -- Trigger completion with our items
    vim.fn.complete(start_col, vim_items)
end

---Execute a completion item
---@param item table The completion item to execute
---@param chat CodeCompanion.Chat
---@return nil
function M.execute(item, chat)
    if not item or not item.user_data then
        return
    end

    local completion_data
    if type(item.user_data) == "string" then
        local ok, decoded = pcall(vim.fn.json_decode, item.user_data)
        if ok then
            completion_data = decoded
        end
    else
        completion_data = item.user_data
    end

    if not completion_data then
        return
    end

    local completion = require("codecompanion.providers.completion")

    if completion_data.type == "slash_command" then
        completion.slash_commands_execute(completion_data, chat)
    elseif completion_data.type == "acp_command" then
        local text = completion.acp_commands_execute(completion_data)
        -- Insert the text at cursor
        local pos = api.nvim_win_get_cursor(0)
        local line = api.nvim_get_current_line()
        local new_line = line:sub(1, pos[2]) .. text .. line:sub(pos[2] + 1)
        api.nvim_set_current_line(new_line)
        api.nvim_win_set_cursor(0, { pos[1], pos[2] + #text })
    end
end

return M

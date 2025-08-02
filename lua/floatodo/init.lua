local Path = require('plenary.path')
local state = { win_num = -1, buf_num = -1 }
local M = {}

local data_dir = vim.fn.stdpath('data')

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.45)
  local height = opts.height or math.floor(vim.o.lines * 0.75)

  -- Calculate position to center of window
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  ---@type vim.api.keyset.win_config
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'single',
  }

  return win_config
end

---Expand path with tilde ~
---`~/projects` -> `$HOME/projects`
---@param path string
---@return string
local function expand_path(path)
  if path:sub(1, 1) == '~' then
    return os.getenv('HOME') .. path:sub(2)
  end
  return path
end

---comment
---@param target_file string
---@return integer
local function open_floating_window(target_file)
  local expanded_path = expand_path(target_file)
  if vim.fn.filereadable(expanded_path) == 0 then
    vim.notify('TODO file does not exist at directory: ' .. expanded_path, vim.log.levels.ERROR)
  end

  local buf = vim.fn.bufnr(expanded_path, true)

  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, expanded_path)
  end

  vim.bo[buf].swapfile = false

  local win = vim.api.nvim_open_win(buf, true, create_floating_window())

  -- Set cursor to the end of the buffer
  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(win, { line_count, 0 })

  return win
end

local function toggle_todo_window(target_file)
  local create = true
  for _, value in ipairs(vim.api.nvim_list_wins()) do
    if state.win_num == value then
      create = false
    end
  end
  target_file = state.searched_file or target_file or state.target_file
  if create then
    state.win_num = open_floating_window(target_file)
  else
    vim.api.nvim_win_close(state.win_num, false)
  end
end

local function setup_user_commands(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command('Todo', function()
    toggle_todo_window(state.target_file)
  end, {})
end

local default_opts = {
  target_file_pattern = 'todo.md',
  -- target_file = 'todo.md',
  fzf_opts = { target_dir = '~/' },
}

---Opens `fzf-lua` picker to search files in the target directory.
---The default is the home directory `~/`.
---@param opts any
local function search_files(opts, cache_file_path)
  local fzf_opts = opts or {}
  fzf_opts.actions = {
    ['enter'] = function(selected, _)
      state.searched_file = selected[1]
      toggle_todo_window(selected[1])
    end,
  }
  fzf_opts.previewer = true

  local dir = fzf_opts.target_dir or './'
  vim.api.nvim_create_user_command('TodoSearch', function(opts)
    require('fzf-lua').fzf_exec('fd . --extension md --extension txt --type f ' .. dir, fzf_opts)
  end, {})
end

local function create_cache_file()
  -- Set up cache files for persistent per project conf
  Path:new(data_dir .. '/floatodo.nvim'):mkdir()
  local data_cache_path =
    -- Path:new(data_dir .. '/floatodo.nvim/' .. os.date('%Y%m%d_%H%M%S') .. '.json')
    Path:new(data_dir .. '/floatodo.nvim' .. vim.uv.cwd() .. '.json')
  print(data_cache_path:touch({ parents = true }))
end

create_cache_file()

M.setup = function(opts)
  create_cache_file()
  -- TODO: Better handling of defaults and user set options
  local target_file_pattern = opts.target_file_pattern or default_opts.target_file_pattern
  default_opts.target_file = vim.uv.cwd() .. '/' .. target_file_pattern
  opts = vim.tbl_deep_extend('force', default_opts, opts)
  state.target_file = opts.target_file
  setup_user_commands(opts)
  search_files(opts.fzf_opts, data_cache_path)
end

-- require('fzf-lua').fzf_exec(Path:new('./tod.md'):readlines())
return M

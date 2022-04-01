local log = require("neo-tree.log")
local utils = require("neo-tree.utils")
local vim = vim
local M = {}

M.BUFFER_NUMBER = "NeoTreeBufferNumber"
M.CURSOR_LINE = "NeoTreeCursorLine"
M.DIM_TEXT = "NeoTreeDimText"
M.DIRECTORY_ICON = "NeoTreeDirectoryIcon"
M.DIRECTORY_NAME = "NeoTreeDirectoryName"
M.DOTFILE = "NeoTreeDotfile"
M.FADE_TEXT_1 = "NeoTreeFadeText1"
M.FADE_TEXT_2 = "NeoTreeFadeText2"
M.FILE_ICON = "NeoTreeFileIcon"
M.FILE_NAME = "NeoTreeFileName"
M.FILE_NAME_OPENED = "NeoTreeFileNameOpened"
M.FILTER_TERM = "NeoTreeFilterTerm"
M.FLOAT_BORDER = "NeoTreeFloatBorder"
M.FLOAT_TITLE = "NeoTreeFloatTitle"
M.GIT_ADDED = "NeoTreeGitAdded"
M.GIT_CONFLICT = "NeoTreeGitConflict"
M.GIT_DELETED = "NeoTreeGitDeleted"
M.GIT_IGNORED = "NeoTreeGitIgnored"
M.GIT_MODIFIED = "NeoTreeGitModified"
M.GIT_RENAMED = "NeoTreeGitRenamed"
M.GIT_UNTRACKED = "NeoTreeGitUntracked"
M.HIDDEN_BY_NAME = "NeoTreeHiddenByName"
M.INDENT_MARKER = "NeoTreeIndentMarker"
M.MODIFIED = "NeoTreeModified"
M.NORMAL = "NeoTreeNormal"
M.NORMALNC = "NeoTreeNormalNC"
M.ROOT_NAME = "NeoTreeRootName"
M.SYMBOLIC_LINK_TARGET = "NeoTreeSymbolicLinkTarget"
M.TITLE_BAR = "NeoTreeTitleBar"
M.INDENT_MARKER = "NeoTreeIndentMarker"
M.EXPANDER = "NeoTreeExpander"

local function dec_to_hex(n, chars)
  chars = chars or 6
  local hex = string.format("%0" .. chars .. "x", n)
  while #hex < chars do
    hex = "0" .. hex
  end
  return hex
end

---If the given highlight group is not defined, define it.
---@param hl_group_name string The name of the highlight group.
---@param link_to_if_exists table A list of highlight groups to link to, in
--order of priority. The first one that exists will be used.
---@param background string The background color to use, in hex, if the highlight group
--is not defined and it is not linked to another group.
---@param foreground string The foreground color to use, in hex, if the highlight group
--is not defined and it is not linked to another group.
---@gui string The gui to use, if the highlight group is not defined and it is not linked
--to another group.
---@return table table The highlight group values.
local function create_highlight_group(hl_group_name, link_to_if_exists, background, foreground, gui)
  local success, hl_group = pcall(vim.api.nvim_get_hl_by_name, hl_group_name, true)
  if not success or not hl_group.foreground or not hl_group.background then
    for _, link_to in ipairs(link_to_if_exists) do
      success, hl_group = pcall(vim.api.nvim_get_hl_by_name, link_to, true)
      if success then
        local new_group_has_settings = background or foreground or gui
        local link_to_has_settings = hl_group.foreground or hl_group.background
        if link_to_has_settings or not new_group_has_settings then
          vim.cmd("highlight default link " .. hl_group_name .. " " .. link_to)
          return hl_group
        end
      end
    end

    if type(background) == "number" then
      background = dec_to_hex(background)
    end
    if type(foreground) == "number" then
      foreground = dec_to_hex(foreground)
    end

    local cmd = "highlight default " .. hl_group_name
    if background then
      cmd = cmd .. " guibg=#" .. background
    end
    if foreground then
      cmd = cmd .. " guifg=#" .. foreground
    else
      cmd = cmd .. " guifg=NONE"
    end
    if gui then
      cmd = cmd .. " gui=" .. gui
    end
    vim.cmd(cmd)

    return {
      background = background and tonumber(background, 16) or nil,
      foreground = foreground and tonumber(foreground, 16) or nil,
    }
  end
  return hl_group
end

local faded_highlight_group_cache = {}
M.get_faded_highlight_group = function (hl_group_name, fade_percentage)
  if type(hl_group_name) ~= "string" then
    error("hl_group_name must be a string")
  end
  if type(fade_percentage) ~= "number" then
    error("hl_group_name must be a number")
  end
  if fade_percentage < 0 or fade_percentage > 1 then
    error("fade_percentage must be between 0 and 1")
  end

  local key = hl_group_name .. "_" .. tostring(math.floor(fade_percentage * 100))
  if faded_highlight_group_cache[key] then
    return faded_highlight_group_cache[key]
  end

  local normal = vim.api.nvim_get_hl_by_name("Normal", true)
  local foreground = dec_to_hex(normal.foreground)
  local background = dec_to_hex(normal.background)

  local hl_group = vim.api.nvim_get_hl_by_name(hl_group_name, true)
  if utils.truthy(hl_group.foreground) then
    foreground = dec_to_hex(hl_group.foreground)
  end
  if utils.truthy(hl_group.background) then
    background = dec_to_hex(hl_group.background)
  end

  local gui = {}
  if hl_group.bold then
    table.insert(gui, "bold")
  end
  if hl_group.italic then
    table.insert(gui, "italic")
  end
  if hl_group.underline then
    table.insert(gui, "underline")
  end
  if hl_group.undercurl then
    table.insert(gui, "undercurl")
  end
  if #gui > 0 then
    gui = table.concat(gui, ",")
  else
    gui = nil
  end

  local f_red = tonumber(foreground:sub(1, 2), 16)
  local f_green = tonumber(foreground:sub(3, 4), 16)
  local f_blue = tonumber(foreground:sub(5, 6), 16)

  local b_red = tonumber(background:sub(1, 2), 16)
  local b_green = tonumber(background:sub(3, 4), 16)
  local b_blue = tonumber(background:sub(5, 6), 16)

  local red = (f_red * fade_percentage) + (b_red * (1 - fade_percentage))
  local green = (f_green * fade_percentage) + (b_green * (1 - fade_percentage))
  local blue = (f_blue * fade_percentage) + (b_blue * (1 - fade_percentage))

  local new_foreground = string.format("%s%s%s", dec_to_hex(red, 2), dec_to_hex(green, 2), dec_to_hex(blue, 2))

  create_highlight_group(key, {}, hl_group.background, new_foreground, gui)
  faded_highlight_group_cache[key] = key
  return key
end

M.setup = function()
  local normal_hl = create_highlight_group(M.NORMAL, { "Normal" })
  local normalnc_hl = create_highlight_group(M.NORMALNC, { "NormalNC", M.NORMAL })

  local float_border_hl = create_highlight_group(
    M.FLOAT_BORDER,
    { "FloatBorder" },
    normalnc_hl.background,
    "444444"
  )

  create_highlight_group(M.FLOAT_TITLE, {}, float_border_hl.background, normal_hl.foreground)
  create_highlight_group(M.TITLE_BAR, {}, float_border_hl.foreground, nil)

  create_highlight_group(M.BUFFER_NUMBER, { "SpecialChar" })
  create_highlight_group(M.DIM_TEXT, {}, nil, "505050")
  create_highlight_group(M.FADE_TEXT_1, {}, nil, "626262")
  create_highlight_group(M.FADE_TEXT_2, {}, nil, "444444")
  create_highlight_group(M.DOTFILE, {}, nil, "626262")
  create_highlight_group(M.HIDDEN_BY_NAME, { M.DOTFILE }, nil, nil)
  create_highlight_group(M.CURSOR_LINE, { "CursorLine" }, nil, nil, "bold")
  create_highlight_group(M.DIRECTORY_NAME, { "Directory" }, "NONE", "NONE")
  create_highlight_group(M.DIRECTORY_ICON, { "Directory" }, nil, "73cef4")
  create_highlight_group(M.FILE_ICON, { M.DIRECTORY_ICON })
  create_highlight_group(M.FILE_NAME, {}, "NONE", "NONE")
  create_highlight_group(M.FILE_NAME_OPENED, {}, nil, nil, "bold")
  create_highlight_group(M.SYMBOLIC_LINK_TARGET, { M.FILE_NAME })
  create_highlight_group(M.FILTER_TERM, { "SpecialChar", "Normal" })
  create_highlight_group(M.ROOT_NAME, {}, nil, nil, "bold,italic")
  create_highlight_group(M.INDENT_MARKER, { M.DIM_TEXT })
  create_highlight_group(M.EXPANDER, { M.DIM_TEXT })
  create_highlight_group(M.MODIFIED, {}, nil, "d7d787")

  local added = create_highlight_group(
    M.GIT_ADDED,
    { "GitGutterAdd", "GitSignsAdd" },
    nil,
    "5faf5f"
  )
  create_highlight_group(M.GIT_DELETED, { "GitGutterDelete", "GitSignsDelete" }, nil, "ff5900")
  create_highlight_group(M.GIT_MODIFIED, { "GitGutterChange", "GitSignsChange" }, nil, "d7af5f")
  local conflict = create_highlight_group(M.GIT_CONFLICT, {}, nil, "ff8700", "italic,bold")
  create_highlight_group(M.GIT_IGNORED, { M.DOTFILE }, nil, nil)
  create_highlight_group(M.GIT_RENAMED, { M.GIT_MODIFIED }, nil, nil)
  create_highlight_group(M.GIT_UNTRACKED, {}, nil, conflict.foreground, "italic")
end


return M

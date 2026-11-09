-- Takumi theme loader: reads ~/.local/state/takumi/look/nvim-theme.lua.
local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local theme_file = state .. "/takumi/look/nvim-theme.lua"

local function apply_takumi_theme()
  local ok, c = pcall(dofile, theme_file)
  if not ok or type(c) ~= "table" then return end
  vim.o.termguicolors = true
  vim.o.background = c.mode == "light" and "light" or "dark"
  local set = vim.api.nvim_set_hl
  set(0, "Normal",          { fg = c.foreground, bg = c.background })
  set(0, "NormalFloat",     { fg = c.foreground, bg = c.surface })
  set(0, "FloatBorder",     { fg = c.muted,      bg = c.surface })
  set(0, "CursorLine",      { bg = c.surface })
  set(0, "CursorLineNr",    { fg = c.accent,     bold = true })
  set(0, "LineNr",          { fg = c.muted })
  set(0, "Visual",          { bg = c.surface })
  set(0, "Search",          { fg = c.background, bg = c.accent })
  set(0, "IncSearch",       { fg = c.background, bg = c.yellow })
  set(0, "StatusLine",      { fg = c.foreground, bg = c.surface })
  set(0, "StatusLineNC",    { fg = c.muted,      bg = c.background })
  set(0, "Pmenu",           { fg = c.foreground, bg = c.surface })
  set(0, "PmenuSel",        { fg = c.background, bg = c.accent })
  set(0, "WinSeparator",    { fg = c.surface })
  set(0, "Comment",         { fg = c.muted,      italic = true })
  set(0, "Constant",        { fg = c.yellow })
  set(0, "String",          { fg = c.green })
  set(0, "Identifier",      { fg = c.foreground })
  set(0, "Function",        { fg = c.blue })
  set(0, "Statement",       { fg = c.magenta })
  set(0, "Keyword",         { fg = c.magenta })
  set(0, "Operator",        { fg = c.cyan })
  set(0, "Type",            { fg = c.cyan })
  set(0, "Special",         { fg = c.accent })
  set(0, "Error",           { fg = c.red })
  set(0, "DiagnosticError", { fg = c.red })
  set(0, "DiagnosticWarn",  { fg = c.yellow })
  set(0, "DiagnosticInfo",  { fg = c.cyan })
  set(0, "DiagnosticHint",  { fg = c.muted })
end

apply_takumi_theme()
vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
  callback = apply_takumi_theme,
})


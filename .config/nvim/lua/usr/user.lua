-- User-owned Neovim behavior.
-- Keep personal overrides here so upstream config syncs do not silently remove them.

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.guifont = "monospace:h17"

vim.keymap.set("i", "kj", "<Esc>", {
  noremap = true,
  silent = true,
  desc = "Exit insert mode",
})

vim.keymap.set("x", "kj", "<Esc>", {
  noremap = true,
  silent = true,
  desc = "Exit visual mode",
})

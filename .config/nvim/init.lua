vim.cmd("source ~/.vimrc")

-- require('config.lazy') only if lazyvim config exists
if pcall(require, "config.lazy") then
  require("config.lazy")
end

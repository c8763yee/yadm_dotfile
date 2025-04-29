require("hardtime").setup {
  timeout = 10000, -- 10秒後重新啟用被禁用的按鍵
  disable_mouse = false,
  disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
  disabled_keys={
    ["<ESC>"] = {"", "i"},
    ["<CR>"] = {"", "i"},
  },
  hints={

    ["<ESC>"] = {
      message = function()
        return "Use kj instead of <ESC>"
      end 
    },
    ["<CR>"] = {
      message = function()
        return "Use kj instead of <CR>"
      end 
    }
  }
}

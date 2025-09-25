local modrev, specrev = "dev", "-1"
local repo_url = "https://github.com/lettertwo/occurrence.nvim"

rockspec_format = "3.0"
package = "occurrence.nvim"
version = modrev .. specrev

description = {
  summary = "Intelligent occurrence highlighting and operations for Neovim",
  detailed = [[
    occurrence.nvim is a modern Neovim plugin for intelligent occurrence
    highlighting and operations. It allows you to mark occurrences of
    words/patterns in a buffer and perform operations on them, similar to multiple
    cursor functionality but with vim-native operators.

    Features:
    - Smart occurrence detection (word, selection, search patterns)
    - Visual highlighting using Neovim's extmarks system
    - Native vim operator integration (c, d, y, etc.)
    - Multiple interaction modes (preset, operator-pending, modifier)
    - Highly configurable keymaps and behavior
    - Performance optimized for large files
  ]],
  homepage = repo_url,
  license = "MIT",
}

dependencies = {
  "lua >= 5.1, < 5.2",
}

test_dependencies = {
  "busted",
  "nlua",
}

source = {
  url = repo_url .. "/archive/" .. "main" .. ".zip",
  dir = "occurrence.nvim-" .. "main",
}

if modrev == "dev" then
  source = {
    url = repo_url .. "/archive/" .. modrev .. ".zip",
    dir = "occurrence.nvim-" .. modrev,
  }
end

build = {
  type = "builtin",
  copy_directories = {
    "doc",
    "plugin",
  },
}


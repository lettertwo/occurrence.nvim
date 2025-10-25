local modrev, specrev = "dev", "-1"
local repo_url = "https://github.com/lettertwo/occurrence.nvim"

rockspec_format = "3.0"
package = "occurrence.nvim"
version = modrev .. specrev

description = {
  summary = "Mark occurrences of words/patterns in a buffer and perform operations on them",
  detailed = [[
    occurrence.nvim is a Neovim plugin to mark occurrences of words/patterns
    in a buffer and perform operations on them.

    Inspired by vim-mode-plus's occurrence feature.

    Features:
    - Smart Occurrence Detection: Find word under cursor, visual selections, or last search patterns
    - Visual Feedback: Occurrences are highlighted with status showing current/total counts
    - Operator Integration: Use native vim operators (c, d, y, etc.) on occurrences
    - Multiple Interaction Modes: Select occurrences and then operate, or modify a pending operation to target occurrences
    - Highly Configurable: Customize keymaps, operators, and behavior
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


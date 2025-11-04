# occurrence.nvim

A Neovim plugin for marking and operating on multiple occurrences. Mark words, selections, or search patterns, then use native Vim operators to batch edit them.

<!-- panvimdoc-ignore-start -->

Inspired by [vim-mode-plus]'s occurrence feature.

# Key Features

## 🔍 Smart Occurrence Detection

- Word under cursor with boundary matching
- Visual selections (character, line, or block)
- Last search pattern from `/` or `?`
- Automatic pattern escaping and vim regex support

## ⚡ Native Operator Integration

- Use standard Vim operators: `c`, `d`, `y`, `p`, `<`, `>`, `=`, `gu`, `gU`, `g~`, `g?`
- Two interaction modes: mark-then-operate or operator-pending modifier
- Works with motions and text objects (`ip`, `$`, `G`, etc.)
- Dot-repeat support for all operations

## 🎯 Visual Feedback

- Real-time highlighting of all matches and marked occurrences
- Current occurrence highlighting during navigation
- Statusline integration showing current/total counts
- Customizable highlight groups

## 🛠️ Highly Configurable

- Enable/disable default keymaps or define custom ones
- Choose which operators to enable or disable, or add custom ones
- Customize highlight appearance
- Lua API for advanced usage and integration

<!-- panvimdoc-ignore-end -->

# Installation

### Requirements

- Neovim >= 0.10.0

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "lettertwo/occurrence.nvim",
  event = "BufReadPost", -- If you want to lazy load
  -- opts = {} -- setup is optional; the defaults will work out of the box.
}
```

### Using :h vim.pack

```lua
vim.pack.add("lettertwo/occurrence.nvim")
```

# Quick Start

With the default configuration, you can try these workflows to get a feel for `occurrence.nvim`.

1. Install the plugin using your preferred package manager
2. No configuration required - default keymaps work out of the box

## Marking occurrences

You can enter 'occurrence mode' to mark occurrences and then operate on them:

1. Place cursor on a word and press `go` to mark all occurrences
2. Use `n`/`N` to navigate between marked occurrences
3. Press `c` followed by a motion (e.g., `ip`) to change marked occurrences in that range
4. Type your replacement text
5. Press `<Esc>` to exit occurrence mode

Marking occurrences can be done in several ways:

- **Word under cursor**: Place cursor on a word and press `go` in normal mode
- **Visual selection**: Select text in visual mode and press `go`
- **Last search pattern**: After searching with `/pattern` or `?pattern`, press `go` in normal mode

Once occurrences are marked, you can navigate, add and remove them:

- **Navigate**: Use `n`/`N` to jump between marked occurrences, or `gn`/`gN` for all occurrences
- **Mark individual**: `ga` to mark current occurrence, `gx` to unmark
- **Toggle mark**: `go` to toggle mark on current occurrence

## Operating on occurrences

With occurrences marked, you can perform operations on them in several ways:

1. **Choose operation**: Use vim operators like `c` (change), `d` (delete), `y` (yank) on marked occurrences
2. **Choose range**: Use vim motions like `$`, `ip`, etc. to apply operator to occurrences in that range

Or, you can use visual mode:

1. **Start visual mode**: Press `v` to enter visual mode, or `V` for visual line mode
2. **Select range**: Use vim motions to select a range
3. **Choose operation**: Use vim operators like `c` (change), `d` (delete), `y` (yank) on marked occurrences in the visual range.

When you're done, press `<Esc>` to exit occurrence mode and clear all marks.

## Operator-pending mode

**Alternative workflow:** Use operator-pending mode with `c`, `d`, or `y` followed by `o` and a motion (e.g., `doip` deletes word occurrences in the paragraph).

You can modify most vim operators to work on occurrences of the word under cursor:

1. **Choose operator**: Start an operation like `c`, `d`, `y`
2. **Modify operator**: Press `o` to enter occurrence operator-modifier mode
3. **Choose range**: Use vim motions like `$`, `ip`, etc. to apply to occurrences in that range

# Configuration

The plugin works with zero configuration but can be customized through `require("occurrence").setup({...})`. Configuration options include:

```lua
require("occurrence").setup({
  -- Enable default keymaps (go, n, N, gn, gN, ga, gx, etc.)
  default_keymaps = true,

  -- Enable default operator support (c, d, y, p, gp, <, >, =, gu, gU, g~, g?)
  default_operators = true,

  -- Operator configurations
  operators = {
    ["c"] = "change",             -- Change marked occurrences
    ["d"] = "delete",             -- Delete marked occurrences
    ["y"] = "yank",               -- Yank marked occurrences
    ["p"] = "put",                -- Put register at marked occurrences
    ["gp"] = "distribute",        -- Distribute lines from register across occurrences
    ["<"] = "indent_left",        -- Indent left
    [">"] = "indent_right",       -- Indent right
    ["="] = "indent_format",      -- Indent/format
    ["gu"] = "lowercase",         -- Convert to lowercase
    ["gU"] = "uppercase",         -- Convert to uppercase
    ["g~"] = "swap_case",         -- Swap case
    ["g?"] = "rot13",             -- ROT13 encoding
  },

  -- Optional: callback when occurrence mode activates
  -- Receives a keymap function: `map(mode, lhs, rhs, opts)`
  -- This function can be used to set up custom keymaps that are only active in occurrence mode.
  -- Keymaps that are set through this function will automatically be removed when occurrence mode deactivates.
  on_activate = nil,
})
```

### Default Keymaps

These keymaps are set automatically when `default_keymaps = true`.

Normal/Visual mode:

- `go` - Find and mark occurrences (word/selection/search pattern)

Operator-pending mode:

- `o` - Occurrence operator modifier (e.g., `coip`, `do$`)

Occurrence mode (after marking occurrences from normal/visual mode):

- `n` / `N` - Next/previous marked occurrence
- `gn` / `gN` - Next/previous occurrence (all matches)
- `go` - Toggle mark on current occurrence or mark new word
- `ga` - Mark current occurrence
- `gx` - Unmark current occurrence
- `<Esc>`, `<C-c>`, `<C-[>` - Exit occurrence mode
- All configured operators (`c`, `d`, `y`, `p`, `gp`, `<`, `>`, `=`, `gu`, `gU`, `g~`, `g?`)

## Keymaps

You can disable default keymaps and set up custom ones:

```lua
require("occurrence").setup({
  default_keymaps = false,  -- Disable defaults
  on_activate = function(map)
    -- Custom navigation
    map("n", "<Tab>", "<Plug>(OccurrenceNext)")
    map("n", "<S-Tab>", "<Plug>(OccurrencePrevious)")

    -- Batch operations
    map("n", "<leader>a", function()
      require('occurrence').mark_all()
    end)
    map("n", "<leader>x", function()
      require('occurrence').unmark_all()
    end)

    -- Exit
    -- NOTE: If you disable default keymaps
    -- you'll want a way to exit occurrence mode!
    map("n", "q", "<Plug>(OccurrenceDeactivate)")
  end,
})

-- Set up custom keymaps using <Plug> mappings
vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceCurrent)")

-- Or using the `:Occurrence` command:
vim.keymap.set("v", "<C-o>", ":Occurrence selection<CR>")

-- Or using Lua API:
vim.keymap.set("o", "<C-o>", function()
  require('occurrence').modify_operator()
end)
```

## Operators

### Disabling Specific Operators

```lua
require("occurrence").setup({
  operators = {
    ["c"] = "change",
    ["d"] = "delete",
    ["y"] = "yank",
    ["g?"] = false,  -- Disable ROT13
    ["g~"] = false,  -- Disable swap case
  },
})
```

### Custom Line-Based Operators

Add operators that work on marked occurrences on the current line:

```lua
require("occurrence").setup({
  on_activate = function(map)
    -- dd - Delete marked occurrences on current line
    map("n", "dd", function()
      local occ = require('occurrence.Occurrence').get()
      local range = require("occurrence.Range").of_line()
      occ:apply_operator("delete", range, "line")
    end, { desc = "Delete marked occurrences on line" })

    -- D - Delete marked occurrences from cursor to end of line
    map("n", "D", function()
      local occ = require("occurrence.Occurrence").get()
      occ:apply_operator("delete", "$")
    end, { desc = "Delete marked occurrences from cursor to end of line" })

    -- cc - Change marked occurrences on current line
    map("n", "cc", function()
      local occ = require('occurrence.Occurrence').get()
      local range = require("occurrence.Range").of_line()
      occ:apply_operator("change", range, "line")
    end, { desc = "Change marked occurrences on line" })

    -- C - Change marked occurrences from cursor to end of line
    map("n", "C", function()
      local occ = require("occurrence.Occurrence").get()
      occ:apply_operator("change", "$")
    end, { desc = "Change marked occurrences from cursor to end of line" })
  end,
})
```

## Highlights

occurrence.nvim uses three highlight groups for visual feedback:

- **`OccurrenceMatch`**: All occurrence matches (default: links to `Search`)
- **`OccurrenceMark`**: Marked occurrences (default: links to `IncSearch`)
- **`OccurrenceCurrent`**: Current occurrence (default: links to `CurSearch`)

You can customize these highlight groups in your configuration:

```lua
-- Example: Bold and underlined for emphasis
vim.api.nvim_set_hl(0, "OccurrenceMatch", {})
vim.api.nvim_set_hl(0, "OccurrenceMark", { bold = true, underline = true })
vim.api.nvim_set_hl(0, "OccurrenceCurrent", { bold = true, underline = true, reverse = true })
```

## Statusline Integration

Display occurrence count in your statusline similar to Neovim's search count using the `status()` API:

```lua
-- Example: lualine component
local function occurrence_status()
  local count = require('occurrence').status()
  if not count then
    return ""
  end
  return string.format("[%d/%d]", count.current, count.total)
end

require('lualine').setup({
  sections = {
    lualine_c = { 'filename', occurrence_status },
  }
})
```

The `status()` function returns `nil` if no active occurrence, otherwise returns:

- `current`: Current match index
- `total`: Total number of matches
- `exact_match`: 1 if cursor is on a match, 0 otherwise
- `marked_only`: Whether counting only marked occurrences

# Usage Examples

Some examples of real-world workflows using `occurrence.nvim`.

### Example: Selective Editing

Change only some occurrences of a word:

```vim
" Buffer: The quick brown fox jumps over the lazy dog.
"         The fox is quick and the dog is lazy.
"         Another fox and dog appear here.

go          " Mark all occurrences of 'fox' (cursor on first 'fox')
n           " Navigate to next occurrence (line 2)
gx          " Unmark this one (skip it)
n           " Navigate to next (line 3)
cip         " 'c'hange marked occurrences 'i'n 'p'aragraph
wolf        " Type replacement
<Esc>       " Exit and clear marks

" Result: 'fox' on lines 1 and 3 changed to 'wolf', line 2 unchanged
```

### Example: Working with Search Patterns

Mark occurrences from last search pattern:

```vim
" Buffer: The quick brown fox jumps over the lazy dog.
"         The fox is quick and the dog is lazy.
"         Another fox and dog appear here.

/\<...\>    " Search for 3-letter words (the, fox, the, dog, and)
go          " Mark all occurrences matching the search pattern
gggUG       " Uppercase all marked occurrences: 'gg' to start, 'gU' uppercase, 'G' to end

" Result: THE quick brown FOX jumps over THE lazy DOG.
"         THE FOX is quick AND THE DOG is lazy.
"         Another FOX AND DOG appear here.
```

### Example: Working with Multiple Patterns

Mark different words and edit them together:

```vim
" Buffer: foo is here and bar is there
"         foo and bar together
"         only foo here
"         only bar there

go          " Mark all 'foo' occurrences (cursor on first 'foo')
j2w         " Move cursor to 'bar' on line 2
go          " Mark all 'bar' occurrences as well
cip         " 'c'hange all marked occurrences 'i'n 'p'aragraph
test<CR>    " Type replacement
<Esc>       " Exit

" Result: test is here and test is there
"         test and test together
"         only test here
"         only test there
```

### Example: Yanking and Putting Occurrences

Yank marked occurrences and paste at different locations:

```vim
" Buffer: SOURCE SOURCE SOURCE
"         dest dest dest

go          " Mark 'SOURCE' occurrences (cursor on first SOURCE)
y$          " Yank all marked occurrences to end of line
<Esc>       " Exit occurrence mode
j^          " Move to line 2, first column
go          " Mark all 'dest' occurrences
p$          " Put yanked content at all marked locations

" Result: Multi-line content replaces each dest
"         Each dest becomes: SOURCE
"                            SOURCE
"                            SOURCE
```

### Example: Distributing Values

The `distribute` operator (`gp`) cycles through lines from a register when pasting, giving each occurrence a different value. This is useful for refactoring or batch renaming with distinct values.

```vim
" Buffer: alpha foo beta bar gamma bat
"         foo dest bar dest bat dest

" 1. Mark and yank source values using search pattern
/\(alpha\|beta\|gamma\)<CR>  " Search for the three values
go                           " Mark all matching occurrences
Vy                           " Yank marked values (creates "alpha\nbeta\ngamma")
<Esc>                        " Exit occurrence mode

" 2. Distribute values to destinations
/\(foo\|bar\|bat\)<CR>       " Search for the three dest values
go                           " Mark all matching occurrences
jVgp                         " Move to line2 and Distribute - cycles through yanked lines

" Result: alpha foo beta bar gamma bat
"         alpha dest beta dest gamma dest
" (Each dest gets a different value: first->alpha, second->beta, third->gamma)
```

**Difference between `p` and `gp`:**

- `p` (put): Replicates the same text at each occurrence
- `gp` (distribute): Cycles through lines in the register, giving each occurrence a different line

# API Reference

## Lua API

occurrence.nvim provides a Lua API for programmatic control:

### `require('occurrence').setup(opts)`

Configure the plugin. See [Configuration](#configuration) for available options.

**Note:** calling `setup()` is **not required** unless you intend to customize settings!

### `require('occurrence').status(opts)`

Get occurrence count information for statusline (or other) integrations.

**Parameters:**

- `opts` (table, optional):
  - `marked` (boolean): Count only marked occurrences (default: `false`)
  - `buffer` (integer): Buffer number (default: current buffer)

**Returns:**

- `nil` if no active occurrence
- Table with fields:
  - `current` (integer): Current match index (1-based)
  - `total` (integer): Total number of matches
  - `exact_match` (integer): 1 if cursor is exactly on a match, 0 otherwise
  - `marked_only` (boolean): Whether counting only marked occurrences

## Actions

All actions are available in three ways:

- **Lua API**:

  ```lua
  require('occurrence').current()
  ```

- **Vim commands**:

  ```vim
  :Occurrence current
  ```

- **<Plug> mappings**:

  ```vim
  <Plug>(OccurrenceCurrent)
  ```

### Entry Actions

Actions that activate occurrence mode:

| Action      | <Plug> Mapping                | Description                                           |
| ----------- | ----------------------------- | ----------------------------------------------------- |
| `word`      | `<Plug>(OccurrenceWord)`      | Find occurrences of word under cursor                 |
| `selection` | `<Plug>(OccurrenceSelection)` | Find occurrences of visual selection                  |
| `pattern`   | `<Plug>(OccurrencePattern)`   | Find occurrences of last search pattern               |
| `current`   | `<Plug>(OccurrenceCurrent)`   | Find occurrences (smart: selection, pattern, or word) |

### Occurrence Mode Actions

Actions available when occurrence mode is active:

| Action                | <Plug> Mapping                    | Description                                          |
| --------------------- | --------------------------------- | ---------------------------------------------------- |
| `next`                | `<Plug>(OccurrenceNext)`          | Navigate to next marked occurrence                   |
| `previous`            | `<Plug>(OccurrencePrevious)`      | Navigate to previous marked occurrence               |
| `match_next`          | `<Plug>(OccurrenceMatchNext)`     | Navigate to next occurrence (all matches)            |
| `match_previous`      | `<Plug>(OccurrenceMatchPrevious)` | Navigate to previous occurrence (all matches)        |
| `mark`                | `<Plug>(OccurrenceMark)`          | Mark current occurrence                              |
| `unmark`              | `<Plug>(OccurrenceUnmark)`        | Unmark current occurrence                            |
| `toggle`              | `<Plug>(OccurrenceToggle)`        | Toggle mark on occurrence or mark new word/selection |
| `mark_all`            | -                                 | Mark all occurrences                                 |
| `unmark_all`          | -                                 | Unmark all occurrences                               |
| `mark_in_selection`   | -                                 | Mark occurrences within visual selection             |
| `unmark_in_selection` | -                                 | Unmark occurrences within visual selection           |
| `deactivate`          | `<Plug>(OccurrenceDeactivate)`    | Clear all marks and exit occurrence mode             |

### Operator Modifier

Actions to modify operator-pending mode to work on occurrences:

| Action            | <Plug> Mapping                     | Description                                       |
| ----------------- | ---------------------------------- | ------------------------------------------------- |
| `modify_operator` | `<Plug>(OccurrenceModifyOperator)` | Modifier for operator-pending mode (e.g., `doip`) |

## Builtin Operators

The following operators can be modified via `modify_operator` or used in occurrence mode (configured via `operators` table):

| Operator        | Key  | Description                                                       |
| --------------- | ---- | ----------------------------------------------------------------- |
| `change`        | `c`  | Change marked occurrences (prompts for replacement)               |
| `delete`        | `d`  | Delete marked occurrences                                         |
| `yank`          | `y`  | Yank marked occurrences to register                               |
| `put`           | `p`  | Put register content at marked occurrences (replicates same text) |
| `distribute`    | `gp` | Distribute lines from register cyclically across occurrences      |
| `indent_left`   | `<`  | Indent left                                                       |
| `indent_right`  | `>`  | Indent right                                                      |
| `indent_format` | `=`  | Indent/format                                                     |
| `uppercase`     | `gU` | Convert to uppercase                                              |
| `lowercase`     | `gu` | Convert to lowercase                                              |
| `swap_case`     | `g~` | Swap case                                                         |
| `rot13`         | `g?` | ROT13 encoding                                                    |

<!-- panvimdoc-ignore-start -->

# Development

See [CONTRIBUTING](./CONTRIBUTING.md) for contribution guidelines.

# License

[MIT](./LICENSE)

[vim-mode-plus]: https://github.com/t9md/atom-vim-mode-plus?tab=readme-ov-file#some-features

<!-- panvimdoc-ignore-end -->

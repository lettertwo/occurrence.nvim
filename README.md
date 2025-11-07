# occurrence.nvim

A Neovim plugin for marking and operating on multiple occurrences. Mark words, selections, or search patterns, then use native Vim operators to batch edit them.

<!-- panvimdoc-ignore-start -->

Inspired by [vim-mode-plus]'s occurrence feature.

## Key Features

### 🔍 Smart Occurrence Detection

- Word under cursor with boundary matching
- Visual selections (character, line, or block)
- Last search pattern from `/` or `?`
- Automatic pattern escaping and vim regex support

### ⚡ Native Operator Integration

- Use standard Vim operators: `c`, `d`, `y`, `p`, `<`, `>`, `=`, `gu`, `gU`, `g~`, `g?`
- Two interaction modes: mark-then-operate or operator-pending modifier
- Works with motions and text objects (`ip`, `$`, `G`, etc.)
- Dot-repeat support for all operations

### 🎯 Visual Feedback

- Real-time highlighting of all matches and marked occurrences
- Current occurrence highlighting during navigation
- Statusline integration showing current/total counts
- Customizable highlight groups

### 🛠️ Highly Configurable

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
  -- Whether to include default keymaps.
  --
  -- If `false`, global keymaps, such as the default `go` to activate
  -- occurrence mode, or the default `o` to modify a pending operator,
  -- are not set, so activation keymaps must be set manually,
  -- e.g., `vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceCurrent)")``
  -- or `vim.keymap.set("o", "<C-o>", "<Plug>(OccurrenceModifyOperator)")`.
  --
  -- Additionally, when `false`, only keymaps explicitly defined in `keymaps`
  -- will be automatically set when activating occurrence mode. Keymaps for
  -- occurrence mode can also be set manually using the `on_activate` callback.
  --
  -- Default `operators` will still be set unless `default_operators` is also `false`.
  --
  -- Defaults to `true`.
  default_keymaps = true,

  -- Whether to include default operator support.
  -- (c, d, y, p, gp, <, >, =, gu, gU, g~, g?)
  --
  -- If `false`, only operators explicitly defined in `operators`
  -- will be supported.
  --
  -- Defaults to `true`.
  default_operators = true,

  -- A table defining keymaps that will be active in occurrence mode.
  -- Each key is a string representing the keymap, and each value is either:
  --   - a string representing the name of a built-in API action,
  --   - a table defining a custom keymap configuration,
  --   - or `false` to disable the keymap.
  keymaps = {
    ["n"] = "next",                     -- Next marked occurrence
    ["N"] = "previous",                 -- Previous marked occurrence
    ["gn"] = "match_next",              -- Next occurrence (all matches)
    ["gN"] = "match_previous",          -- Previous occurrence (all matches)
    ["go"] = "toggle",                  -- Toggle or mark an occurrence
    ["ga"] = "mark",                    -- Mark current occurrence
    ["gx"] = "unmark",                  -- Unmark current occurrence
    ["<Esc>"] = "deactivate",           -- Exit occurrence mode
    ["<C-c>"] = "deactivate",           -- Exit occurrence mode
    ["<C-[>"] = "deactivate",           -- Exit occurrence mode
  },

  -- A table defining operators that can be modified to operate on occurrences.
  -- These operators will also be active as keymaps in occurrence mode.
  -- Each key is a string representing the operator key, and each value is either:
  --   - a string representing the name of a built-in operator,
  --   - a table defining a custom operator configuration,
  --   - or `false` to disable the operator.
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

  -- A callback that is invoked when occurrence mode is activated.
  -- The callback receives a `map` function that can be used
  -- to set additional keymaps for occurrence mode.
  --
  -- Any keymaps set using this `map` function will automatically be
  -- buffer-local and will be removed when occurrence mode is deactivated.
  --
  -- Receives a function with the same signature as `:h vim.keymap.set`:
  --`map(mode, lhs, rhs, opts)`
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

The `status()` function returns `nil` if there is no active occurrence, otherwise returns:

- `current`: Current match index
- `total`: Total number of matches
- `exact_match`: 1 if cursor is on a match, 0 otherwise
- `marked_only`: Whether counting only marked occurrences

# Usage Examples

Some examples of possible workflows using `occurrence.nvim`.

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

setup
: `require('occurrence').setup(opts)`

Configure the plugin. See [Configuration](#configuration) for available options.
**Note:** calling `setup()` is **not required** unless you intend to customize settings!

status
: `require('occurrence').status(opts)`

Get occurrence count information for statusline (or other) integrations.

**Parameters:**

- `opts` (table, optional):
  - `marked` (boolean): Count only marked occurrences (default: `false`)
  - `buffer` (integer): Buffer number (default: current buffer)

**Returns:**

- `nil` if no active occurrence
- or a table with fields:
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

word

: `require('occurrence').word()`  
`:Occurrence word`  
`<Plug>(OccurrenceWord)`

Find occurrences of word under cursor, mark all matches, and activate occurrence mode

selection

: `require('occurrence').selection()`  
`:Occurrence selection`  
`<Plug>(OccurrenceSelection)`

Find occurrences of the current visual selection, mark all matches, and activate occurrence mode

pattern

: `require('occurrence').pattern()`  
`:Occurrence pattern`  
`<Plug>(OccurrencePattern)`

Find occurrences of the last search pattern, mark all matches, and activate occurrence mode

current

: `require('occurrence').current()`  
`:Occurrence current`  
`<Plug>(OccurrenceCurrent)`

Smart entry action that adapts to the current context. In visual mode: acts like `selection`. Otherwise, if `:h hlsearch` is active: acts like `pattern`. Otherwise: acts like `word`. Marks all matches and activates occurrence mode

toggle

: `require('occurrence').toggle()`  
`:Occurrence toggle`  
`<Plug>(OccurrenceToggle)`

Smart toggle action that activates occurrence mode or toggles marks. In normal mode: If no patterns exist, acts like `word` to start occurrence mode. Otherwise, toggles the mark on the match under the cursor, or adds a new word pattern if not on a match. In visual mode: If no patterns exist, acts like `selection` to start occurrence mode. Otherwise, toggles marks on all matches within the selection, or adds a new selection pattern if no matches.

deactivate

: `require('occurrence').deactivate()`  
`:Occurrence deactivate`  
`<Plug>(OccurrenceDeactivate)`

Clear all marks and patterns, and deactivate occurrence mode

modify_operator

: `require('occurrence').modify_operator()`  
`:Occurrence modify_operator`  
`<Plug>(OccurrenceModifyOperator)`

Modify a pending operator to act on occurrences of the word under the cursor. Only useful in operator-pending mode (e.g., `c`, `d`, etc.)

Note that this action does not activate occurrence mode. It simply modifies the pending operator to act on occurrences within the specified range.

### Occurrence Mode Actions

Actions available when occurrence mode is active:

next

: `require('occurrence').next()`  
`:Occurrence next`

Move to the next marked occurrence

previous

: `require('occurrence').previous()`  
`:Occurrence previous`

Move to the previous marked occurrence

match_next

: `require('occurrence').match_next()`  
`:Occurrence match_next`

Move to the next occurrence match, whether marked or unmarked

match_previous

: `require('occurrence').match_previous()`  
`:Occurrence match_previous`

Move to the previous occurrence match, whether marked or unmarked

mark

: `require('occurrence').mark()`  
`:Occurrence mark`

Mark the occurrence match nearest to the cursor

unmark

: `require('occurrence').unmark()`  
`:Occurrence unmark`

Unmark the occurrence match nearest to the cursor

mark_all

: `require('occurrence').mark_all()`  
`:Occurrence mark_all`

Mark all occurrence matches in the buffer

unmark_all

: `require('occurrence').unmark_all()`  
`:Occurrence unmark_all`

Unmark all occurrence matches in the buffer

mark_in_selection

: `require('occurrence').mark_in_selection()`  
`:Occurrence mark_in_selection`

Mark all occurrence matches in the current visual selection

unmark_in_selection

: `require('occurrence').unmark_in_selection()`  
`:Occurrence unmark_in_selection`

Unmark all occurrence matches in the current visual selection

## Builtin Operators

The following operators are supported via `modify_operator` or with marked occurrences (configured via `operators` table):

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

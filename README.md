# occurrence.nvim

A Neovim plugin to mark occurrences of words/patterns in a buffer and perform operations on them.

Inspired by [vim-mode-plus]'s occurrence feature.

## Features

- 🔍 **Smart Occurrence Detection**: Find word under cursor, visual selections, or last search patterns
- 🎯 **Visual Feedback**: occurrences are highlighted. Status shows current/total counts
- ⚡ **Operator Integration**: Use native vim operators (`c`, `d`, `y`, etc.) on occurrences
- 🎮 **Multiple Interaction Modes**: Select occurrences and then operate, or modify a pending operation to target occurrences
- 🔧 **Highly Configurable**: Customize keymaps, operators, and behavior

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "occurrence.nvim",
  config = function()
    require("occurrence").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "occurrence.nvim",
  config = function()
    require("occurrence").setup()
  end,
}
```

## Quick Start

With the default configuration, you can try these workflows to get a feel for `occurrence.nvim`.

### Operator-pending mode

You can modify most vim operators to work on occurrences of the word under cursor:

1. **Choose operator**: Start an operation like `c`, `d`, `y`
2. **Modify operator**: Press `o` to enter occurrence operator-modifier mode
3. **Choose range**: Use vim motions like `$`, `ip`, etc. to apply to occurrences in that range

### Occurrence mode

Alternatively, you can first mark occurrences and then operate on them.

#### Marking occurrences

Marking occurrences can be done in several ways:

- **Word under cursor**: Place cursor on a word and press `go` in normal mode
- **Visual selection**: Select text in visual mode and press `go`
- **Last search pattern**: After searching with `/pattern` or `?pattern`, press `go` in normal mode

Once occurrences are marked, you can navigate, add and remove them:

- **Navigate**: Use `n`/`N` to jump between marked occurrences, or `gn`/`gN` for all occurrences
- **Mark individual**: `ga` to mark current occurrence, `gx` to unmark
- **Toggle mark**: `go` to toggle mark on current occurrence

#### Operating on marked occurrences

With occurrences marked, you can perform operations on them in several ways:

1. **Choose operation**: Use vim operators like `c` (change), `d` (delete), `y` (yank) on marked occurrences
2. **Choose range**: Use vim motions like `$`, `ip`, etc. to apply operator to occurrences in that range

Or, you can use visual mode:

1. **Start visual mode**: Press `v` to enter visual mode, or `V` for visual line mode
2. **Select range**: Use vim motions to select a range
3. **Choose operation**: Use vim operators like `c` (change), `d` (delete), `y` (yank) on marked occurrences in the visual range.

When you're done, press `<Esc>` to exit occurrence mode and clear all marks.

## Configuration

### Default Configuration

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

**Default Keymaps** (when `default_keymaps = true`):

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

### Custom Configuration Examples

#### Minimal Configuration

Disable default keymaps and set up custom ones:

```lua
require("occurrence").setup({
  default_keymaps = false,  -- Disable default keymaps
  on_activate = function(map)
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

#### Custom Keymaps

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
    map("n", "q", "<Plug>(OccurrenceDeactivate)")
  end,
})

-- Entry keymap
vim.keymap.set({ "n", "v" }, "<leader>o", "<Plug>(OccurrenceCurrent)")
```

#### Disable Specific Operators

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

#### Custom Line-Based Operators

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

### Statusline Integration

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

```lua
-- Example: statusline function with icons
function _G.occurrence_statusline()
  local count = require('occurrence').status({ marked = true })
  if not count then
    return ""
  end

  local icon = count.exact_match == 1 and "" or "󰍉"
  return string.format("%s %d/%d", icon, count.current, count.total)
end

-- Add to your statusline
vim.opt.statusline = "%f %{%v:lua.occurrence_statusline()%}"
```

**API: `require('occurrence').status(opts)`**

Returns `nil` if no active occurrence, otherwise returns:

- `current` (integer): Current match index (1-based)
- `total` (integer): Total number of matches
- `exact_match` (integer): 1 if cursor is on a match, 0 otherwise
- `marked_only` (boolean): Whether counting only marked occurrences

Options:

- `marked` (boolean): Count only marked occurrences (default: false)
- `buffer` (integer): Buffer number (default: current buffer)

## Example Workflows

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

## API Reference

### Lua API

occurrence.nvim provides a Lua API for programmatic control:

#### `require('occurrence').setup(opts)`

Configure the plugin. See [Configuration](#configuration) for available options.

**Note:** calling `setup()` is **not required** unless you intend to customize settings!

#### `require('occurrence').status(opts)`

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

**Example:**

```lua
local count = require('occurrence').status()
if count then
  print(string.format("Match %d of %d", count.current, count.total))
end
```

### Actions

All actions are available in three ways:

- **Lua API**: `require('occurrence').<action>()`
- **Vim commands**: `:Occurrence <action>`
- **<Plug> mappings**: `<Plug>(Occurrence<Action>)`

**Example usage:**

```lua
local occurrence = require('occurrence')

-- Entry actions (activate occurrence mode)
occurrence.word()      -- Mark word under cursor
occurrence.current()   -- Smart: selection, pattern, or word

-- Navigation (when occurrence mode is active)
occurrence.next()      -- Next marked occurrence
occurrence.mark()      -- Mark current occurrence
occurrence.deactivate() -- Exit occurrence mode
```

#### Entry Actions

Actions that activate occurrence mode:

| Action      | <Plug> Mapping                | Description                                           |
| ----------- | ----------------------------- | ----------------------------------------------------- |
| `word`      | `<Plug>(OccurrenceWord)`      | Find occurrences of word under cursor                 |
| `selection` | `<Plug>(OccurrenceSelection)` | Find occurrences of visual selection                  |
| `pattern`   | `<Plug>(OccurrencePattern)`   | Find occurrences of last search pattern               |
| `current`   | `<Plug>(OccurrenceCurrent)`   | Find occurrences (smart: selection, pattern, or word) |

#### Occurrence Mode Actions

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

#### Operator Modifier

Actions to modify operator-pending mode to work on occurrences:

| Action            | <Plug> Mapping                     | Description                                       |
| ----------------- | ---------------------------------- | ------------------------------------------------- |
| `modify_operator` | `<Plug>(OccurrenceModifyOperator)` | Modifier for operator-pending mode (e.g., `doip`) |

#### Operators

Operators that work on marked occurrences (configured via `operators` table):

| Operator        | Default Key | Description                                                       |
| --------------- | ----------- | ----------------------------------------------------------------- |
| `change`        | `c`         | Change marked occurrences (prompts for replacement)               |
| `delete`        | `d`         | Delete marked occurrences                                         |
| `yank`          | `y`         | Yank marked occurrences to register                               |
| `put`           | `p`         | Put register content at marked occurrences (replicates same text) |
| `distribute`    | `gp`        | Distribute lines from register cyclically across occurrences      |
| `indent_left`   | `<`         | Indent left                                                       |
| `indent_right`  | `>`         | Indent right                                                      |
| `indent_format` | `=`         | Indent/format                                                     |
| `uppercase`     | `gU`        | Convert to uppercase                                              |
| `lowercase`     | `gu`        | Convert to lowercase                                              |
| `swap_case`     | `g~`        | Swap case                                                         |
| `rot13`         | `g?`        | ROT13 encoding                                                    |

<!-- panvimdoc-ignore-start -->

## Development

See [CONTRIBUTING](./CONTRIBUTING.md) for contribution guidelines.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-ignore-start -->

## License

[MIT](./LICENSE)

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-ignore-start -->

[vim-mode-plus]: https://github.com/t9md/atom-vim-mode-plus?tab=readme-ov-file#some-features
[panvimdoc]: https://github.com/kdheepak/panvimdoc
[LuaCATS]: https://luals.github.io/wiki/annotations/
[LuaRocks]: https://luarocks.org/modules/lettertwo/occurrence.nvim
[busted]: https://github.com/lunarmodules/busted

<!-- panvimdoc-ignore-end -->

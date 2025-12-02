# occurrence.nvim

A Neovim plugin to mark occurrences of words/patterns/selections in a buffer and perform operations on them.

<!-- panvimdoc-ignore-start -->

Inspired by [vim-mode-plus]'s occurrence feature.

## Key Features

### 🔍 Smart Occurrence Detection

- Word under cursor with boundary matching
- Visual selections (character, line, or block)
- Last search pattern from `/` or `?`
- Automatic pattern escaping and vim regex support

### ⚡ Native and Custom Operator Integration

- Use standard Vim operators: `c`, `d`, `y`, `p`, `<`, `>`, `=`, `gu`, `gU`, `g~`
- Define custom operators to work with occurrences
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
  ---@module "occurrence"
  ---@type occurrence.Options
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
- **Add matches**: `ga` to add a new occurrence
- **Remove marks**: `gx` to unmark current occurrence
- **Toggle individual marks**: `go` to toggle mark on current occurrence

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
  -- e.g., `vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceMark)")``
  -- or `vim.keymap.set("o", "<C-o>", "<Plug>(OccurrenceModifyOperator)")`.
  --
  -- Additionally, when `false`, only keymaps explicitly defined in `keymaps`
  -- will be automatically set when activating occurrence mode. Keymaps for
  -- occurrence mode can also be set manually in an `OccurrenceActivate`
  -- autocmd using `occurrence.keymap:set(...)`.
  --
  -- Default `operators` will still be set unless `default_operators` is also `false`.
  --
  -- Defaults to `true`.
  default_keymaps = true,

  -- Whether to include default operator support.
  -- (c, d, y, p, gp, <, >, =, gu, gU, g~)
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
  -- Each key is a string representing either the operator key or
  -- a custom operator name, and each value is either:
  --   - a string representing the name of a builtin or custom operator,
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
  },
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
- All configured operators (`c`, `d`, `y`, `p`, `gp`, `<`, `>`, `=`, `gu`, `gU`, `g~`)

## Keymaps

You can disable default keymaps and set up custom ones:

```lua
require("occurrence").setup({
  -- NOTE: If you disable default keymaps
  -- you'll want a way to exit occurrence mode!
  default_keymaps = false,  -- Disable defaults
  keymaps = {
    -- Custom navigation
    ["<Tab>"] = "next",
    ["<S-Tab>"] = "previous",
    ["q"] = "deactivate",  -- Exit occurrence mode
  },
})

-- Set up custom keymaps using <Plug> mappings
vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceMark)")

-- Or using the `:Occurrence` command:
vim.keymap.set("v", "<C-o>", "<cmd>Occurrence toggle<CR>")

-- Or using Lua API:
vim.keymap.set("o", "<C-o>", function()
  require('occurrence').modify_operator()
end)

-- Set up custom keymaps on occurrence activation.
-- These keymaps will be buffer-local and active only in occurrence mode.
vim.api.nvim_create_autocmd("User", {
  pattern = "OccurrenceActivate",
  callback = function(e)
    local occurrence = require("occurrence").get(e.buf)
    if occurrence and not occurrence:is_disposed() then
      -- Batch operations
      occurrence.keymap:set("n", "<leader>a", function()
        assert(require("occurrence").get()):mark_all()
      end)
      occurrence.keymap:set("n", "<leader>x", function()
        assert(require("occurrence").get()):unmark_all()
      end)
    end
  end,
})
```

## Operators

Similarly to keymaps, you can disable default operators and set up custom ones.

```lua
require("occurrence").setup({
  default_operators = false,  -- Disable all defaults
  operators = {
    ["c"] = "change", -- Keep default change operator
    ["d"] = "delete", -- Keep default delete operator
    ["g~"] = false,  -- Disable swap case (if `default_operators` were `true`)
    -- Define a custom operator:
    ["upper_first"] = {
      desc = "Uppercase first letter",
      ---@type occurrence.OperatorFn
      operator = function(current)
        local text = current.text
        text[1] = text[1]:gsub("^%l", string.upper)
        return text
      end
    },
    -- and bind it to a key:
    ["gU"] = "upper_first",
    -- or define it to a key directly:
    ["gu"] = {
      desc = "Lowercase first letter",
      ---@type occurrence.OperatorFn
      operator = function(current)
        local text = current.text
        text[1] = text[1]:gsub("^%u", string.lower)
        return text
      end
    },
  },
})
```

For more on defining custom operators, see [Custom Operators](#custom-operators).

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
ga          " Mark all 'bar' occurrences as well
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

# Command Usage

The `:Occurrence` command provides access to all builtin actions and operators. It features basic completion for subcommands, count and range modifiers for fine-grained control, and arguments for specific actions.

Actions can be invoked via the `:Occurrence` command:

```vim
:Occurrence mark          " Mark occurrences of word under cursor
:Occurrence toggle        " Toggle mark at cursor position
:Occurrence next          " Navigate to next marked occurrence
:Occurrence deactivate    " Clear all marks
```

And some can take arguments:

```vim
:Occurrence mark \w\s\s    " Mark occurrences of a pattern
:Occurrence toggle foo     " Toggle the next occurrence of 'foo'
:Occurrence next 2         " Move to the 2nd next marked occurrence
```

Operators will trigger operator-pending mode and then operate on marked occurrences:

```vim
:Occurrence delete        " Delete all marked occurrences
:Occurrence change        " Change all marked occurrences (prompts for input)
:Occurrence yank          " Yank all marked occurrences to register
:Occurrence uppercase     " Convert all marked to uppercase
```

And any that use a register can specify which register to use:

```vim
:Occurrence delete b      " Delete all marked occurrences to register 'b'
:Occurrence put b         " Put register 'b' content at all marked occurrences
```

### Count Modifier

Prefix the command with a count to limit operations to the first N marked occurrences:

```vim
:3Occurrence delete       " Delete only the first 3 marked occurrences
:5Occurrence yank         " Yank only the first 5 marked occurrences
:2Occurrence uppercase    " Uppercase only the first 2 marked occurrences
```

Or to limit the number of marked occurrences:

```vim
:4Occurrence mark       " Mark only the first 4 occurrences
:3Occurrence next       " Navigate to the 3rd marked occurrence
```

### Range Modifier

Use a range to operate only on marked occurrences within specific lines:

```vim
:2,5Occurrence delete     " Delete marks only in lines 2-5
:'<,'>Occurrence change   " Change marks only in visual selection
```

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
  require('occurrence').mark()
  ```

- **Vim commands**:

  ```vim
  :Occurrence mark
  ```

- **<Plug> mappings**:

  ```vim
  <Plug>(OccurrenceMark)
  ```

modify_operator

: `require('occurrence').modify_operator()`  
`:Occurrence modify_operator`  
`<Plug>(OccurrenceModifyOperator)`

Modify a pending operator to act on occurrences of the word under the cursor. Only useful in operator-pending mode (e.g., `c`, `d`, etc.)

Once a pending operator is modified, the operator will act on occurrences within the range specified by the subsequent motion.

Note that this action does not activate occurrence mode, and it does not have any effect when occurrence mode is active, as operators already act on occurrences in that mode.

mark

: `require('occurrence').mark()`  
`:Occurrence mark`  
`<Plug>(OccurrenceMark)`

Mark one or more occurrences and activate occurrence mode.

If occurrence already has matches, mark matches based on:

- In visual mode, if matches exist in the range of the visual selection, mark those matches.
- Otherwise, if a match exists at the cursor, mark that match.

If no occurrence match exists to satisfy the above, add a new pattern based on:

- In visual mode, mark occurrences of the visual selection.
- If `:h hlsearch` is active, mark occurrences of the search pattern.
- Otherwise, mark occurrences of the word under the cursor.

unmark

: `require('occurrence').unmark()`  
`:Occurrence unmark`  
`<Plug>(OccurrenceUnmark)`

Unmark one or more occurrences.

If occurrence has matches, unmark matches based on:

- In visual mode, unmark matches in the range of the visual selection.
- Otherwise, if a match exists at the cursor, unmark that match.

If no match exists to satisfy the above, does nothing.

toggle

: `require('occurrence').toggle()`  
`:Occurrence toggle`  
`<Plug>(OccurrenceToggle)`

Mark or unmark one (or more) occurrence(s) and activate occurrence mode.

If occurrence already has matches, toggle matches based on:

- In visual mode, if matches exist in the range of the visual selection, toggle marks on those matches.
- Otherwise, if a match exists at the cursor, toggle that mark.

If no occurrence match exists to satisfy the above, add a new pattern based on:

- In visual mode, mark the closest occurrence of the visual selection.
- If `:h hlsearch` is active, mark the closest occurrence of the search pattern.
- Otherwise, mark the closest occurrence of the word under the cursor.

next

: `require('occurrence').next()`  
`:Occurrence next`  
`<Plug>(OccurrenceNext)`

Move to the next marked occurrence and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the next marked occurrence.

previous

: `require('occurrence').previous()`  
`:Occurrence previous`  
`<Plug>(OccurrencePrevious)`

Move to the previous marked occurrence and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the previous marked occurrence.

match_next

: `require('occurrence').match_next()`  
`:Occurrence match_next`  
`<Plug>(OccurrenceMatchNext)`

Move to the next occurrence match, whether marked or unmarked, and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the next occurrence match.

match_previous

: `require('occurrence').match_previous()`  
`:Occurrence match_previous`  
`<Plug>(OccurrenceMatchPrevious)`

Move to the previous occurrence match, whether marked or unmarked, and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the previous occurrence match.

deactivate

: `require('occurrence').deactivate()`  
`:Occurrence deactivate`  
`<Plug>(OccurrenceDeactivate)`

Clear all marks and patterns, and deactivate occurrence mode.

# Builtin Operators

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
| `indent_format` | `=`  | Format through `:h equalprg`                                      |
| `uppercase`     | `gU` | Convert to uppercase                                              |
| `lowercase`     | `gu` | Convert to lowercase                                              |
| `swap_case`     | `g~` | Swap case                                                         |

These operators are also available as API methods, e.g.,:

```lua
require("occurrence").change()
require("occurrence").delete()
```

And as subcommands, e.g.,:

```vim
:Occurrence change
:Occurrence delete
```

# Custom Operators

## Custom Line-Based Operators

A custom operator defined via `operators` will always expect a motion or visual selection.
To define a custom operator that operates on a fixed motion, define it as a keymap instead.
For example, you could define operators that work on marked occurrences on the current line:

```lua
require("occurrence").setup({
  -- Define them as custom keymaps:
  keymaps = {
    -- dd - Delete marked occurrences on current line
    ["dd"] = {
      mode = "n",
      desc = "Delete marked occurrences on line",
      callback = function(occ)
        local range = require("occurrence.Range").of_line()
        occ:apply_operator("delete", { motion = range, motion_type = "line" })
      end,
    },
    -- D - Delete marked occurrences from cursor to end of line
    ["D"] = {
      mode = "n",
      desc = "Delete marked occurrences from cursor to end of line",
      callback = function(occ)
        occ:apply_operator("delete", { motion = "$" })
      end,
    },
  },
})
-- or use the `OccurrenceActivate` autocmd to set them up.
vim.api.nvim_create_autocmd("User", {
  pattern = "OccurrenceActivate",
  callback = function(e)
    local occurrence = require("occurrence").get(e.buf)
    if occurrence and not occurrence:is_disposed() then
      -- cc - Change marked occurrences on current line
      occurrence.keymap:set("n", "cc", function()
        local range = require("occurrence.Range").of_line()
        occurrence:apply_operator("change", { motion = range, motion_type = "line" })
      end, { desc = "Change marked occurrences on line" })
      -- C - Change marked occurrences from cursor to end of line
      occurrence.keymap:set("n", "C", function()
        occurrence:apply_operator("change", { motion = "$" })
      end, { desc = "Change marked occurrences from cursor to end of line" })
    end
  end,
})
```

# Events

occurrence.nvim triggers custom User events that you can listen to with autocommands. These events allow you to react to occurrence lifecycle changes and integrate with other plugins or workflows.

## OccurrenceCreate

Triggered when an occurrence instance is first created for a buffer.

**When it fires:**

- First time an occurrence action is used in a buffer
- When `Occurrence.get(bufnr)` creates a new instance

**Does NOT fire:**

- When occurrence mode is activated (use `OccurrenceActivate` instead)
- When patterns or marks are added to an existing occurrence

**Event data:**

- `buf` (integer): Buffer number where occurrence was created

**Example:**

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OccurrenceCreate",
  callback = function(event)
    -- get the occurrence instance
    local occurrence = require("occurrence").get(event.buf)
    print("Occurrence created in buffer " .. event.buf)
    print("Initial pattern: " .. vim.inspect(occurrence.patterns))
  end,
})
```

## OccurrenceActivate

Triggered when occurrence mode is activated in a buffer.

**When it fires:**

- When occurrence mode keymaps are activated
- After an occurrence-mode action completes successfully (e.g., `mark`, `toggle`)

**Does NOT fire:**

- When occurrence instance is created without activating mode
- When already in occurrence mode
- When using operator-modifier mode (`doip`)

**Event data:**

- `buf` (integer): Buffer number where occurrence mode was activated

**Example:**

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OccurrenceActivate",
  callback = function(event)
    local occurrence = require("occurrence").get(event.buf)
    if occurrence and not occurrence:is_disposed() then
      -- Set up buffer-local keymaps that are only active in occurrence mode
      occurrence.keymap:set("n", "<leader>a", function()
        assert(require("occurrence").get()):mark_all()
      end, { desc = "Mark all occurrences" })

      occurrence.keymap:set("n", "<leader>x", function()
        assert(require("occurrence").get()):unmark_all()
      end, { desc = "Unmark all occurrences" })
    end
  end,
})
```

## OccurrenceUpdate

Triggered when an occurrence instance is updated with new patterns or marks.

**When it fires:**

- When new patterns are added
- When marks are added or removed

**Does NOT fire:**

- When occurrence instance is created without patterns or marks
- When occurrence mode is activated (use `OccurrenceActivate` instead)
- When occurrence instance is disposed (use `OccurrenceDispose` instead)

**Event data:**

- `buf` (integer): Buffer number where occurrence was updated

**Example:**

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OccurrenceUpdate",
  callback = function(event)
    print(vim.inspect(require("occurrence").status({ buffer = event.buf })))
  end,
})
```

## OccurrenceDispose

Triggered when an occurrence instance is disposed and its resources are cleaned up.

**When it fires:**

- When exiting occurrence mode (e.g., pressing `<Esc>` or `q`)
- When `Occurrence.del(bufnr)` is called
- When the buffer is deleted
- When all marks are cleared and occurrence is no longer needed

**Does NOT fire:**

- When marks are cleared but occurrence mode remains active

**Event data:**

- `buf` (integer): Buffer number where occurrence was disposed

**Example:**

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OccurrenceDispose",
  callback = function(event)
    print("Occurrence disposed in buffer " .. event.buf)
    -- Clean up any custom state associated with this occurrence
  end,
})
```

<!-- panvimdoc-ignore-start -->

# Development

See [CONTRIBUTING](./CONTRIBUTING.md) for contribution guidelines.

# License

[MIT](./LICENSE)

[vim-mode-plus]: https://github.com/t9md/atom-vim-mode-plus?tab=readme-ov-file#some-features

<!-- panvimdoc-ignore-end -->

# occurrence.nvim

A Neovim plugin to mark occurrences of words/patterns/selections in a buffer and perform operations on them.

<!-- panvimdoc-ignore-start -->

Inspired by [vim-mode-plus]'s occurrence feature.

## Key Features

### 🔍 Smart Occurrence Detection

- Word under cursor with boundary matching
- Visual selections (character, line, or block)
- Last search pattern from `/` or `?`

### ⚡ Native and Custom Operator Integration

- Use standard Vim operators: `c`, `d`, `y`, `p`, `<`, `>`, `=`, `gu`, `gU`, `g~`
- Define custom operators to work with occurrences
- Two interaction modes: mark-then-operate or operator-pending modifier
- Works with motions and text objects (`ip`, `$`, `G`, etc.)
- Dot-repeat support for all operations

### 🎯 Visual Feedback

- Real-time highlighting of all matches and marked occurrences
- Current occurrence highlighting during navigation
- Status API for showing current/total counts

### 🛠️ Highly Configurable

- Enable/disable default keymaps or define custom ones
- Choose which operators to enable or disable, or add custom ones
- Customizable highlight groups
- Lua API for advanced usage and integration

### Demos

#### Using the occurrence operator-modifier

The sequence `gUoip` uppercases occurrences of the word under the cursor in the current paragraph.

https://github.com/user-attachments/assets/2c7bb264-b93d-4f21-ad5f-f8d6b17550b8

The `o` operator-modifier can be used with any operator and motion, e.g., `yog}` yanks occurrences to the end of the paragraph, `gUoG` uppercases occurrences to the end of the paragraph, etc.

#### Using the operator-modifier with a count

The sequence `d2oj` deletes the first 2 occurrences of the word under the cursor until the next line.

https://github.com/user-attachments/assets/ba898088-689b-4708-9dec-763cc2ea0dda

#### Selective editing in occurrence mode

This example shows marking occurrences of a selection and then unmarking one of them before changing the rest.

https://github.com/user-attachments/assets/858ae5c6-8f9e-4408-ad60-52938b082782

<!-- panvimdoc-ignore-end -->

# Installation

### Requirements

- Neovim >= 0.10.0
- Neovim >= 0.13.0 for native multicursor features (`cursors`, `cursors_start`, `cursors_end`, `change_cursors`; see [Custom Integrations](#custom-integrations))

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "lettertwo/occurrence.nvim",
  lazy = false,
  ---@module "occurrence"
  ---@type occurrence.Options
  -- opts = {} -- setup is optional; the defaults will work out of the box.
}
```

### Note on lazy loading:

`occurrence.nvim` is designed to progressively load by default, so it is not necessary to configure the plugin manager for lazy loading.
However, if you wish to explicitly control loading, you can disable the auto setup behavior:

```lua
{
  "lettertwo/occurrence.nvim",
  init = function()
    -- Prevents automatic setup on load
    vim.g.occurrence_auto_setup = false
  end,
  -- Explicitly load on specific keys.
  keys = {
    { "go", "<Plug>(OccurrenceMark)", mode = { "n", "v" }, desc = "Mark occurrences" },
    { "o", "<Plug>(OccurrenceModifyOperator)", mode = "o", desc = "Modify operator for occurrences" },
  },
}
```

### Using :h vim.pack

```lua
vim.pack.add("lettertwo/occurrence.nvim")
-- require("occurrence").setup({}) -- setup is optional; the defaults will work out of the box.
```

# Migrating from v1 to v2

**Breaking change:** occurrence mode now exits automatically after an operator
completes (`dispose_after_operator = true` by default). In v1, occurrence mode
persisted after an operator unless all marks were consumed.

If you relied on the old behavior — for example, chaining several operators on
the same set of marks — restore it globally:

```lua
require("occurrence").setup({ dispose_after_operator = false })
```

You can also opt out for individual operators, or flip the decision for a single
operator at runtime with the `toggle_dispose` action. See
[Disposing after operators](#disposing-after-operators).

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

By default, occurrence mode exits automatically once the operator completes. If
you'd rather keep it active to chain more operators, see
[Disposing after operators](#disposing-after-operators). You can always press
`<Esc>` to exit occurrence mode manually.

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

By default, occurrence mode exits automatically after the operator completes. To
keep it active for chaining further operations, set `dispose_after_operator = false`
(see [Disposing after operators](#disposing-after-operators)). You can also press
`<Esc>` at any time to exit occurrence mode and clear all marks.

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
  -- (c, d, y, p, gp, <, >, =, gu, gU, g~; on Neovim >= 0.13 with
  -- `nvim_mcursor`, `c` maps to `change_cursors` and I, A are added)
  --
  -- If `false`, only operators explicitly defined in `operators`
  -- will be supported.
  --
  -- Defaults to `true`.
  default_operators = true,

  -- Whether to exit occurrence mode after an operator completes.
  --
  -- When `true`, occurrence mode is disposed once any operator finishes,
  -- so a typical mark-then-operate sequence does not need a trailing
  -- `<Esc>` to clean up.
  --
  -- When `false`, occurrence mode persists after an operator (the pre-v2
  -- behavior), letting you chain multiple operators on the same marks until
  -- you exit explicitly.
  --
  -- Can be overridden per-operator via the operator's own
  -- `dispose_after_operator` field, and inverted for a single operator at
  -- runtime via the `toggle_dispose` action (which only applies to operators
  -- without their own value).
  --
  -- Defaults to `true`.
  dispose_after_operator = true,

  -- Whether native multicursors created by `cursors`, `cursors_start`,
  -- `cursors_end`, and `change_cursors` start in follow-mode (`:h q=`), so
  -- motions replay at every cursor and not just the primary. Toggle at
  -- runtime with the native `q=` command. Neovim >= 0.13 only.
  --
  -- Defaults to `true`.
  follow_cursors = true,

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
    ["Q"] = "cursors",                  -- Convert marks to native cursors (Neovim >= 0.13 only)
  },

  -- A table defining operators that can be modified to operate on occurrences.
  -- These operators will also be active as keymaps in occurrence mode.
  -- Each key is a string representing either the operator key or
  -- a custom operator name, and each value is either:
  --   - a string representing the name of a builtin or custom operator,
  --   - a table defining a custom operator configuration,
  --   - or `false` to disable the operator.
  operators = {
    ["c"] = "change",             -- Change marked occurrences ("change_cursors" on Neovim >= 0.13)
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
    ["I"] = "cursors_start",      -- Convert marks in motion to cursors at their start (Neovim >= 0.13 only)
    ["A"] = "cursors_end",        -- Convert marks in motion to cursors on their last char (Neovim >= 0.13 only)
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
- `go` - Toggle mark on current occurrence or word
- `ga` - Mark or current occurrence or add word
- `gx` - Unmark current occurrence
- `<Esc>`, `<C-c>`, `<C-[>` - Exit occurrence mode
- `Q` - Convert marks to native cursors and exit occurrence mode (Neovim >= 0.13 only; see [Custom Integrations](#custom-integrations))
- All configured operators (`c`, `d`, `y`, `p`, `gp`, `<`, `>`, `=`, `gu`, `gU`, `g~`, and on Neovim >= 0.13: `I`, `A`, with `c` handing off to native cursors)

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

### Disposing after operators

By default, occurrence mode exits as soon as an operator completes
(`dispose_after_operator = true`). Individual operators can override this with
their own `dispose_after_operator` field, which takes precedence over the global
option:

```lua
require("occurrence").setup({
  -- Keep occurrence mode active after operators globally...
  dispose_after_operator = false,
  operators = {
    -- ...but exit after this one specifically.
    ["d"] = {
      desc = "Delete marked occurrences",
      operator = function()
        return {}
      end,
      dispose_after_operator = true,
    },
  },
})
```

Resolution order is: per-operator value, then the global option, then the
default of `true`.

To flip the decision for just the next operator at runtime, use the
`toggle_dispose` action (see [Actions](#actions)). It only applies to operators
that resolve through the global option: an operator with its own
`dispose_after_operator` keeps that value, and a pending toggle is consumed
without effect. The built-in cursor operators force `true` this way, since
occurrence mode cannot outlive a native multicursor session. The action has no
default keymap; bind it via `<Plug>(OccurrenceToggleDispose)` if you want it:

```lua
vim.keymap.set({ "n", "v" }, "<leader>od", "<Plug>(OccurrenceToggleDispose)")
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
local occurrence_status = {
  function()
    local count = require('occurrence').status()
    if not count then
      return ""
    end
    return string.format("[%d/%d]", count.current, count.total)
  end,
  cond = function()
    -- Only show if occurrence.nvim is loaded
    return package.loaded["occurrence"] ~= nil
  end,
}

require('lualine').setup({
  sections = {
    lualine_c = { 'filename', occurrence_status },
  }
})
```

The `status()` function returns `nil` if there is no active occurrence. Otherwise, it returns:

- `current`: Current match index
- `total`: Total number of matches
- `exact_match`: 1 if cursor is on a match, 0 otherwise
- `marked_only`: Whether counting only marked occurrences

# Usage Examples

Some examples of possible workflows using `occurrence.nvim`.

### Example: Selective Editing

Change only some occurrences of a word:

> On Neovim 0.13+, `c` defaults to `change_cursors` (a native multicursor handoff). This example uses the prompt-based `change`; add `operators = { c = "change" }` to your setup to follow it verbatim.

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

> On Neovim 0.13+, `c` defaults to `change_cursors` (a native multicursor handoff). This example uses the prompt-based `change`; add `operators = { c = "change" }` to your setup to follow it verbatim.

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

### Enumerating builtins

The `occurrence.api` module exposes the built-in operators and actions as named
sub-tables, so you can enumerate them without filtering the flat table:

```lua
local api = require("occurrence.api")

for name, config in pairs(api.operators) do
  -- name: e.g. "change", "delete", "yank", ...
  -- config: the occurrence.OperatorConfig descriptor
end

for name, config in pairs(api.actions) do
  -- name: e.g. "mark", "toggle", "deactivate", "toggle_dispose", ...
end
```

Flat access (e.g. `api.change`, `api.mark`) is still supported for backward
compatibility.

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

**modify_operator**

: `require('occurrence').modify_operator()`  
`:Occurrence modify_operator`  
`<Plug>(OccurrenceModifyOperator)`

Modify a pending operator to act on occurrences of the word under the cursor. Only useful in operator-pending mode (e.g., `c`, `d`, etc.)

On Neovim >= 0.13, if native multicursors exist in the buffer, import the keyword under each cursor as a pattern and clear the cursors instead of using the word under the window cursor.

Once a pending operator is modified, the operator will act on occurrences within the range specified by the subsequent motion.

Note that this action does not activate occurrence mode, and it does not have any effect when occurrence mode is active, as operators already act on occurrences in that mode.

**mark**

: `require('occurrence').mark()`  
`:Occurrence mark`  
`<Plug>(OccurrenceMark)`

Mark one or more occurrences and activate occurrence mode.

- On Neovim >= 0.13, if native multicursors exist in the buffer, import the keyword under each cursor as a pattern and clear the cursors. Every occurrence is marked; with a count, only `count` matches from each cursor. Cursors not on a keyword are skipped with a warning.

If occurrence already has matches, mark matches based on:

- In visual mode, if matches exist in the range of the visual selection, mark those matches.
- Otherwise, if a match exists at the cursor, mark that match.

If no occurrence match exists to satisfy the above, add a new pattern based on:

- In visual mode, mark occurrences of the visual selection.
- If `:h hlsearch` is active, mark occurrences of the search pattern.
- Otherwise, mark occurrences of the word under the cursor.

**unmark**

: `require('occurrence').unmark()`  
`:Occurrence unmark`  
`<Plug>(OccurrenceUnmark)`

Unmark one or more occurrences.

If occurrence has matches, unmark matches based on:

- In visual mode, unmark matches in the range of the visual selection.
- Otherwise, if a match exists at the cursor, unmark that match.

If no match exists to satisfy the above, does nothing.

**toggle**

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

**next**

: `require('occurrence').next()`  
`:Occurrence next`  
`<Plug>(OccurrenceNext)`

Move to the next marked occurrence and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the next marked occurrence.

**previous**

: `require('occurrence').previous()`  
`:Occurrence previous`  
`<Plug>(OccurrencePrevious)`

Move to the previous marked occurrence and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the previous marked occurrence.

**match_next**

: `require('occurrence').match_next()`  
`:Occurrence match_next`  
`<Plug>(OccurrenceMatchNext)`

Move to the next occurrence match, whether marked or unmarked, and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the next occurrence match.

**match_previous**

: `require('occurrence').match_previous()`  
`:Occurrence match_previous`  
`<Plug>(OccurrenceMatchPrevious)`

Move to the previous occurrence match, whether marked or unmarked, and activate occurrence mode.

If occurrence has no matches, acts like `mark` and then moves to the previous occurrence match.

**deactivate**

: `require('occurrence').deactivate()`  
`:Occurrence deactivate`  
`<Plug>(OccurrenceDeactivate)`

Clear all marks and patterns, and deactivate occurrence mode.

**toggle_dispose**

: `require('occurrence').toggle_dispose()`  
`:Occurrence toggle_dispose`  
`<Plug>(OccurrenceToggleDispose)`

Invert the `dispose_after_operator` decision for the next operator only.

- When `dispose_after_operator` is `true` (the default), this prevents occurrence
  mode from exiting after the next operator, enabling one-off chaining.
- When `dispose_after_operator` is `false`, this forces occurrence mode to exit
  after the next operator.
- An operator with its own `dispose_after_operator` is not inverted; its value
  wins, and the toggle is consumed anyway.

The inversion is one-shot: it is consumed when the next operator completes. Press
again before running an operator to cancel it.

This action has no default keymap. Bind it via `<Plug>(OccurrenceToggleDispose)`
if you want it.

**cursors**

: `require('occurrence').cursors()`  
`:Occurrence cursors`  
`<Plug>(OccurrenceCursors)`

Convert marked occurrences to native `:h multicursor` cursors and dispose
occurrence mode, handing the buffer over to Neovim.

In visual mode, only marks within the selection are converted; otherwise all
marks are converted. If occurrence has no matches yet, marks the word under
the cursor first (like `next`), then converts.

Requires Neovim >= 0.13 with `vim.api.nvim_mcursor`. Bound to `Q` by default
on supported Neovim versions; unavailable otherwise. See
[Custom Integrations](#custom-integrations) for details.

# Builtin Operators

The following operators are supported via `modify_operator` or with marked occurrences (configured via `operators` table). Exception: `cursors_start` and `cursors_end` are not reachable via `modify_operator` (e.g. `Ioip`), since `I`/`A` are not Vim operators and there is no pending operator for `o` to rewrite; use them as motion-scoped operator keys instead (e.g. `Iip`, `Aip`). `change_cursors` is a real operator, so it works both as `cip` in occurrence mode and as `coip` in operator-pending mode.

| Operator        | Key  | Description                                                       |
| --------------- | ---- | ----------------------------------------------------------------- |
| `change`        | `c`  | Change marked occurrences (prompts for replacement; Neovim < 0.13) |
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
| `cursors_start` | `I`  | Convert marks to cursors at their start (Neovim >= 0.13 only)     |
| `cursors_end`   | `A`  | Convert marks to cursors on their last character (Neovim >= 0.13) |
| `change_cursors`| `c`  | Delete marks, convert to cursors, and insert (Neovim >= 0.13 only)|

`cursors_start`, `cursors_end`, and `change_cursors` always dispose occurrence
mode after running, regardless of the global `dispose_after_operator` option,
since occurrence mode cannot coexist with a native multicursor session. See
[Custom Integrations](#custom-integrations) for details.

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

You can define custom operators to work with occurrences by configuring the `operators` table in `require("occurrence").setup({...})`.

**Key points about operators:**

- Async operations are sized to 10 concurrent operations by default (configurable via `batch_size`)
- The `before` hook runs once before processing marks
- The `operator` function runs for each mark
- The `after` hook runs once after all marks have been processed
- The `before` and `operator` can be async by returning a function that accepts `done`
- The `after` hook receives updated mark positions for post-processing

See the [Configuration](#configuration) section for simple examples of defining custom operators.

See the [Custom Operators and Integrations](https://github.com/lettertwo/occurrence.nvim/wiki/Custom-Operators-and-Integrations) wiki for complete documentation and advanced examples.

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

# Custom Integrations

occurrence.nvim can be integrated with other plugins to create powerful workflows through flexible action, operator, and event systems that provide easy access to the occurrence API.

## Native multicursor

On Neovim >= 0.13, marked occurrences can be handed off directly to Neovim's
built-in `:h multicursor`, no external plugin required:

- **`cursors`** (`Q` by default) - Convert all (or, in visual mode, selected)
  marks to cursors and exit occurrence mode.
- **`cursors_start`** / **`cursors_end`** (`I` / `A` by default) - Convert
  marks within a motion to cursors on their first or last character, e.g.
  `Iip`, `Aip`. After `Aip`, press `a` to append after every occurrence
  (cursors sit on the last character rather than past it, so marks that end
  at end-of-line behave like any other).
- **`change_cursors`** (`c` by default, also via `coip`) - Delete marks
  within a motion, convert them to cursors, and enter insert mode. This
  replaces the prompt-based `change` as the default `c` when native
  multicursor is available; restore the prompt with `operators = { c = "change" }`.

These always exit occurrence mode once cursors are placed, since native
multicursor has no mode of its own for occurrence to observe, and its
buffer-local keymaps would otherwise shadow native multicursor workflows
(`n`, `N`, `c`, `d`, ...). See [Actions](#actions) and
[Builtin Operators](#builtin-operators) for details.

Cursors start in follow-mode (`:h q=`), so motions such as `w`, `e`, or `f`
replay at every cursor. Set `follow_cursors = false` to leave that off, or press
the native `q=` after the handoff to toggle it for one session.

On Neovim < 0.13, these are unavailable and their default keys are not bound.

### Importing cursors

`mark` (`go`) and `modify_operator` (the `o` in `doip`) are the inverse of
`cursors`: if native cursors already exist in the buffer, they import each
cursor's keyword as a pattern, mark it, and clear the cursors, rather than
acting on the word under the window cursor. This makes a full round trip
possible: `go`, `Q`, `q=` plus motions to add cursors on other words,
`<Esc>`, `go` to bring everything back into occurrence mode, then any
operator (`d`, `y`, `gU`, ...) over the combined set. That set can mix
words, which native `1Q` alone cannot express.

A cursor that lands on whitespace, past end-of-line, or on an empty line has
no keyword to import; it is skipped and counted, with one warning reporting
how many were skipped. Plain `go` behaves differently: off a keyword it falls
back to the word `<cword>` finds nearby. An imported cursor is a deliberate
position, so it gets no such fallback.

Importing does not read the search register, so `:h hlsearch` is left as it
was.

See the [wiki](https://github.com/lettertwo/occurrence.nvim/wiki) for detailed examples, including:

- **[Multicursor](https://github.com/lettertwo/occurrence.nvim/wiki/Integration:-Multicursor-nvim)** - Spawn multiple cursors at marked occurrences using the third-party [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim), for Neovim versions without native multicursor support
- **[Surround](https://github.com/lettertwo/occurrence.nvim/wiki/Integration:-Mini-surround)** - Surround marked occurrences with quotes, brackets, or tags using [mini.surround](https://github.com/echasnovski/mini.surround)
- **[Snacks.picker](https://github.com/lettertwo/occurrence.nvim/wiki/Integration:-Snacks-picker)** - Select and manipulate marked occurrences using [snacks.nvim picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md)

## Building Your Own

Integrations leverage:

- **Custom operators** - Call into other plugins from occurrence operators
- **Before hooks** - Setup phase for user prompts or state initialization
- **Async operators** - Handle async plugin APIs
- **Events** - React to occurrence lifecycle changes

See [Custom Operators](#custom-operators) and [Events](#events) for the building blocks, or check the wiki for complete examples.

Have an integration to share? Please contribute to the [wiki](https://github.com/lettertwo/occurrence.nvim/wiki)!

<!-- panvimdoc-ignore-start -->

# Development

See [CONTRIBUTING](./CONTRIBUTING.md) for contribution guidelines.

# License

[MIT](./LICENSE)

[vim-mode-plus]: https://github.com/t9md/atom-vim-mode-plus?tab=readme-ov-file#some-features

<!-- panvimdoc-ignore-end -->

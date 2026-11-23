# Neovim Keybindings

A minimalist Neovim 0.12 configuration built on the native `vim.pack` package manager and native LSP. It follows the conventions used across these dotfiles: the **gruvbox** theme and Vim-style `h/j/k/l` movement. The keyboard layer is **`<leader>` + `Ctrl`**, with `Space` as the leader key.

In the wider dotfiles ecosystem Neovim owns the **editor** layer (splits, buffers, files); OS windows/spaces are Amethyst, session-persistent panes are Herdr. The bindings below are the editor layer on top.

## Leader & namespaces

`Space` is both `mapleader` and `maplocalleader`. Custom maps are grouped into reserved `<leader>` namespaces (first letter = domain) so related actions stay together. Press `<leader>` and wait to see the live **which-key** popup listing every group.

| Namespace    | Domain      | Purpose                                  |
| ------------ | ----------- | ---------------------------------------- |
| `<leader>f*` | Find        | Telescope pickers (files, grep, …)       |
| `<leader>b*` | Buffer      | Buffer switch / delete                   |
| `<leader>h*` | Harpoon     | Pinned-file navigation                   |
| `<leader>c*` | Code        | LSP format / action / rename / workspace |
| `<leader>x*` | Diagnostics | Diagnostic float / quickfix / loclist    |
| `<leader>s*` | Spell       | Spell-language switching                 |
| `<leader>m*` | Move        | Move lines                               |

Modifier roles are kept semantic and never mixed: **`Ctrl`+`h/j/k/l`** = window focus, **`Ctrl`+`d/u`** = scroll, **`<leader>`+group** = commands, **`g`** = go-to/LSP builtins, **`[`/`]`** = prev/next pairs.

> **Why the Ctrl layer is motion-only:** in a terminal `Ctrl+h` can be confused with backspace (ASCII `0x08`); modern terminals (Ghostty here) send it distinctly, so `Ctrl+h/j/k/l` is used for window focus. All *command* actions live under `<leader>` groups, keeping the two roles separate.
>
> **`s*` vs `<leader>s*`:** bare `s` (no leader) is mini.surround; `<leader>s` (with leader) is Spell. They never collide.

## Learn these first

| Action                     | Key               |
| -------------------------- | ----------------- |
| Find files                 | `<leader>ff`      |
| Live grep (search text)    | `<leader>fg`      |
| File explorer (oil)        | `-` / `<leader>e` |
| Pin current file (Harpoon) | `<leader>ha`      |
| Move between windows       | `<C-h/j/k/l>`     |

## General editing & movement

| Key                         | Mode | Action                                               |
| --------------------------- | ---- | ---------------------------------------------------- |
| `<Esc>`                     | n    | Clear search highlights                              |
| `J` / `K`                   | v    | Move selection down / up                             |
| `<leader>mj` / `<leader>mk` | n    | Move line down / up                                  |
| `<C-d>` / `<C-u>`           | n    | Half-page down / up (centered)                       |
| `n` / `N`                   | n    | Next / previous search result (centered)             |
| `<leader>p`                 | x    | Paste over selection without yanking                 |
| `gx`                        | n, x | Open URL/file under cursor (built-in, `vim.ui.open`) |
| `<Esc><Esc>`                | t    | Exit terminal mode                                   |

## Windows & buffers

| Key                                   | Mode | Action                                |
| ------------------------------------- | ---- | ------------------------------------- |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | n    | Focus window left / down / up / right |
| `<leader>bp`                          | n    | Previous buffer                       |
| `<leader>bn`                          | n    | Next buffer                           |
| `<leader>bf`                          | n    | First buffer                          |
| `<leader>bl`                          | n    | Last buffer                           |
| `<leader>bd`                          | n    | Delete buffer                         |
| `gt` / `gT`                           | n    | Cycle next / previous buffer          |

> `gt` / `gT` are remapped from their Vim default (tab-page cycle) to **buffer** cycle. Tab pages remain reachable via `:tabnext` / `:tabprev`. Screen-top / screen-bottom `H` / `L` are left at their Vim defaults.

## Find (Telescope)

| Key          | Action              |
| ------------ | ------------------- |
| `<leader>ff` | Find files          |
| `<leader>fg` | Live grep           |
| `<leader>fb` | Buffers             |
| `<leader>fh` | Help tags           |
| `<leader>fd` | Diagnostics         |
| `<leader>fr` | Resume last picker  |
| `<leader>fo` | Recent (old) files  |
| `<leader>fw` | Current word        |
| `<leader>fk` | Keymaps             |
| `<leader>fn` | Neovim config files |

## File navigation

| Key                         | Action                      |
| --------------------------- | --------------------------- |
| `-`                         | Open parent directory (oil) |
| `<leader>e`                 | Open file explorer (oil)    |
| `<leader>ha`                | Harpoon: add file           |
| `<leader>he`                | Harpoon: toggle quick menu  |
| `<leader>h1`..`h4`          | Harpoon: select file 1–4    |
| `<leader>hp` / `<leader>hn` | Harpoon: previous / next    |
| `<leader>u`                 | Toggle undotree             |

> Bare `nvim` starts with an empty buffer and no intro message. Open oil manually with `-` or `<leader>e`; `nvim .` / `nvim <dir>` open oil's native explorer, and file arguments open normally. Hidden files are shown (`show_hidden = true`); toggle with `g.` inside oil.

## Code (LSP)

### Custom (this config, buffer-local on attach)

| Key           | Action                                  |
| ------------- | --------------------------------------- |
| `<leader>cf`  | Format buffer (LSP)                     |
| `<leader>ca`  | Code action (alias → `gra`)             |
| `<leader>cr`  | Rename symbol (alias → `grn`)           |
| `<leader>cx`  | Execute file (Swift only, buffer-local) |
| `<leader>cwa` | Add workspace folder                    |
| `<leader>cwr` | Remove workspace folder                 |
| `<leader>cwl` | List workspace folders                  |

> **Formatting is LSP-only by design.** `<leader>cf` calls `vim.lsp.buf.format`; there is no dedicated formatter plugin (conform.nvim / none-ls). Servers that provide formatting handle it; trailing whitespace is stripped on save globally.

### Neovim built-in defaults (0.11+)

The config also relies on Neovim's built-in LSP defaults; the `<leader>c*` aliases above sit alongside them for discoverability:

| Key         | Mode | Action                     |
| ----------- | ---- | -------------------------- |
| `grn`       | n    | Rename symbol              |
| `gra`       | n, x | Code action                |
| `grr`       | n    | References                 |
| `gri`       | n    | Implementation             |
| `grt`       | n    | Type definition            |
| `gO`        | n    | Document symbols           |
| `gd` / `gD` | n    | Definition / declaration   |
| `K`         | n    | Hover documentation        |
| `[d` / `]d` | n    | Previous / next diagnostic |
| `<C-w>d`    | n    | Show diagnostic float      |

## Diagnostics

| Key          | Action                            |
| ------------ | --------------------------------- |
| `<leader>xd` | Open diagnostic float             |
| `<leader>xq` | Send diagnostics to quickfix list |
| `<leader>xl` | Send diagnostics to location list |

## Completion (blink.cmp — `default` preset)

Upstream default-preset chords (active in insert mode while the menu is open):

| Key                 | Action                             |
| ------------------- | ---------------------------------- |
| `<C-space>`         | Show menu / toggle documentation   |
| `<C-e>`             | Hide menu                          |
| `<C-y>`             | Accept selected item               |
| `<C-n>` / `<C-p>`   | Select next / previous             |
| `<C-b>` / `<C-f>`   | Scroll documentation up / down     |
| `<Tab>` / `<S-Tab>` | Snippet jump / select forward-back |
| `<C-k>`             | Toggle signature help              |

## Editing operators (mini.ai / mini.surround)

Plugin defaults (not custom-set). mini.surround operates on the `s` prefix:

| Key         | Mode | Action                                    |
| ----------- | ---- | ----------------------------------------- |
| `sa`        | n, v | Surround add (e.g. `saiw)` word → parens) |
| `sd`        | n    | Surround delete (e.g. `sd"`)              |
| `sr`        | n    | Surround replace (e.g. `sr)'`)            |
| `sf` / `sF` | n    | Find surrounding right / left             |
| `sh`        | n    | Highlight surrounding                     |
| `a` / `i`   | o, x | mini.ai textobjects (around / inside)     |

mini.ai extends textobjects with `n` / `l` for next / last (e.g. `van(`, `ci"`, `yinq`).

## Spell & language

| Key          | Native spelling | Document spelling & grammar (LTeX+) |
| ------------ | --------------- | ----------------------------------- |
| `<leader>sc` | `ca`            | Catalan (`ca-ES`)                   |
| `<leader>sd` | `de_de`         | German (`de-DE`)                    |
| `<leader>se` | `en_us`         | English (`en-US`)                   |
| `<leader>ss` | `es_es`         | Spanish (Spain) (`es-ES`)           |

Spanish selects Spain explicitly in both checkers (`es_es` / `es-ES`).
Catalan's native dictionary has no regions, so it uses `ca`; LTeX+ uses `ca-ES`.
Run `sh neovim/setup.sh` from the repository root to install the Spanish native
dictionary (discovered from `spell/es.utf-8.add`). Generated `.spl` files stay
untracked. **LTeX+ 18.7.x or newer is required for `es-ES`**; update the
`ltex-ls-plus` server through Mason if necessary.

LTeX+ 18.7.0 internally uses `es` for Spanish dictionary/code-action keys.
The integration bridges that protocol key to `es-ES` persistence files and sends
both settings keys, while document declarations remain explicitly `es-ES`.

In Markdown, TeX (`tex` / `plaintex`), and reStructuredText, these mappings persist
the initial language in the document and synchronize native `spelllang`. **Save
normally to persist the edit and refresh LTeX+ diagnostics** (`checkFrequency =
"save"`). Selection also works before LTeX+ attaches or when plugins are unavailable.
Edits preserve the current view and form one undo step; repeated selection adds
no duplicate declaration.

| Filetype          | Declaration (German example)    |
| ----------------- | ------------------------------- |
| `markdown`        | `<!-- LTeX: language=de-DE -->` |
| `tex`, `plaintex` | `% LTeX: language=de-DE`        |
| `rst`             | `.. LTeX: language=de-DE`       |

- Only declarations in the **opening metadata/comment area, before document
  content**, are updated. Existing comment style, other LTeX+ settings, and TeX
  encoding/editor headers are preserved. Markdown's alternative
  `[comment]: <> "LTeX: language=de-DE"` style is supported.
- Markdown YAML front matter with a simple top-level `lang` field uses that
  field, preserving quotes and trailing comments. Without `lang`, a magic comment
  is inserted after the front matter. If both YAML and opening comments declare
  languages, all opening language values are updated consistently. Complex,
  multiline, duplicate or ambiguous YAML declarations are reported for manual
  correction rather than rewritten.
- Opening declarations initialize native spelling on load/reload and
  resynchronize it after saving manual declaration edits. The last opening
  declaration wins. Only `ca-ES`, `de-DE`, `en-US`, and `es-ES` map to native
  dictionaries; other values leave the configured native language unchanged. Switching windows does
  not reset a manual native-language choice.
- Later section-level magic comments are preserved. LTeX+ can check multilingual
  sections independently, and supported LaTeX language commands (e.g.
  `\usepackage[ngerman]{babel}`, `\selectlanguage`, `\foreignlanguage`, and
  `otherlanguage` environments) can override the initial language. **Native
  spelling remains buffer-wide**, using the initial document language.
- Other filetypes switch **native spelling only**, with a notification.
  Read-only, unmodifiable, special, or ambiguous supported buffers report why
  synchronization was skipped.

Declaration/undo/event checks: `nvim --headless -u NONE -i NONE -n -l tests/test_neovim_spell.lua`
(run from the repository root).

Live LTeX+ checks use `tests/test_neovim_spell_ltex.lua`; its header documents the
server, nvim-lspconfig, and `ltex_extra` paths to supply. The test uses a disposable
project for Catalan, German, English, and Spain-Spanish diagnostics, including
accented text, dictionary persistence, and false-positive actions.

- **Swift**: run the current file with `<leader>cx` (output in a split). This is an explicit keymap — intended for standalone runnable scripts, not SwiftPM package sources.
- **LaTeX** (vimtex): PDF viewer is Skim (`vimtex_view_method = "skim"`).
- **Markdown**: table editing via vim-table-mode.

## Theme / visual indicators

- **Theme:** `gruvbox` (hard contrast), matching the rest of these dotfiles.
- **Statusline:** `mini.statusline` with `LINE:COLUMN` location.
- **Indent guides:** `indent-blankline` (`▏`), scope highlighting off.
- **Diagnostics:** custom sign icons (error/warn/info/hint) with severity-based line highlighting.
- **Comments:** `todo-comments` highlights `TODO` / `NOTE` / `WARN` markers.
- **Icons:** `mini.icons` (mocks `nvim-web-devicons`).
- **Keybinding discovery:** `which-key` shows a live popup of the `<leader>` namespace groups (`f`/`b`/`h`/`c`/`x`/`s`/`m`) after a short delay.

## Configuration files

- `neovim/init.lua` → `~/.config/nvim/init.lua`; `neovim/lua`, `neovim/after` and `neovim/spell` are symlinked into `~/.config/nvim/` by `neovim/setup.sh`.
- Layout: `init.lua` (leaders, plugin module load order); `lua/config/` (`options`, `keymaps`, `autocmds`, plugin-agnostic `pack` helpers, `minimal`); `lua/plugins/` (one file per domain, with `lang/` for per-language setup, plus shared `specs` and build `hooks`); `after/lsp/` (overrides merged over nvim-lspconfig's server definitions).
- This `keybindings.md` is repo documentation only; it is **not** symlinked.

## Plugins (`vim.pack`)

- Plugins follow their latest semver release where one is maintained. The exceptions (default branch or a named branch) carry a comment next to their spec explaining why.
- Each plugin module lists its own hard dependencies. A plugin that fails to install or load is reported as a warning and the rest of the config still loads; without gruvbox the built-in `retrobox` theme is used.
- Loaded after startup (`vim.schedule`): which-key, todo-comments, undotree, vim-table-mode, and Mason's registry refresh / missing server installation.
- Update with `:PackUpdate` (all plugins) or `:PackUpdate vimtex oil.nvim` (selected plugins, names tab-complete). Review the changes, then `:w` to apply or `:q` to cancel, and `:restart` to load the updated code. Each plugin keeps its configured branch, tag or version range.
- Inspect with `:lua vim.pack.update(nil, { offline = true })`; diagnose with `:checkhealth vim.pack`. Build hooks (telescope-fzf-native `make`, nvim-treesitter `:TSUpdate`) live in `lua/plugins/hooks.lua`; specs shared by several modules (plenary, mini.nvim) in `lua/plugins/specs.lua`.

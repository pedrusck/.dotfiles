# Herdr Configuration

Herdr is an **agent-aware terminal workspace manager** (a multiplexer like
tmux): a background server owns real terminal processes, clients attach to
render them, and panes survive detach / closing the terminal. Herdr **detects
coding agents** (claude, opencode, pi, …) inside panes and shows each one's
state (`working`, `blocked`, `done`, `idle`) in a per-workspace sidebar.

The configuration here follows the conventions used across these dotfiles:
gruvbox theme and Vim-style `h/j/k/l` movement, plus detach/reattach
persistence. Herdr is **prefix-first** (a tmux-style `ctrl+b` prefix). This
config is a **deliberate custom remap** of `[keys]` — it does not use Herdr's
stock keymap — so the bindings below reflect `herdr/config.toml`, not the
upstream defaults.

> Herdr is **mouse-first**: panes, tabs, workspaces, split borders and
> right-click menus are all clickable. None of the keybindings below are
> required — they are the keyboard layer on top.

## The prefix: `ctrl+b`

A multiplexer sits between your terminal and the programs inside it, which
already claim most key chords. The **prefix** solves the conflict: press
`ctrl+b`, release, then press one action key. `prefix+n` means `ctrl+b` then
`n`. One reserved chord instead of dozens.

Most actions also have a **prefix-free `ctrl+alt` chord** (see the right-hand
column below); `ctrl+alt` is the one modifier family terminals and desktops
leave almost untouched.

Press **`prefix+?`** at any time to see every active binding live.

## Why `Ctrl+B` is safe

No other layer in this setup claims `Ctrl+B`, so the prefix always reaches Herdr:

| Layer         | `Ctrl+B`?                                                   |
|---------------|-------------------------------------------------------------|
| macOS (Tahoe) | free — Cmd family owns global shortcuts, not Ctrl           |
| Amethyst      | free — uses `Opt+Cmd`; `b` is only `Opt+Cmd+B` (bsp layout) |
| Ghostty       | free — passes `Ctrl`-letter chords through to the pane      |

Inside a pane, Herdr does shadow a few low-value defaults, each easily replaced:

- **zsh** — `backward-char` (cursor left) → use Left Arrow or `Esc h`
- **Neovim** — page-up (unused; this config scrolls with `<C-d>`/`<C-u>`) and
  blink.cmp doc-scroll-up (minor; docs `auto_show = false`)
- **lazygit** — nothing (binds no `<c-b>`)

## Learn these five first

| Action                           | Key                     |
|----------------------------------|-------------------------|
| New tab                          | `prefix+n`              |
| Split right / down               | `prefix+v` / `prefix+s` |
| Move between panes               | `prefix+h/j/k/l`        |
| Workspace picker                 | `prefix+shift+w`        |
| Detach, leave everything running | `prefix+q`              |

## Full mapping (Vim philosophy)

Every pane action follows the Vim model used across this setup. Where a
prefix-free direct chord is also bound, it is shown in the last column.

### Panes

| Key                          | Direct chord             | Action                                                                 | Vim parallel      |
|------------------------------|--------------------------|------------------------------------------------------------------------|-------------------|
| `prefix+s`                   | `ctrl+alt+s`             | Split down                                                             | `:split`          |
| `prefix+v`                   | `ctrl+alt+v`             | Split right                                                            | `:vsplit`         |
| `prefix+h` / `j` / `k` / `l` | `ctrl+alt+h/j/k/l`       | Focus pane left / down / up / right                                    | `Ctrl+w h/j/k/l`  |
| `prefix+H` / `J` / `K` / `L` | `ctrl+alt+shift+h/j/k/l` | Swap pane left / down / up / right                                     | `Ctrl+w H/J/K/L`  |
| `prefix+z`                   | `ctrl+alt+z`             | Zoom (fullscreen) the focused pane                                     | —                 |
| `prefix+w`                   | `ctrl+alt+w`             | Resize mode                                                            | `Ctrl+w` + resize |
| `prefix+d`                   | `ctrl+alt+d`             | Close focused pane                                                     | `:close`          |
| `prefix+e`                   | `ctrl+alt+e`             | Open pane scrollback in `$EDITOR` (nvim)                               | —                 |
| `prefix+[`                   | —                        | Copy mode (`h/j/k/l`, `v`/space select, `y`/enter copy, `q`/esc leave) | Visual / yank     |

### Tabs

| Key                           | Direct chord                      | Action              | Vim parallel |
|-------------------------------|-----------------------------------|---------------------|--------------|
| `prefix+n`                    | —                                 | New tab             | `:tabnew`    |
| `prefix+t` / `prefix+shift+t` | `ctrl+alt+t` / `ctrl+alt+shift+t` | Next / previous tab | `gt` / `gT`  |
| `prefix+1..9`                 | `ctrl+alt+1..9`                   | Jump to tab 1–9     | `{n}gt`      |
| `prefix+r`                    | —                                 | Rename tab          | —            |
| `prefix+x`                    | —                                 | Close tab           | `:tabclose`  |

### Workspaces & session

| Key              | Action                            |
|------------------|-----------------------------------|
| `prefix+shift+w` | Workspace picker                  |
| `prefix+shift+n` | New workspace                     |
| `prefix+shift+r` | Rename workspace                  |
| `prefix+shift+x` | Close workspace                   |
| `prefix+g`       | Goto picker                       |
| `prefix+b`       | Toggle sidebar                    |
| `prefix+shift+s` | Settings                          |
| `prefix+q`       | Detach (everything keeps running) |

### Agents (agent-aware navigation)

| Key                             | Direct chord                      | Action                       |
|---------------------------------|-----------------------------------|------------------------------|
| `prefix+a` / `prefix+shift+a`   | `ctrl+alt+a` / `ctrl+alt+shift+a` | Focus next / previous agent  |
| `prefix+alt+1..9`               | —                                 | Focus agent 1–9 by index     |

Herdr detects coding agents in panes and tracks their state; these jump focus
straight to a `working` / `blocked` / `done` agent across workspaces. The agent
panel is ordered by state priority (`agent_panel_sort = "priority"`).

### Worktrees (grouped workspaces)

| Key                  | Direct chord | Action                                            |
|----------------------|--------------|---------------------------------------------------|
| `prefix+shift+g`     | `ctrl+alt+g` | New worktree → opens as a grouped workspace       |
| `prefix+shift+o`     | `ctrl+alt+o` | Open an existing worktree checkout                |
| `prefix+alt+shift+g` | —            | Delete worktree checkout (confirmed; branch kept) |

Worktrees are checked out under `~/.herdr/worktrees/<repo>/<branch-slug>`
(`[worktrees] directory`) and behave like normal workspaces — navigate them with
the workspace picker (`prefix+shift+w`) and goto (`prefix+g`). Closing the parent
workspace closes the whole group but never deletes checkouts or branches.

### Custom commands / plugins

| Key              | Action                                                     |
|------------------|------------------------------------------------------------|
| `prefix+alt+l`   | Open **lazygit** in a temporary popup (matches `lg` alias) |
| `prefix+f`       | Open **file viewer** in a split (herdr-file-viewer plugin) |
| `prefix+shift+f` | Open **file viewer** in a tab (herdr-file-viewer plugin)   |

When the **navigate surface** is open, bare `h/j/k/l` move between panes
directly (no prefix), and `shift+j` / `shift+k` move the workspace selection
down / up — keeping the Vim feel for quick hops.

## Theme / visual indicators

- **Theme:** `gruvbox`, matching Alacritty and Lazygit across these dotfiles.
  `auto_switch` follows the host terminal's light/dark appearance and swaps
  between the gruvbox dark/light siblings.
- **Accent:** gruvbox green `#98971a` (`[theme.custom] accent`) — the same color
  Lazygit uses as its accent — for highlights, borders and navigation UI.
- **Sidebar:** agent state (`working` / `blocked` / `done` / `idle`) is rolled
  up per workspace; `agent_panel_sort = "priority"` orders the agent panel by
  state priority rather than by space. Worktree children appear **indented and
  packed as one Space group** under their parent workspace.
- **Agent rows** (`[ui.sidebar.agents] rows`): the state text
  (`working` / `blocked` / `done`) is shown inline next to the icon, alongside
  workspace/tab, with the agent name on a second line. The **Space rows** show
  the Git `branch` and ahead/behind `git_status` (handy for the worktree
  workflow) at Herdr's defaults.

## Architecture (who owns what)

| Layer                                     | Owner     | Mechanism                                            |
|-------------------------------------------|-----------|------------------------------------------------------|
| OS windows / spaces                       | Amethyst  | `Opt+Cmd` / `Opt+Cmd+Shift`                          |
| Non-persistent terminal splits            | Ghostty   | `Cmd`-based built-ins (`ghostty/pane_cheatsheet.md`) |
| **Session-persistent, agent-aware panes** | **Herdr** | `ctrl+b` prefix + `herdr` CLI                        |
| Editor (splits, buffers, files)           | Neovim    | `<leader>` + `Ctrl`                                  |
| European characters                       | EurKEY    | `Opt+key`                                            |

Reach for **Herdr panes** (`prefix+v`) when you want a split to persist across
detach/reboot or you are running a coding agent worth keeping alive; use quick
**Ghostty splits** (`Cmd+D`) for throwaway side-by-side views.

## Notifications & agents

- **Notifications** (`[ui.toast]`): set to `delivery = "terminal"` so Ghostty
  shows a native desktop notification when a background agent finishes or needs
  input (active-tab agents are not announced). Sound is **off** (`[ui.sound]`) —
  the sidebar plus terminal notifications are enough.
- **Agent integrations**: install once per agent for authoritative
  `working` / `blocked` / `done` state instead of screen detection:

  ```sh
  herdr integration install pi        # Pi Coding Agent
  herdr integration install claude    # Claude Code
  herdr integration install opencode  # OpenCode
  herdr integration status            # see what's installed
  ```

  `claude` and `opencode` are already installed; `pi` is added here.
- **Session restore** (`[session] resume_agents_on_restore = true`): after a
  server restart, Pi / OpenCode / Claude Code panes resume their native
  conversation sessions.

## Session control (CLI)

Shell aliases defined in `zsh/zsh_aliases` (all guarded by `herdr` being
installed):

| Alias       | Command                       | What it does                                       |
|-------------|-------------------------------|----------------------------------------------------|
| `hh`        | `herdr`                       | Launch or attach to the default persistent session |
| `ha <name>` | `herdr session attach <name>` | Attach to (or create) a named session              |
| `hl`        | `herdr session list`          | List named sessions                                |
| `hs`        | `herdr status`                | Show client + server status                        |
| `hk`        | `herdr server stop`           | Stop the running server (kills all panes)          |
| `hu`        | `herdr update`                | Update Herdr to the latest version                 |
| `hrc`       | `herdr server reload-config`  | Reload `config.toml` in the running server         |

Detaching is done from **inside** Herdr with `prefix+q` (or by closing the
terminal); there is no detach subcommand — everything keeps running in the
background until `hk` (`herdr server stop`).

### Typical workflow

```sh
cd some/project
hh                   # launch / attach the default session; a workspace is created
claude               # start a coding agent in the pane; Herdr detects its state
prefix+v             # split right -> a second pane
prefix+h / prefix+l  # focus between panes
prefix+q             # detach — all panes (and agents) keep running
# close the Ghostty window, reboot the GUI, etc.
hh                   # reattach later; every pane is as you left it
hk                   # when you actually want to stop everything
```

(For agent-state detection integrations, see **Notifications & agents** above.)

## Configuration files

- `herdr/config.toml` → `~/.config/herdr/config.toml` (symlinked by
  `herdr/setup.sh`). Holds `onboarding = false`, the `gruvbox` theme with
  `auto_switch` and the green accent, the custom prefix-first `[keys]` remap,
  and the `[[keys.command]]` blocks (lazygit popup + file-viewer plugin
  actions, bound via `type = "plugin_action"`).
- This `keybindings.md` is repo documentation only; it is **not** symlinked.
- Validate the config with `herdr config check`; print the full upstream default
  with `herdr --default-config`; apply edits to a running server with
  `herdr server reload-config` (alias `hrc`).
- **Left at Herdr defaults** (no config entry): new panes/tabs/workspaces
  inherit the source pane's cwd (`[terminal] new_cwd = "follow"`), and the
  update channel is `stable` with background version/manifest checks
  (`herdr update`, alias `hu`).

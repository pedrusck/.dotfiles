# Herdr Keybindings

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
`n`. A prefix-only keymap reserves one chord; this setup also reserves the direct
shortcuts listed below.

Most actions also have a **prefix-free `ctrl+alt` chord** (see the right-hand
column below); `ctrl+alt` is the one modifier family terminals and desktops
leave almost untouched.

Press **`prefix+?`** at any time to see every active binding live.

## Why `Ctrl+B` is safe

No other layer in this setup claims `Ctrl+B`, so the prefix always reaches Herdr:

| Layer         | `Ctrl+B`?                                                   |
| ------------- | ----------------------------------------------------------- |
| macOS (Tahoe) | free — Cmd family owns global shortcuts, not Ctrl           |
| Amethyst      | free — uses `Opt+Cmd`; `b` is only `Opt+Cmd+B` (bsp layout) |
| Ghostty       | free — passes `Ctrl`-letter chords through to the pane      |

Inside a pane, Herdr does shadow a few low-value defaults, each easily replaced:

- **zsh** — `backward-char` (cursor left) → use Left Arrow or `Esc h`
- **Neovim** — page-up (unused; this config scrolls with `<C-d>`/`<C-u>`) and
  blink.cmp doc-scroll-up (minor; docs `auto_show = false`)
- **lazygit** — nothing (binds no `<c-b>`)

To send a literal **`Ctrl+B`** to the focused pane, press **`ctrl+b ctrl+b`**
(the prefix twice). This lets the pane application handle its own Ctrl+B action.
`ctrl+b` followed by plain `b` is different: it toggles Herdr's sidebar.

## Direct `ctrl+alt` chords vs. full-screen TUIs

During normal pane input, Herdr intercepts configured prefix-free `ctrl+alt+*`
chords *before* they reach the focused pane application. Prefix and direct
bindings are active simultaneously in shell panes and full-screen TUIs (Neovim,
OpenCode, …); this configuration does not scope direct shortcuts to shells.

- **No collision with Neovim window motion** — Neovim uses *bare* `Ctrl+h/j/k/l`
  (window focus), not `ctrl+alt`, so those pass straight through to nvim.
- **But some direct chords shadow TUI actions** — e.g. `ctrl+alt+e`
  (`edit_scrollback`), `ctrl+alt+t/s/v` can mask a chord the TUI or a coding
  agent wants.

**Using the prefix form does not disable its direct alternative.** For example,
choosing `prefix+e` to open scrollback still leaves `ctrl+alt+e` intercepted by
Herdr while both are configured.

To give a conflicting chord back to a pane application, remove or remap the
Herdr direct binding, or choose a different shortcut in the application. For
example, to free `ctrl+alt+e` while keeping `prefix+e`, replace the existing
`edit_scrollback` entry under `[keys]` in `herdr/config.toml` with:

```toml
edit_scrollback = "prefix+e"
```

Validate with `herdr config check`, then reload with `prefix+shift+e`. Binding
arrays replace an action's shortcut list, so keep every shortcut you still want
when editing one. The mappings below describe the current config, including its
direct alternatives.

## Learn these five first

| Action                           | Key                     |
| -------------------------------- | ----------------------- |
| New tab                          | `prefix+n`              |
| Split right / down               | `prefix+v` / `prefix+s` |
| Move between panes               | `prefix+h/j/k/l`        |
| Workspace picker                 | `prefix+shift+w`        |
| Detach, leave everything running | `prefix+q`              |

## Full mapping (Vim philosophy)

Every pane action follows the Vim model used across this setup. Where a
prefix-free direct chord is also bound, it is shown in the last column.

### Panes

| Key                          | Direct chord             | Action                                   | Vim parallel      |
| ---------------------------- | ------------------------ | ---------------------------------------- | ----------------- |
| `prefix+s`                   | `ctrl+alt+s`             | Split down                               | `:split`          |
| `prefix+v`                   | `ctrl+alt+v`             | Split right                              | `:vsplit`         |
| `prefix+h` / `j` / `k` / `l` | `ctrl+alt+h/j/k/l`       | Focus pane left / down / up / right      | `Ctrl+w h/j/k/l`  |
| `prefix+H` / `J` / `K` / `L` | `ctrl+alt+shift+h/j/k/l` | Swap pane left / down / up / right       | `Ctrl+w H/J/K/L`  |
| `prefix+z`                   | `ctrl+alt+z`             | Zoom (fullscreen) the focused pane       | —                 |
| `prefix+w`                   | `ctrl+alt+w`             | Resize mode                              | `Ctrl+w` + resize |
| `prefix+d`                   | `ctrl+alt+d`             | Close focused pane                       | `:close`          |
| `prefix+e`                   | `ctrl+alt+e`             | Open pane scrollback in `$EDITOR` (nvim) | —                 |

### Tabs

| Key                           | Direct chord                      | Action              | Vim parallel |
| ----------------------------- | --------------------------------- | ------------------- | ------------ |
| `prefix+n`                    | —                                 | New tab             | `:tabnew`    |
| `prefix+t` / `prefix+shift+t` | `ctrl+alt+t` / `ctrl+alt+shift+t` | Next / previous tab | `gt` / `gT`  |
| `prefix+1..9`                 | `ctrl+alt+1..9`                   | Jump to tab 1–9     | `{n}gt`      |
| `prefix+r`                    | —                                 | Rename tab          | —            |
| `prefix+x`                    | —                                 | Close tab           | `:tabclose`  |

### Workspaces & session

| Key              | Action                            |
| ---------------- | --------------------------------- |
| `prefix+shift+w` | Workspace picker                  |
| `prefix+shift+n` | New workspace                     |
| `prefix+shift+r` | Rename workspace                  |
| `prefix+shift+x` | Close workspace                   |
| `prefix+g`       | Goto picker                       |
| `prefix+b`       | Toggle sidebar                    |
| `prefix+shift+s` | Settings                          |
| `prefix+shift+e` | Reload config                     |
| `prefix+q`       | Detach (everything keeps running) |

`rename_workspace` takes `prefix+shift+r`, which is Herdr's default for
`reload_config`; the latter is remapped to `prefix+shift+e` so both stay
reachable.

### Left at Herdr's defaults

The prefix (`ctrl+b`), detach (`prefix+q`), new workspace (`prefix+shift+n`),
goto (`prefix+g`), toggle sidebar (`prefix+b`), and Navigate-mode pane movement
(`h/j/k/l`) use built-in defaults without config entries. Their mappings remain
listed above and below for reference.

Other inherited bindings, listed so they aren't accidentally re-bound:

| Key                               | Action                        |
| --------------------------------- | ----------------------------- |
| `prefix+?`                        | Keybinding help               |
| `prefix+[`                        | Copy mode                     |
| `prefix+shift+p`                  | Rename pane                   |
| `prefix+tab` / `prefix+shift+tab` | Cycle to next / previous pane |
| `prefix+o`                        | Focus notification target     |

### Agents (agent-aware navigation)

| Key                           | Direct chord                      | Action                      |
| ----------------------------- | --------------------------------- | --------------------------- |
| `prefix+a` / `prefix+shift+a` | `ctrl+alt+a` / `ctrl+alt+shift+a` | Focus next / previous agent |
| `prefix+alt+1..9`             | —                                 | Focus agent 1–9 by index    |

Herdr detects coding agents in panes and tracks their state; these jump focus
straight to a `working` / `blocked` / `done` agent across workspaces. The agent
panel is ordered by state priority (`agent_panel_sort = "priority"`).

### Worktrees (grouped workspaces)

| Key                  | Direct chord | Action                                            |
| -------------------- | ------------ | ------------------------------------------------- |
| `prefix+shift+g`     | `ctrl+alt+g` | New worktree → opens as a grouped workspace       |
| `prefix+shift+o`     | `ctrl+alt+o` | Open an existing worktree checkout                |
| `prefix+alt+shift+g` | —            | Delete worktree checkout (confirmed; branch kept) |

Worktrees use Herdr's default `~/.herdr/worktrees/<repo>/<branch-slug>` location
(no `[worktrees]` override) and behave like normal workspaces — navigate them with
the workspace picker (`prefix+shift+w`) and goto (`prefix+g`). Closing the parent
workspace closes the whole group but never deletes checkouts or branches.

### Custom commands / plugins

| Key              | Action                                                     |
| ---------------- | ---------------------------------------------------------- |
| `prefix+alt+l`   | Open **lazygit** in a temporary popup (matches `lg` alias) |
| `prefix+f`       | Open **file viewer** in a split (herdr-file-viewer plugin) |
| `prefix+shift+f` | Open **file viewer** in a tab (herdr-file-viewer plugin)   |

When the **navigate surface** is open, bare `h/j/k/l` move between panes
directly (no prefix), and `shift+j` / `shift+k` move the workspace selection
down / up — keeping the Vim feel for quick hops.

#### File-viewer setup

`herdr/setup.sh` installs [herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer)
from the upstream repository's default-branch HEAD, without a `--ref` pin. The
development bootstrap runs this after installing Herdr from the Brewfile. To
install or reapply it manually, run from the repository root:

```sh
sh herdr/setup.sh
```

Plugin installation requires Herdr and Git on `PATH` and network access. Setup
installs noninteractively with `--yes`; reruns replace the managed plugin checkout
with the latest upstream HEAD while retaining the plugin's separate config and
state. If Herdr is missing, setup installs the config symlink but silently skips
the plugin. A failed plugin installation makes setup fail. Herdr refuses to
overwrite a locally linked development checkout.

The plugin installer downloads a matching prebuilt binary and verifies its SHA-256.
If that download is unavailable or cannot be verified, its fallback builds from
source and requires Rust 1.96+ with Cargo. The optional renderers `glow`,
`git-delta` (the `delta` command), and `bat` are already included in the Brewfile.

After launching or attaching to Herdr, verify registration:

```sh
herdr plugin list
herdr plugin action list --plugin herdr-file-viewer
```

The plugin should be enabled, with actions
`herdr-file-viewer.open-file-viewer` and
`herdr-file-viewer.open-file-viewer-tab`. Reload config with `prefix+shift+e` and
check `prefix+f` (split) and `prefix+shift+f` (tab).

To update the plugin, rerun setup and verify both actions and shortcuts again.
The plugin is installed per user on the machine running setup; remote servers
need their own installation.

## Theme / visual indicators

- **Theme:** `gruvbox` (dark), matching Alacritty and Lazygit across these
  dotfiles. Auto-switching defaults to `false`, so the theme stays dark and does
  **not** follow the host terminal's light/dark appearance. If enabled later,
  Herdr infers the `gruvbox` / `gruvbox-light` siblings from the theme name;
  explicit `dark_name` and `light_name` entries are unnecessary.
- **Accent:** gruvbox green `#98971a` (`[theme.custom] accent`) — the same color
  Lazygit uses.
- **Sidebar:** agent state (`working` / `blocked` / `done` / `idle`) is rolled
  up per workspace; `agent_panel_sort = "priority"` orders the agent panel by
  state priority rather than by space. Worktree children appear **indented and
  packed as one Space group** under their parent workspace.
- **Agent rows** (`[ui.sidebar.agents] rows`): a two-row layout of
  `state_icon` + `machine` + `workspace` + `tab`, with `agent` + `state_text` on
  the second row. This preserves location information as the priority-sorted
  agent panel reorders, while keeping the state readable beside the agent name.
  The `machine` token disappears for a single local machine; missing values and
  their separators are omitted. These rows apply to the expanded desktop sidebar.
  The **Space rows** are left at Herdr's defaults and show the Git `branch` with
  ahead/behind `git_status` (handy for the worktree workflow).

## Architecture (who owns what)

| Layer                                     | Owner     | Mechanism                                        |
| ----------------------------------------- | --------- | ------------------------------------------------ |
| OS windows / spaces                       | Amethyst  | `Opt+Cmd` / `Opt+Cmd+Shift`                      |
| Non-persistent terminal splits            | Ghostty   | `Cmd`-based built-ins (`ghostty/keybindings.md`) |
| **Session-persistent, agent-aware panes** | **Herdr** | `ctrl+b` prefix + `herdr` CLI                    |
| Editor (splits, buffers, files)           | Neovim    | `<leader>` + `Ctrl`                              |
| European characters                       | EurKEY    | `Opt+key`                                        |

Reach for **Herdr panes** (`prefix+v`) when you want pane processes to keep
running after detach or closing the terminal client. After a server restart or
reboot, Herdr restores the saved layout and can relaunch eligible agent sessions;
the original processes do not survive. Use quick **Ghostty splits** (`Cmd+D`) for
throwaway side-by-side views.

## Notifications & agents

- **Notifications** (`[ui.toast]`): set to `delivery = "terminal"` so Ghostty
  shows a native desktop notification when a background agent finishes or needs
  input (active-tab agents are not announced), using the default one-second
  delay. Sound is **off** (`[ui.sound]`) — the sidebar plus terminal notifications
  are enough.
- **Agent integrations**: Pi and OpenCode report lifecycle state and native
  session identity through their integrations. Claude Code's hook reports native
  session identity only; its lifecycle state still comes from screen detection.
  All three integrations support native conversation restoration when a valid
  session reference has been reported.

  The development bootstrap runs `claude_code/setup.sh`, `opencode/setup.sh`, and
  `pi_coding_agent/setup.sh` before `herdr/setup.sh`. Each agent setup prepares its
  config directory, then installs its bundled integration if Herdr is available.
  Installation failures propagate; missing Herdr prints a message to rerun setup.
  To apply manually, run from the repository root:

  ```sh
  sh claude_code/setup.sh
  sh opencode/setup.sh
  sh pi_coding_agent/setup.sh
  herdr integration status
  ```

  After upgrading Herdr, refresh just the integrations without reapplying agent
  settings:

  ```sh
  herdr integration install pi        # Pi Coding Agent
  herdr integration install claude    # Claude Code
  herdr integration install opencode  # OpenCode
  herdr integration status            # check installed versions and status
  ```

  Installation state is machine-specific; use the status command to verify it.
  Integrations do not install the agent executables or authenticate them.

  Claude's `settings.json` is copied from the repo template on each setup run,
  then Herdr installs the hook script and generates the machine-local registration.
  Rerunning Claude setup reapplies that template; keep shared preferences in
  `claude_code/settings.json`. With Herdr 0.9.3, the generated `SessionStart`
  matcher is `^(startup|resume|clear|compact|fork)$`, avoiding Grok's `new` / `load`
  events. No generated absolute hook path is committed. Claude and Pi setup honor
  `CLAUDE_CONFIG_DIR` and `PI_CODING_AGENT_DIR`; use absolute paths for overrides.

  Restart agents after installation. OpenCode also needs its shared servers
  restarted after an integration upgrade. If the installer defers OpenCode V2
  registration for first-start migration, start `opencode2` once and rerun
  `herdr integration install opencode`. See the
  [integration documentation](https://herdr.dev/docs/integrations/) for supported
  versions and install locations.
- **Session restore** (enabled by default; no `[session]` override): after a
  server restart, eligible Pi / OpenCode / Claude Code panes relaunch into their
  native conversation sessions using valid session references reported by current
  official integrations. Missing, invalid, duplicated, or stale references fall
  back to new shells in the saved directories.

## Session control (CLI)

Shell aliases defined in `zsh/zsh_aliases` (all guarded by `herdr` being
installed):

| Alias       | Command                       | What it does                                       |
| ----------- | ----------------------------- | -------------------------------------------------- |
| `hh`        | `herdr`                       | Launch or attach to the default persistent session |
| `ha <name>` | `herdr session attach <name>` | Attach to (or create) a named session              |
| `hl`        | `herdr session list`          | List named sessions                                |
| `hs`        | `herdr status`                | Show client + server status                        |
| `hk`        | `herdr server stop`           | Stop the running server (kills all panes)          |

Updates have no shell alias — run the commands directly: `herdr update` (or
`herdr channel set <stable|preview>`). Config reloads also have no alias, but
can be triggered from inside Herdr with `prefix+shift+e` instead of
`herdr server reload-config`. Validate the file first with `herdr config check`.

Detaching is done from **inside** Herdr with `prefix+q` (or by closing the
terminal client); there is no detach subcommand. Pane processes keep running in
the background while the server lives, unless they exit on their own. `hk`
(`herdr server stop`) stops the server and its pane processes.

### What survives

| Event                                                                | Behavior with this configuration                                                                                                            |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Detach / close the terminal client, then reattach to the live server | Pane processes keep running; the live layout and terminal buffers remain available.                                                         |
| Full server restart or host reboot                                   | Saved workspaces, tabs, panes, directories, layout, and focus are restored. Original processes are gone; ordinary panes start new shells.   |
| Eligible agent restoration after a restart                           | Herdr relaunches supported agents into their saved native conversations; this does not preserve their original processes or in-flight work. |

Pane screen history is **off** (`experimental.pane_history` is unset and defaults
to `false`), so ordinary pane screen contents and scrollback are not replayed
after a full server restart. The live per-pane buffer used by `edit_scrollback`
survives detach, but is not configured for disk-backed restoration. Editors,
development servers, tests, and other arbitrary processes must be restarted.

See [Herdr's session state and restore guide](https://herdr.dev/docs/session-state/)
for the distinction between live persistence, snapshot restore, and native agent
session restore.

### Typical workflow

```sh
cd some/project
hh                   # launch / attach the default session; a workspace is created
claude               # start a coding agent in the pane; Herdr detects its state
prefix+v             # split right -> a second pane
prefix+h / prefix+l  # focus between panes
prefix+q             # detach — all panes (and agents) keep running
# Close Ghostty; leave the Herdr server and host running.
hh                   # reattach to the live session; work may have progressed
hk                   # stop the server and its pane processes
```

(For agent-state detection integrations, see **Notifications & agents** above.)

## Configuration files

- `herdr/config.toml` → `~/.config/herdr/config.toml` (symlinked by
  `herdr/setup.sh`). Holds `onboarding = false`, the `gruvbox` theme and green
  accent, the custom prefix-first `[keys]` remap, and the `[[keys.command]]`
  blocks (lazygit popup + file-viewer plugin actions, bound via
  `type = "plugin_action"`).
- This `keybindings.md` is repo documentation only; it is **not** symlinked.
- Validate the config with `herdr config check`; print the full upstream default
  with `herdr --default-config`; apply edits to a running server with
  `herdr server reload-config` or `prefix+shift+e`.
- Defaults were checked against **Herdr 0.9.3**. After a Herdr upgrade, compare
  `herdr --default-config` to catch newly added keys or changed defaults. Redundant
  overrides are omitted, so inherited settings follow upstream defaults.
- **Left at Herdr defaults** (no config entry):
  - theme auto-switching is off; eligible agent sessions resume after a restart;
  - worktrees use `~/.herdr/worktrees`, and agent notifications wait one second;
  - the prefix and unchanged keybindings listed under **Left at Herdr's defaults**
    above are inherited; arrays retain both prefix and direct shortcuts because
    they replace an action's entire binding list;
  - new panes/tabs/workspaces inherit the source pane's cwd
    (`[terminal] new_cwd = "follow"`), and new-pane shells start in
    `shell_mode = "auto"` (login shells on macOS, already the default);
  - the update channel is `stable` with background version/manifest checks
    (`herdr update`, switch with `herdr channel set <stable|preview>`);
  - `[ui] accent`, the `[theme.custom]` row-highlight tokens (`active_row_bg`,
    `selection_bg`, `sidebar_bg`) and the sidebar `row_gap` are all unset, so
    the theme's own colors and Herdr's stock spacing apply;
  - `[ui] window_title` is unset, so Herdr writes its default
    `{hostname}: {workspace}` to the Ghostty tab/window label. Set it to `""` to
    leave Ghostty's own titling alone.

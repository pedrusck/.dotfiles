# Monitor Herdr from an iPhone or iPad

Use an SSH client on your iPhone or iPad to connect to this Mac, then run
`herdr` there. The existing Herdr configuration supports this without changes.
The mobile device displays the terminal while the Herdr server and agents
continue running on the Mac.

Herdr documents this workflow in
[Work from your phone](https://herdr.dev/tui/docs/how-to-work/#work-from-your-phone).

## Current setup

Verify current versions and sessions on the Mac with `herdr --version`,
`herdr status`, and `herdr session list`. The installed executable and a running
server can have different versions after an update.

The configuration in [`config.toml`](config.toml) provides:

| Capability          | Current behavior                                                                              |
| ------------------- | --------------------------------------------------------------------------------------------- |
| Persistent sessions | Panes continue running after closing Ghostty or disconnecting SSH.                            |
| Mobile layout       | Inherited default: a single-column layout at **64 terminal columns or fewer**.                |
| Agent monitoring    | Agent panel sorted by priority, with agent labels enabled on split-pane borders.              |
| Notifications       | `[ui.toast] delivery = "terminal"` requests notifications from the terminal displaying Herdr. |
| Sound               | Disabled through `[ui.sound] enabled = false`.                                                |

[`setup.sh`](setup.sh) links this configuration to `HERDR_CONFIG_PATH` when set,
otherwise `$XDG_CONFIG_HOME/herdr/config.toml`, falling back to
`~/.config/herdr/config.toml`. Run `herdr --help` to inspect the resolved location.
Setup installs the file-viewer plugin when Herdr is available; it does not
configure SSH or remote network access. Use the same configuration-path overrides
in the SSH environment as on the desktop if you have customized them.

Verify Remote Login is enabled and test SSH connectivity from the device and
network you intend to use before attaching to Herdr.

## Connect from a mobile device

### 1. Enable SSH on the Mac

Open **System Settings → General → Sharing → Remote Login**, enable Remote
Login, and allow the macOS account `pere.bohigas`.

Connect using that same account so Herdr finds the existing session and its
configuration.

### 2. Install an iOS SSH client

Examples include **Blink Shell** and **Termius**. Herdr's guide also recommends
[moshi](https://getmoshi.app/) for iPhone.

The Herdr binary runs on the Mac; it does not need to be installed on iOS.

### 3. Choose the network path

- **On the same local network:** connect to the Mac's LAN IP or its local
  hostname, `DX2LYYK2XR.local`, if local hostname resolution works.
- **Away from that network:** use a VPN connecting the devices, such as
  Tailscale installed on both, and connect to the Mac's VPN address.

### 4. Attach to the existing session

From the mobile terminal:

```sh
ssh pere.bohigas@DX2LYYK2XR.local
herdr
```

Alternatively, configure the SSH connection in the app and run `herdr` after
connecting. Substitute the Mac's LAN IP or VPN address when appropriate.

This opens the already-running **default session**, including its workspaces,
panes, and agents. If the SSH shell cannot find Herdr, check command resolution
inside that shell:

```sh
command -v herdr
```

Make the installed executable available on the SSH shell's `PATH`, or invoke its
verified absolute path. See the [repository installation guide](../README.md#for-macos)
and [Herdr's PATH troubleshooting](https://herdr.dev/tui/docs/troubleshooting/#the-herdr-command-is-not-found).

For named sessions:

```sh
herdr session list
herdr session attach <name>
```

Use the existing session's exact name. Attaching to a new name creates a separate
session rather than opening the one being monitored.

## Navigate with the current keybindings

The custom bindings apply because the Herdr client runs on the Mac and reads its
configuration. **Prefix** means press `Ctrl+B`, release, then press the action
key.

| Action                         | Binding          |
| ------------------------------ | ---------------- |
| Jump to next agent             | `prefix+a`       |
| Open workspace picker          | `prefix+Shift+W` |
| Next tab                       | `prefix+t`       |
| Zoom the focused pane          | `prefix+z`       |
| Toggle sidebar                 | `prefix+b`       |
| Detach, leaving agents running | **`prefix+q`**   |

**Use `prefix+q` to detach; `prefix+d` closes the focused pane in this
configuration.** After detaching, run `exit` to close the SSH shell if desired.

Prefix bindings are generally easier to use with an iOS terminal's on-screen
modifier keys than the configured `Ctrl+Alt` alternatives. See
[`keybindings.md`](keybindings.md) for the full mapping.

## Simultaneous desktop and mobile viewing

Ghostty can remain attached while a mobile client monitors the session. Herdr
supports multiple clients viewing different workspaces or tabs independently.

When both clients view **the same tab**, the last client to focus, select, or
interact with it controls that tab's pane sizes. A phone connection can therefore
cause terminal content to reflow. See
[Client and server](https://herdr.dev/tui/docs/concepts/#client-and-server).

Each client tracks viewed completions independently. Viewing a completed agent
on the desktop does not clear its Done badge on the phone. CLI/API statuses use
the server's seen state, so they can differ from either UI. Both `idle` and `done`
mean ready for input; `unknown` means Herdr cannot confidently classify the state.

### Inspect without an interactive UI

For occasional checks, run these commands in the SSH shell:

```sh
herdr agent list
herdr agent read <pane-id> --source recent-unwrapped --lines 80
```

Replace `<pane-id>` with an ID returned by the list command. These commands
inspect agent state and output without taking terminal input or resize
ownership.

To inspect a named session, use the same session selector for both commands:

```sh
herdr --session <name> agent list
herdr --session <name> agent read <pane-id> --source recent-unwrapped --lines 80
```

## Notifications

The current terminal notifications **are not iOS push notifications**. Over SSH,
their display depends on the mobile terminal's support. They do not establish a
reliable alert channel while the app is suspended or the device is locked.
Background push alerts would require a separate notification integration.

## Keep the session available

Leave the **Mac awake and network-connected**, with the Herdr server running.

- Closing Ghostty or disconnecting SSH leaves pane processes running.
- Mac sleep pauses work and can interrupt the connection.
- A server stop or reboot ends the original processes. Herdr can restore layout
  and eligible agent conversations, but not the original in-flight processes.

Recommended connection path:

```text
iPhone/iPad SSH client
  → local network or VPN (for example, Tailscale)
  → Mac, logged in as pere.bohigas
  → herdr
  → existing persistent session
```

## References

- [Herdr: Work from your phone](https://herdr.dev/tui/docs/how-to-work/#work-from-your-phone)
- [Herdr: Persistence and remote access](https://herdr.dev/tui/docs/persistence-remote/)
- [Herdr: Client and server](https://herdr.dev/tui/docs/concepts/#client-and-server)
- [Herdr: Session state and restore](https://herdr.dev/tui/docs/session-state/)
- [Local configuration](config.toml)
- [Local keybindings guide](keybindings.md)

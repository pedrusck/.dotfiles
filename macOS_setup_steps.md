# macOS setup steps

- [ ] Disable startup chime
> in German go to Systemeinstellungen > Ton > Toneffekte > Beim Starten Ton abspielen
>
> in English go to System Settings > Sound > Sound Effects > Play sound on startup

- [ ] Disable sound effects
> in German go to Systemeinstellungen > Ton > Toneffekte > Toneffekte der Benutzeroberfläche verwenden
>
> in English go to System Settings > Sound > Sound Effects > Play user interface sound effects

- [ ] Map cap locks key to escape
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Sondertasten > Feststelltaste: esc-Taste
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys > Cap-Locks key: Escape

- [ ] Set key repetition
> in German go to Systemeinstellungen > Tastatur > [Tastenwiederholrate > Schnell, Ansprechverzögerung > Kurz]
>
> in English go to System Settings > Keyboard > [Key repeat rate > Fast, Delay until repeat > Short]

- [ ] Activate Firewall (required)
> Required: the OpenCode server listens on the network and advertises itself via
> mDNS (`opencode.local`), so the firewall is the primary access control for it.
>
> in German go to Systemeinstellungen > Netzwerk > Firewall > Firewall aktivieren
>
> in English go to System Settings > Network > Firewall > Turn On Firewall

- [ ] Set links to projects directories in Finder
> Add the project roots to the Finder sidebar Favorites so they are one click away.
>
> in Finder, open each project root (e.g. `~/Developer/personal_projects` and `~/Developer/adesso_projects`), then drag its folder into the sidebar under Favorites, or select it and press `Ctrl+Cmd+T` (File > Add to Sidebar).

- [ ] Show file path in finder
> in German in Finder App go to Darstellung > Pfadleiste ausblenden
>
> in English in Finder App go to View > Show path bar

- [ ] Upload ssh keys for repositories hosting platforms
> This setup uses [Secretive](https://github.com/maxgoedjen/secretive) so private keys live in the Secure Enclave and never touch disk (see `ssh/configuration`). The `~/.ssh/*.pub` files are symlinks into Secretive's container.
>
> 1. Install and open Secretive (`brew install --cask secretive`), then grant it the requested permissions.
> 2. Create one key per hosting platform (GitHub, GitLab, Codeberg, ...); require Touch ID for use if desired.
> 3. Copy each public key from Secretive (or from `~/.ssh/<name>.pub`) and add it to the corresponding platform's SSH keys settings.
> 4. Verify with `ssh -T git@github.com` (and the equivalent for each host).

- [ ] Activate night shift
> in German go to Systemeinstellungen > Displays > Night Shift > Zeitplan: Sonnenuntergang bis Sonnenaufgang
>
> in English go to System Settings > Displays > Night Shift > Schedule: Sunset to Sunrise

- [ ] Battery percentage
> in German go to Systemeinstellungen > Kontrollzentrum > Batterie > Prozent anzeigen
>
> in English go to System Settings > Control Center > Battery > Show Percentage

- [ ] Reduce menu transparency??
> in German go to Systemeinstellungen > Bedienungshilfen > Anzeige > Transparenz reduzieren
>
> in English go to System Settings > Accessibility > Display > Reduce transparency

- [ ] Activate zoom with control key
> in German go to Systemeinstellungen > Bedienungshilfen > Zoomen > Zoomen: Scroll-Geste mit diesen Sondertasten > `ctrl-Taste`
>
> in English go to System Settings > Accessibility > Zoom > Use scroll gesture with modifier keys to zoom

- [ ] Hide dock
> in German go to Systemeinstellungen > Schreibtisch & Dock > Dock automatisch ein- und ausblenden
>
> in English go to System Settings > Desktop & Dock > Automatically hide and show the Dock

- [ ] Set computer name
> in German go to Systemeinstellungen > Allgemein > Info > Name
>
> in English go to System Settings > General > About > Name

- [ ] Disable active corners
> in German go to Systemeinstellungen > Schreibtisch & Dock > Aktive Ecken > deselect all actions associated to a corner
>
> in English go to System Settings > Desktop & Dock > Hot Corners... > deselect all actions associated to a corner

- [ ] Disable automatically rearrange of spaces
> in German go to Systemeinstellungen > Schreibtisch & Dock > Mission Control > "Spaces automatisch anhand der letzten Verwendung ausrichten" deaktivieren
>
> in English go to System Settings > Desktop & Dock > Mission Control > deactivate "Automatically rearrange Spaces based on most recent use"

- [ ] Enable "Switch to Desktop N" shortcuts for Amethyst workspace switching (Opt+Cmd+1..9)
> Create the desired number of desktops in Mission Control first (Ctrl+Up, then "+" in the top-right corner).
>
> These must be bound to Opt+Cmd+1..9 (Amethyst's mod1), not the macOS default Ctrl+1..9. See `amethyst/amethyst.yml` and `amethyst/keybindings.md`. Click each existing shortcut to edit it and press Opt+Cmd+<N>.
>
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Mission Control > "Zu Schreibtisch 1" bis "Zu Schreibtisch 9" aktivieren und jeweils von Ctrl+N auf Opt+Cmd+N ändern
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > Mission Control > enable "Switch to Desktop 1" through "Switch to Desktop 9" and change each from the default Ctrl+N to Opt+Cmd+N

- [ ] Override "Hide Others" shortcut (Opt+Cmd+H) to free Amethyst shrink-main
> Remap "Hide Others" to a dummy shortcut so Amethyst can use Opt+Cmd+H.
>
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > App-Kurzbefehle > Alle Programme > "Andere ausblenden" hinzufügen mit Ctrl+Opt+Cmd+Shift+H
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications > add "Hide Others" with Ctrl+Opt+Cmd+Shift+H

- [ ] Override "Minimize All" shortcut (Opt+Cmd+M) to free Amethyst focus-main
> Remap "Minimize All" to a dummy shortcut so Amethyst can use Opt+Cmd+M.
>
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > App-Kurzbefehle > Alle Programme > "Alle minimieren" hinzufügen mit Ctrl+Opt+Cmd+Shift+M
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications > add "Minimize All" with Ctrl+Opt+Cmd+Shift+M

- [ ] Override "Close All Windows" shortcut (Opt+Cmd+W) to free Amethyst focus-screen-1
> Remap "Close All" to a dummy shortcut so Amethyst can use Opt+Cmd+W. This also prevents the destructive "Close All Windows" action.
>
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > App-Kurzbefehle > Alle Programme > "Alle schließen" hinzufügen mit Ctrl+Opt+Cmd+Shift+W
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > All Applications > add "Close All" with Ctrl+Opt+Cmd+Shift+W

- [ ] Disable Dock toggle shortcut (Opt+Cmd+D) to free Amethyst select-fullscreen-layout
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Launchpad & Dock > "Dock ein-/ausblenden" deaktivieren
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > Launchpad & Dock > uncheck "Turn Dock Hiding On/Off"

- [ ] Disable Spotlight shortcut (Opt+Cmd+Space) to free Amethyst cycle-layout
> Disable "Show Finder search window" so Amethyst can use Opt+Cmd+Space.
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Spotlight > "Finder-Suchfenster einblenden" deaktivieren
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > Spotlight > uncheck "Show Finder search window"

- [ ] Disable input-source switching shortcuts (Ctrl+Space / Ctrl+Opt+Space) to free Neovim completion
> With multiple input sources enabled (EurKEY + English + German), macOS binds
> Ctrl+Space and Ctrl+Opt+Space to input-source switching, which shadows Neovim's
> `<C-space>` completion trigger (blink.cmp). Disable them and cycle input sources
> via the Globe/🌐 key or the menu-bar input menu instead.
>
> in German go to Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Eingabequellen > "Vorherige Eingabequelle auswählen" und "Nächste Quelle im Eingabemenü auswählen" deaktivieren
>
> in English go to System Settings > Keyboard > Keyboard Shortcuts > Input Sources > uncheck "Select the previous input source" and "Select next source in input menu"

- [ ] Activate Touch ID
> Add a fingerprint and enable "Use Touch ID to unlock your Mac".
>
> in German go to Systemeinstellungen > Touch ID & Passwort > Fingerabdruck hinzufügen
>
> in English go to System Settings > Touch ID & Password > Add Fingerprint
>
> Optional: to also authorise `sudo` in the terminal with Touch ID, add `auth sufficient pam_tid.so` to `/etc/pam.d/sudo_local` (copy it from `/etc/pam.d/sudo_local.template`).

- [ ] Disable text spelling autocorrection
> in German go to Systemeinstellungen > Tastatur > Texteingabe > Eingabequellen > Bearbeiten... > "Rechtschreibung automatisch korrigieren" und "Wörter automatisch groß schreiben" deaktivieren
>
> in English go to System Settings > Keyboard > Text Input > Input Sources > Edit... > disable "Correct spelling automatically" and "Capitalize words automatically"

- [ ] Disable charging sound
> on the terminal:
> sudo nvram BootAudio=%00

- [ ] Disable click wallpaper to show desktop
> in German go to Systemeinstellungen > Schreibtisch & Dock > Schreibtisch & Stage Manager > "Auf Hintergrund klicken, um den Schreibtisch anzuzeigen" > "Nur im Stage Manager" auswählen
>
> in English go to System Settings > Desktop & Dock > Desktop & Stage Manager > Click wallpaper to show desktop > Select "Only in Stage Manager"

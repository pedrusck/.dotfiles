# Browser bookmark snapshots

These macOS/Zsh helpers copy one bookmark snapshot and restore it within the
same browser family. Run any entry point with `--help` for its options.

## Extract

```sh
zsh extract_chromium_based_browser_bookmarks.zsh [OUTPUT_DIR]
zsh extract_gecko_based_browser_bookmarks.zsh [OUTPUT_DIR]
```

The output directory defaults to the current directory and must already exist.

- **Chromium:** chooses the most recently modified local `Bookmarks` file across
  Helium, Brave, and Chrome profiles. Close the source browser first to flush its
  pending writes. Account/encrypted stores are not included.
- **Gecko:** chooses an existing Firefox, Zen, or Floorp automatic backup by its
  native filename date, then modification time for same-day backups. This does
  not create a fresh export of current bookmarks. The original filename is
  printed so its backup date is visible.

Use `--browser NAME` to restrict selection, `--browser NAME --profile DIRECTORY`
for an explicit profile, or `--source FILE` for an explicit source file. Gecko
automatically searches only standard `Profiles` directories; external profiles
require `--profile`.

Snapshots retain the `*_based_browser_bookmarks_YYYYMMDD_HHMMSS.secret.*` naming
format. Exports produce one private file, without metadata sidecars. If a
same-second snapshot already exists, export fails without overwriting it; retry
in the next second. Copy verification compares bytes, not bookmark contents.

## Restore

```sh
zsh restore_chromium_based_browser_bookmarks.zsh [SOURCE_FILE_OR_DIR]
zsh restore_gecko_based_browser_bookmarks.zsh [SOURCE_FILE_OR_DIR]
```

The source defaults to the directory containing the script, regardless of the
current working directory. An explicit file selects that exact copy, even if it
is older, and may have any name. An explicit directory selects its latest matching
snapshot. Relative source paths are resolved from the current working directory.

Directory selection uses the latest raw snapshot filename timestamp, including
historical six-digit collision suffixes, rather than filesystem modification
time. Derived files such as `*_sorted.*` are excluded.

Examples from the repository root:

```sh
# Latest snapshot alongside the script
zsh browser_bookmarks/restore_chromium_based_browser_bookmarks.zsh

# A specific older copy
zsh browser_bookmarks/restore_chromium_based_browser_bookmarks.zsh \
  browser_bookmarks/chromium_based_browser_bookmarks_20260611_110828.secret.json

# Latest snapshot in another directory (manual Gecko restoration)
zsh browser_bookmarks/restore_gecko_based_browser_bookmarks.zsh \
  "/path/to/bookmark backups"
```

Extraction still writes to the current directory by default. If snapshots were
exported elsewhere, pass that directory or a specific snapshot file to restore.

- **Chromium:** replaces local bookmarks in the `Default` profile of every
  supported installed browser. Applications are found in `~/Applications` and
  `/Applications`. Use repeatable `--app BROWSER=APP_PATH` and
  `--profile BROWSER=DIRECTORY` overrides for custom locations. Existing bookmarks
  are backed up as `Bookmarks.before-restore.*` before atomic replacement. Only
  previously running browsers are relaunched. Per-browser failures are reported,
  other targets are attempted, and partial failure returns a nonzero exit status.
- **Gecko:** prints the selected file and GUI restoration instructions. Complete
  restoration using **Bookmarks > Manage Bookmarks > Import and Backup > Restore
  > Choose File…** in the browser.

Restoration replaces existing bookmarks rather than merging them.

## Browser configuration

Browser definitions live in two sourced Zsh files:

- [`chromium_browsers.zsh`](chromium_browsers.zsh): ordered browser IDs, application/
  process names, and user-data roots for Chromium extraction and restoration.
- [`gecko_browsers.zsh`](gecko_browsers.zsh): ordered browser IDs, display names,
  user-data roots, and optional alternate roots for Gecko extraction and manual
  restore instructions.

These files contain declarations only. Each extraction/restoration entry point
contains its own operational functions and sources only its browser configuration.
Snapshot-handling functions are intentionally duplicated; changes to common
behavior should be applied to each relevant copy. Paths currently target macOS
and expand `$HOME` when sourced.

To add a browser, append its CLI ID to the family's `*_BROWSERS` array and add
matching entries to `*_BROWSER_NAMES` and `*_BROWSER_ROOTS`. Browser IDs should be
unique lowercase names; `all` is reserved. Array order determines iteration and
which browser wins when extraction candidates have equal dates/modification
times. Help text and browser validation use this list automatically.

- **Chromium:** the configured name must match both the `.app` bundle basename
  and the main process name. The root must contain profile directories with
  local `Bookmarks` files; restoration defaults to the `Default` profile. The
  browser must support the existing quit/relaunch and profile-argument workflow.
- **Gecko:** the root must contain `Profiles/*/bookmarkbackups/*.jsonlz4`, using
  the supported native backup filename format. An optional
  `GECKO_BROWSER_ALTERNATE_ROOTS` entry is used only when the primary root directory
  does not exist. Zen currently prefers `zen` over `Zen`, even if both exist.

`--browser` selects a configured extraction browser, and extraction `--profile`
bypasses root discovery for that browser. Chromium restoration accepts `--app`
and `--profile` overrides keyed by configured browser ID. Gecko restoration uses
the configured display names in its manual instructions.

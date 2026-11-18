# Browser snapshots

These macOS/Zsh helpers copy one bookmark snapshot and restore it within the same browser family. Run any entry point with `--help` for its options.

## LibreWolf permissions

```sh
./extract_librewolf_browsing_data_exceptions.zsh [--dry-run] [PROFILE_DIRECTORY]
```

Close LibreWolf first. This macOS/Linux helper saves only **Browsing data exceptions** (`persist-data-on-shutdown`: sites allowed to retain data when LibreWolf closes) as `librewolf_browsing_data_exceptions-YYYYMMDD_HHMMSS.secret.sqlite` beside the script. It requires `sqlite3` and discovers the default profile from `profiles.ini` in native Linux, XDG, Flatpak, or macOS locations; a positional profile overrides `LIBREWOLF_PROFILE`. Ambiguous fallback profiles require an explicit path.

Existing backups are never overwritten; same-second collisions fail. The source database and any WAL/SHM sidecars are copied and byte-verified in private staging. SQLite merges WAL data, retains only `persist-data-on-shutdown` permissions, empties auxiliary tables (including site-interaction records), and runs `VACUUM` to remove deleted URLs from unused space. The schema and version are preserved, integrity is checked, and one standalone database is published with the exception count reported. An empty exception list is valid. All SQLite operations use staged copies so the source is untouched.

Persistent regular lock files such as `.parentlock` are allowed when `lsof` confirms no process has them open. `lsof` is required when these files exist. Open lock files, legacy symlink locks, and inspection errors cause an abort. `--dry-run` performs discovery and safety checks without writing files.

Snapshots match this repository's `*.secret.*` git-crypt attributes, encrypting them when added to Git. They remain ordinary SQLite files in an unlocked checkout. Older snapshots may contain all permissions and have `-wal`/`-shm` sidecars; keep those legacy file sets together.

### Restore LibreWolf permissions

```sh
# Restore the latest snapshot beside the resolved script
./restore_librewolf_permissions.zsh

# Preview the selected snapshot, destination, and installation method
./restore_librewolf_permissions.zsh --dry-run

# Restore a specific snapshot into an explicit profile
./restore_librewolf_permissions.zsh --snapshot ./librewolf_browsing_data_exceptions-20261118_235853.secret.sqlite "/path/to/profile"
```

The latest snapshot is selected by its `YYYYMMDD_HHMMSS` filename timestamp, not modification time; only exact `librewolf_browsing_data_exceptions-YYYYMMDD_HHMMSS.secret.sqlite` names are selected automatically. Use `--snapshot FILE` for older `librewolf_permissions-*` snapshots; this option accepts any filename, including legacy snapshots without `.secret`. Relative paths use the current working directory. Profile selection follows the extractor: positional profile, then `LIBREWOLF_PROFILE`, then default-profile discovery. The profile directory must exist, but its database may be absent.

Close LibreWolf yourself before restoring. The script checks processes and profile locks, aborts if LibreWolf is running, and leaves it closed afterward. It requires `sqlite3`, `pgrep`, standard shell utilities, and `lsof` when regular profile lock files exist. Restoration runs without a confirmation prompt and replaces **all site permissions**, including cookie exceptions. Restoring a new exceptions-only snapshot therefore clears other site permissions; the current restore script does not merge just the Browsing data exception list. It does not restore cookies or enterprise policies.

The snapshot and any matching `-wal`/`-shm` files are copied and byte-verified in private staging inside the profile. SQLite merges WAL data into a standalone database, checks integrity, and verifies the permissions table and core columns. The snapshot itself is never opened by SQLite or modified. Keep the snapshot and its matching sidecars together. `--dry-run` writes nothing and runs preflight checks; SQLite validation happens only during an actual restore.

Restoration treats the selected snapshot as the complete replacement database and creates no backups or rollback. After validation, old `permissions.sqlite-wal` and `permissions.sqlite-shm` sidecars are removed and the prepared database is installed by an atomic rename as `permissions.sqlite`, with owner-only read/write permissions. Temporary staging and the restore lock are cleaned up on normal exit and handled failures.

Validation failures leave the target permissions untouched. If installation fails or is interrupted after replacement begins, the old file set may already have changed. Keep LibreWolf closed and rerun restoration from the snapshot. To apply a different saved state, pass that extracted snapshot with `--snapshot`. After successful restoration, open LibreWolf manually and inspect the **Browsing data** exceptions in **Settings > Privacy & Security**.

Concurrent restores use a `.permissions-restore.lock` directory inside the profile. If an uncatchable termination leaves it behind, first ensure LibreWolf and every restore invocation are stopped, remove the empty lock directory, and rerun restoration from the snapshot. Keep LibreWolf closed throughout restoration; the checks do not prevent someone from launching it mid-operation. Unexpected symlinks/file types and SQLite rollback journals at the database paths cause an abort.

## Extract

```sh
zsh extract_chromium_based_browser_bookmarks.zsh [OUTPUT_DIR]
zsh extract_gecko_based_browser_bookmarks.zsh [OUTPUT_DIR]
```

The output directory defaults to the current directory and must already exist.

- **Chromium:** chooses the most recently modified local `Bookmarks` file across Helium, Brave, and Chrome profiles. Close the source browser first to flush its pending writes. Account/encrypted stores are not included.
- **Gecko:** chooses an existing Firefox, Zen, or Floorp automatic backup by its native filename date, then modification time for same-day backups. This does not create a fresh export of current bookmarks. The original filename is printed so its backup date is visible.

Use `--browser NAME` to restrict selection, `--browser NAME --profile DIRECTORY` for an explicit profile, or `--source FILE` for an explicit source file. Gecko automatically searches only standard `Profiles` directories; external profiles require `--profile`.

Snapshots retain the `*_based_browser_bookmarks_YYYYMMDD_HHMMSS.secret.*` naming format. Exports produce one private file, without metadata sidecars. If a same-second snapshot already exists, export fails without overwriting it; retry in the next second. Copy verification compares bytes, not bookmark contents.

## Restore

```sh
zsh restore_chromium_based_browser_bookmarks.zsh [SOURCE_FILE_OR_DIR]
zsh restore_gecko_based_browser_bookmarks.zsh [SOURCE_FILE_OR_DIR]
```

The source defaults to the directory containing the script, regardless of the current working directory. An explicit file selects that exact copy, even if it is older, and may have any name. An explicit directory selects its latest matching snapshot. Relative source paths are resolved from the current working directory.

Directory selection uses the latest raw snapshot filename timestamp, including historical six-digit collision suffixes, rather than filesystem modification time. Derived files such as `*_sorted.*` are excluded.

Examples from the repository root:

```sh
# Latest snapshot alongside the script
zsh browser_bookmarks/restore_chromium_based_browser_bookmarks.zsh

# A specific older copy
zsh browser_bookmarks/restore_chromium_based_browser_bookmarks.zsh browser_bookmarks/chromium_based_browser_bookmarks_20260611_110828.secret.json

# Latest snapshot in another directory (manual Gecko restoration)
zsh browser_bookmarks/restore_gecko_based_browser_bookmarks.zsh "/path/to/bookmark backups"
```

Extraction still writes to the current directory by default. If snapshots were exported elsewhere, pass that directory or a specific snapshot file to restore.

- **Chromium:** replaces local bookmarks in the `Default` profile of every supported installed browser. Applications are found in `~/Applications` and `/Applications`. Use repeatable `--app BROWSER=APP_PATH` and `--profile BROWSER=DIRECTORY` overrides for custom locations. Existing bookmarks are backed up as `Bookmarks.before-restore.*` before atomic replacement. Only previously running browsers are relaunched. Per-browser failures are reported, other targets are attempted, and partial failure returns a nonzero exit status.
- **Gecko:** prints the selected file and GUI restoration instructions. Complete restoration using **Bookmarks > Manage Bookmarks > Import and Backup > Restore
  > Choose File…** in the browser.

Restoration replaces existing bookmarks rather than merging them.

## Browser configuration

Browser definitions live in two sourced Zsh files:

- [`chromium_browsers.zsh`](chromium_browsers.zsh): ordered browser IDs, application/ process names, and user-data roots for Chromium extraction and restoration.
- [`gecko_browsers.zsh`](gecko_browsers.zsh): ordered browser IDs, display names, user-data roots, and optional alternate roots for Gecko extraction and manual restore instructions.

These files contain declarations only. Each extraction/restoration entry point contains its own operational functions and sources only its browser configuration. Snapshot-handling functions are intentionally duplicated; changes to common behavior should be applied to each relevant copy. Paths currently target macOS and expand `$HOME` when sourced.

To add a browser, append its CLI ID to the family's `*_BROWSERS` array and add matching entries to `*_BROWSER_NAMES` and `*_BROWSER_ROOTS`. Browser IDs should be unique lowercase names; `all` is reserved. Array order determines iteration and which browser wins when extraction candidates have equal dates/modification times. Help text and browser validation use this list automatically.

- **Chromium:** the configured name must match both the `.app` bundle basename and the main process name. The root must contain profile directories with local `Bookmarks` files; restoration defaults to the `Default` profile. The browser must support the existing quit/relaunch and profile-argument workflow.
- **Gecko:** the root must contain `Profiles/*/bookmarkbackups/*.jsonlz4`, using the supported native backup filename format. An optional `GECKO_BROWSER_ALTERNATE_ROOTS` entry is used only when the primary root directory does not exist. Zen currently prefers `zen` over `Zen`, even if both exist.

`--browser` selects a configured extraction browser, and extraction `--profile` bypasses root discovery for that browser. Chromium restoration accepts `--app` and `--profile` overrides keyed by configured browser ID. Gecko restoration uses the configured display names in its manual instructions.

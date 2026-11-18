#!/usr/bin/env zsh
# Restore LibreWolf Browsing data exceptions on macOS/Linux.
# Usage: restore_librewolf_browsing_data_exceptions.zsh [OPTIONS] [PROFILE_DIRECTORY]

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
umask 077
typeset -r SCRIPT_DIR="${0:A:h}"

function die() {
	print -ru2 -- "Error: $*"
	exit 1
}

function usage() {
	print -r -- 'Usage: restore_librewolf_browsing_data_exceptions.zsh [OPTIONS] [PROFILE_DIRECTORY]
  --snapshot FILE  Restore this file instead of the latest snapshot
  --dry-run        Show the planned restore without writing files
  -h, --help       Show help
  --               End options (for profile paths starting with a dash)

By default, select the latest
librewolf_browsing_data_exceptions-YYYYMMDD_HHMMSS.secret.sqlite beside the
resolved script, ordered by filename timestamp. Use --snapshot FILE for older
librewolf_permissions-* snapshots or any other filename, including files without
.secret. Relative paths use the current working directory.
The positional profile overrides LIBREWOLF_PROFILE; otherwise discover the
default profile in the first existing native Linux, XDG, Flatpak, or macOS root.
The profile must exist, but permissions.sqlite may be absent.

LibreWolf must already be closed. Process or profile lock detection aborts;
this script neither closes nor launches LibreWolf. sqlite3 is required. Existing
regular profile lock files require lsof to confirm they are not in use.

Restore replaces just persist-data-on-shutdown entries, preserving
other permissions and interaction records.
An empty exception list clears existing exceptions. Both legacy full
snapshots and extract_librewolf_browsing_data_exceptions.zsh snapshots are supported.
If permissions.sqlite is absent, selective restore creates an exceptions-only
database using the snapshot schema. An existing invalid database causes an abort.
Restoration runs without a confirmation prompt and does not restore cookies or
enterprise policies. Database/WAL/SHM files are copied and validated in private
staging; selective restore also captures the destination and checks it for changes
before installation. The result is installed as a standalone permissions.sqlite.
Restoration creates no backups and performs no rollback.
If installation fails, keep LibreWolf closed and rerun restoration from the
snapshot. Temporary staging and the restore lock are cleaned up on normal exit
and handled failures.
Dry-run performs preflight checks only; SQLite validation requires staging and
therefore happens only during an actual restore.'
}

# Keep discovery and browser/lock checks aligned with the extractor. Unlike extraction, restoration also supports a profile with no permissions database.
function find_profile() {
	local override=$1 base="" candidate selected=""
	local -a roots profiles
	if [[ -n "$override" ]]; then
		selected=$override
	else
		roots=(
			"$HOME/.librewolf"
			"$HOME/.config/librewolf/librewolf"
			"$HOME/.var/app/io.gitlab.librewolf-community/.librewolf"
			"$HOME/Library/Application Support/LibreWolf"
		)
		for candidate in "${roots[@]}"; do
			if [[ -d "$candidate" ]]; then
				base=$candidate
				break
			fi
		done
		[[ -n "$base" ]] || die 'no LibreWolf profile root found; pass a profile directory or set LIBREWOLF_PROFILE'
		if [[ -f "$base/profiles.ini" ]]; then
			selected=$(awk -v base="$base" '
				function resolve(p, relative) {
					return relative && substr(p, 1, 1) != "/" ? base "/" p : p
				}
				function finish() {
					if (section ~ /^Install/ && def != "" && install == "")
						install = resolve(def, 1)
					if (section ~ /^Profile/ && def == "1" && path != "" && profile == "")
						profile = resolve(path, relative != "0")
				}
				{
					sub(/\r$/, "")
					if ($0 ~ /^[[:space:]]*[;#]/) next
					if ($0 ~ /^\[.*\][[:space:]]*$/) {
						finish()
						section = $0
						sub(/^\[/, "", section)
						sub(/\][[:space:]]*$/, "", section)
						def = path = relative = ""
						next
					}
					eq = index($0, "=")
					if (!eq) next
					key = substr($0, 1, eq - 1)
					value = substr($0, eq + 1)
					gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
					gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
					if (key == "Default") def = value
					if (key == "Path") path = value
					if (key == "IsRelative") relative = value
				}
				END { finish(); if (install != "") print install; else if (profile != "") print profile }
			' "$base/profiles.ini") || die "could not read $base/profiles.ini"
		fi
		if [[ -z "$selected" ]]; then
			profiles=("$base"/*.default*(N/) "$base"/Profiles/*.default*(N/))
			(( ${#profiles} )) || die "no default profile found in $base; pass a profile directory"
			(( ${#profiles} == 1 )) || die "multiple candidate profiles in $base; pass a profile directory"
			selected=$profiles[1]
		fi
	fi
	[[ -d "$selected" ]] || die "profile directory not found: $selected"
	print -r -- "${selected:A}"
}

function check_not_running() {
	local profile=$1 process lock_file lock_info
	local -i result
	for process in librewolf librewolf-bin LibreWolf; do
		if pgrep -x "$process" >/dev/null; then
			die 'Close LibreWolf completely and try again.'
		else
			result=$?
			(( result == 1 )) || die "could not check for the $process process (pgrep exited $result)"
		fi
	done
	for lock_file in lock .parentlock parent.lock; do
		if [[ -L "$profile/$lock_file" ]]; then
			die "profile lock symlink found: $profile/$lock_file. Close LibreWolf completely and try again."
		fi
		[[ -e "$profile/$lock_file" ]] || continue
		[[ -f "$profile/$lock_file" ]] || die "unexpected profile lock type: $profile/$lock_file"
		(( $+commands[lsof] )) || die "lsof is required to check whether $profile/$lock_file is in use"
		if lock_info=$(lsof -nP -F p -- "$profile/$lock_file" 2>&1); then
			die "profile lock is in use: $profile/$lock_file. Close LibreWolf completely and try again."
		else
			result=$?
			(( result == 1 )) && [[ -z "$lock_info" ]] || die "could not inspect profile lock: $profile/$lock_file (lsof exited $result): $lock_info"
		fi
	done
}

function select_snapshot() {
	local selected=$1 candidate pattern='^librewolf_browsing_data_exceptions-[0-9]{8}_[0-9]{6}\.secret\.sqlite$'
	local -a candidates
	local -x LC_ALL=C
	if [[ -z "$selected" ]]; then
		candidates=("$SCRIPT_DIR"/librewolf_browsing_data_exceptions-*.secret.sqlite(NOn.))
		for candidate in "${candidates[@]}"; do
			if [[ ${candidate:t} =~ $pattern ]]; then
				selected=$candidate
				break
			fi
		done
		[[ -n "$selected" ]] || die "no snapshots found in $SCRIPT_DIR"
	fi
	[[ -f "$selected" && -r "$selected" && -s "$selected" ]] || die "snapshot is missing, unreadable, or empty: $selected"
	print -r -- "${selected:A}"
}

function check_files() {
	local base=$1 suffix file
	for suffix in '' -wal -shm; do
		file="$base$suffix"
		[[ ! -L "$file" ]] || die "unexpected symlink: $file"
		[[ -e "$file" ]] || continue
		[[ -f "$file" && -r "$file" ]] || die "expected a readable regular file: $file"
	done
	# A hot rollback journal could replay old content over the replacement.
	[[ ! -e "$base-journal" && ! -L "$base-journal" ]] || die "unexpected SQLite rollback journal: $base-journal"
}

function check_no_overlap() {
	local snapshot=$1 dest=$2 source_suffix target_suffix
	for source_suffix in '' -wal -shm; do
		for target_suffix in '' -wal -shm; do
			[[ "$snapshot$source_suffix" != "$dest$target_suffix" && ! "$snapshot$source_suffix" -ef "$dest$target_suffix" ]] || die "snapshot overlaps target permissions files: $snapshot$source_suffix"
		done
	done
}

function stage_database() {
	local source=$1 directory=$2 suffix integrity schema
	[[ -s "$source" ]] || die "database is empty: $source"
	mkdir -- "$directory" "$directory/raw" "$directory/work" || die 'could not create staging subdirectories'
	for suffix in '' -wal -shm; do
		[[ -z "$suffix" || -e "$source$suffix" ]] || continue
		cp -p -- "$source$suffix" "$directory/raw/permissions.sqlite$suffix" || die "could not stage $source$suffix"
		cmp -s -- "$source$suffix" "$directory/raw/permissions.sqlite$suffix" || die "source changed or verification failed: $source$suffix"
	done
	# Keep raw captures untouched for comparison; SQLite can modify even read-only SHM.
	cp -p -- "$directory/raw/"* "$directory/work/" || die 'could not prepare working copy'
	chmod 600 "$directory/work/"* || die 'could not prepare staged files'
	# Fixed relative SQLite paths also support profile names containing quotes.
	(cd -- "$directory" && sqlite3 -bail work/permissions.sqlite '.backup permissions.sqlite') || die 'SQLite backup failed'
	integrity=$(sqlite3 "$directory/permissions.sqlite" 'PRAGMA journal_mode=DELETE;') || die 'could not finalize staged database'
	[[ "$integrity" == delete ]] || die "could not disable WAL: $integrity"
	integrity=$(sqlite3 -readonly "$directory/permissions.sqlite" 'PRAGMA integrity_check;') || die 'SQLite integrity check failed'
	[[ "$integrity" == ok ]] || die "database integrity check failed: $integrity"
	schema=$(sqlite3 -readonly "$directory/permissions.sqlite" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='moz_perms';") || die 'could not inspect permissions schema'
	[[ "$schema" == 1 ]] || die "database does not contain the moz_perms table: $source"
	sqlite3 -readonly "$directory/permissions.sqlite" 'SELECT id, origin, type, permission, expireType, expireTime, modificationTime FROM moz_perms LIMIT 0;' || die "database is missing required permissions columns: $source"
}

function restore_permissions() (
	unsetopt ERR_EXIT
	local snapshot=$1 profile=$2
	local dest="$profile/permissions.sqlite" mutex="$profile/.permissions-restore.lock"
	local stage="" staged suffix integrity clear_tables exceptions
	local -i locked=0 modifying=0 complete=0

	function cleanup_restore() {
		local -i result=$?
		trap - EXIT
		# Finish cleanup even if a second interrupt arrives.
		trap '' INT TERM HUP
		if (( modifying && ! complete )); then
			print -ru2 -- "Installation did not complete. Keep LibreWolf closed and rerun restoration from snapshot: $snapshot"
			(( result != 0 )) || result=1
		fi
		[[ -z "$stage" ]] || rm -rf -- "$stage" || result=1
		(( ! locked )) || rmdir -- "$mutex" || result=1
		exit "$result"
	}
	trap cleanup_restore EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	trap 'exit 129' HUP
	mkdir -- "$mutex" || die "restore lock already exists or cannot be created: $mutex"
	locked=1
	check_not_running "$profile"
	check_files "$snapshot"
	check_files "$dest"
	check_no_overlap "$snapshot" "$dest"
	stage=$(mktemp -d "$profile/.permissions-restore.XXXXXXXX") || die 'could not create staging directory'
	stage_database "$snapshot" "$stage/snapshot"
	staged="$stage/snapshot/permissions.sqlite"
	if [[ -e "$dest" ]]; then
		stage_database "$dest" "$stage/target"
		staged="$stage/target/permissions.sqlite"
		(cd -- "$stage/target" && sqlite3 -bail permissions.sqlite "
			ATTACH '../snapshot/permissions.sqlite' AS snapshot;
			BEGIN;
			DELETE FROM moz_perms WHERE type = 'persist-data-on-shutdown';
			INSERT INTO moz_perms (origin, type, permission, expireType, expireTime, modificationTime)
			SELECT origin, type, permission, expireType, expireTime, modificationTime
			FROM snapshot.moz_perms WHERE type = 'persist-data-on-shutdown';
			COMMIT;") || die 'could not replace Browsing data exceptions'
	else
		# Bootstrap from the snapshot schema, without its unrelated records or deleted URLs.
		clear_tables=$(sqlite3 -readonly "$staged" "SELECT printf('DELETE FROM \"%w\";', name)
			FROM sqlite_master WHERE type = 'table' AND name <> 'moz_perms'
			AND name NOT GLOB 'sqlite_*';") || die 'could not inspect permissions schema'
		sqlite3 -bail "$staged" "BEGIN;
			DELETE FROM moz_perms WHERE type IS NOT 'persist-data-on-shutdown';
			$clear_tables
			COMMIT; VACUUM;" || die 'could not filter Browsing data exceptions'
	fi
	integrity=$(sqlite3 -readonly "$staged" 'PRAGMA integrity_check;') || die 'SQLite integrity check failed'
	[[ "$integrity" == ok ]] || die "restored database integrity check failed: $integrity"
	exceptions=$(sqlite3 -readonly "$staged" "SELECT count(*) FROM moz_perms WHERE type = 'persist-data-on-shutdown';") || die 'could not count exceptions'
	chmod 600 "$staged" || die 'could not set database permissions'

	# Validate fully before installing; selective restore must preserve the captured state.
	check_not_running "$profile"
	check_files "$dest"
	for suffix in '' -wal -shm; do
		if [[ -e "$stage/target/raw/permissions.sqlite$suffix" ]]; then
			cmp -s -- "$dest$suffix" "$stage/target/raw/permissions.sqlite$suffix" || die "destination changed during restore: $dest$suffix"
		else
			[[ ! -e "$dest$suffix" ]] || die "unexpected destination file during restore: $dest$suffix"
		fi
	done
	modifying=1
	rm -f -- "$dest-wal" "$dest-shm" || die 'could not remove previous permissions sidecars'
	# Staging is on the target filesystem, so this replaces the database by rename.
	mv -f -- "$staged" "$dest" || die 'could not install permissions database'
	complete=1
	print -r -- "Snapshot: $snapshot"
	print -r -- "Restored: $dest"
	print -r -- "Scope: Browsing data exceptions only (persist-data-on-shutdown); restored: $exceptions"
	print -r -- 'Integrity: ok; permissions schema verified'
	print -r -- 'Open LibreWolf manually. Check Browsing data exceptions in Settings > Privacy & Security.'
	return 0
)

function main() {
	local override="${LIBREWOLF_PROFILE-}" snapshot="" profile command_name
	local -i dry_run=0 positional=0 snapshot_given=0
	while (( $# )); do
		case "$1" in
			-h|--help) usage; return 0 ;;
			--dry-run) dry_run=1; shift ;;
			--snapshot)
				(( ! snapshot_given )) || die '--snapshot may only be specified once'
				(( $# >= 2 )) || die '--snapshot requires a file path'
				[[ -n "$2" ]] || die 'snapshot path cannot be empty'
				snapshot=$2 snapshot_given=1
				shift 2 ;;
			--) shift; break ;;
			-*) die "unknown option: $1" ;;
			*)
				(( ! positional )) || die 'expected at most one profile directory'
				[[ -n "$1" ]] || die 'profile directory cannot be empty'
				override=$1 positional=1
				shift ;;
		esac
	done
	if (( $# )); then
		(( $# == 1 && ! positional )) || die 'expected at most one profile directory'
		[[ -n "$1" ]] || die 'profile directory cannot be empty'
		override=$1
	fi
	for command_name in sqlite3 pgrep awk cp cmp chmod mkdir mktemp mv rm rmdir; do
		(( $+commands[$command_name] )) || die "$command_name is required"
	done
	snapshot=$(select_snapshot "$snapshot") || return 1
	profile=$(find_profile "$override") || return 1
	[[ -w "$profile" && -x "$profile" ]] || die "profile directory is not writable/searchable: $profile"
	check_files "$snapshot"
	check_files "$profile/permissions.sqlite"
	check_no_overlap "$snapshot" "$profile/permissions.sqlite"
	check_not_running "$profile"
	[[ ! -e "$profile/.permissions-restore.lock" && ! -L "$profile/.permissions-restore.lock" ]] || die "restore lock already exists: $profile/.permissions-restore.lock"
	if (( dry_run )); then
		print -r -- "Snapshot: $snapshot"
		print -r -- "Destination: $profile/permissions.sqlite"
		print -r -- 'Scope: Browsing data exceptions only (persist-data-on-shutdown); preserve other permissions and interaction records.'
		print -r -- 'Method: validate a staged SQLite copy, remove old WAL/SHM sidecars, and replace permissions.sqlite without creating backups.'
		print -r -- 'Dry-run: no files written; SQLite integrity/schema validation will run during actual restoration.'
		return 0
	fi
	restore_permissions "$snapshot" "$profile"
}

main "$@"

#!/usr/bin/env zsh
# Snapshot LibreWolf permissions (including cookie exceptions) on macOS/Linux.
# Usage: extract_managed_exceptions_librewolf.zsh [--dry-run] [PROFILE_DIRECTORY]
# LIBREWOLF_PROFILE supplies a profile when no positional override is given.
# Backups are saved beside this script, including when invoked through a symlink.

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
umask 077
typeset -r SCRIPT_DIR="${0:A:h}"

function die() {
	print -ru2 -- "Error: $*"
	exit 1
}

function usage() {
	print -r -- 'Usage: extract_managed_exceptions_librewolf.zsh [OPTIONS] [PROFILE_DIRECTORY]
  --dry-run     Show the source, destination, and copy method without writing
  -h, --help    Show help
  --            End options (for profile paths starting with a dash)

The positional profile overrides LIBREWOLF_PROFILE. Otherwise, discover the
default profile in the first existing native Linux, XDG, Flatpak, or macOS root.
LibreWolf must be closed; process or profile lock detection aborts the snapshot.
Persistent regular lock files are checked with lsof, not by existence alone.

Output: permissions-YYYYMMDD-HHMMSS.secret.sqlite beside the resolved script.
An existing same-second backup is never overwritten; retry in the next second.
SQLite, when available, merges WAL data and checks integrity on a private copy.
Otherwise, database/WAL/SHM files are copied together and byte-verified. Keep
these sidecars alongside the backup. The source profile is never modified.
This copies all permissions, not just cookie exceptions or enterprise policies.'
}

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
			# Section order and key order are independent. Install defaults take
			# precedence; their paths are relative unless explicitly absolute.
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
	selected=${selected:A}
	[[ -f "$selected/permissions.sqlite" && -r "$selected/permissions.sqlite" && -s "$selected/permissions.sqlite" ]] \
		|| die "permissions.sqlite is missing, unreadable, or empty in $selected"
	print -r -- "$selected"
}

function check_not_running() {
	local profile=$1 process lock_file lock_info
	local -i result
	(( $+commands[pgrep] )) || die 'pgrep is required to check whether LibreWolf is running'
	for process in librewolf librewolf-bin LibreWolf; do
		if pgrep -x "$process" >/dev/null; then
			die 'Close LibreWolf completely and try again.'
		else
			result=$?
			(( result == 1 )) || die "could not check for the $process process (pgrep exited $result)"
		fi
	done
	for lock_file in lock .parentlock parent.lock; do
		# Gecko leaves regular .parentlock files behind after a clean shutdown.
		# Legacy symlink locks encode ownership rather than an open file, so
		# retain the conservative refusal for those (including dangling links).
		if [[ -L "$profile/$lock_file" ]]; then
			die "profile lock symlink found: $profile/$lock_file. Close LibreWolf completely and try again."
		fi
		[[ -e "$profile/$lock_file" ]] || continue
		[[ -f "$profile/$lock_file" ]] || die "unexpected profile lock type: $profile/$lock_file"
		(( $+commands[lsof] )) || die "lsof is required to check whether $profile/$lock_file is in use"
		# Any open handle is enough to refuse. Avoid -t (which implies -w), so
		# diagnostics are preserved and inspection failures cannot look idle.
		if lock_info=$(lsof -nP -F p -- "$profile/$lock_file" 2>&1); then
			die "profile lock is in use: $profile/$lock_file. Close LibreWolf completely and try again."
		else
			result=$?
			(( result == 1 )) && [[ -z "$lock_info" ]] \
				|| die "could not inspect profile lock: $profile/$lock_file (lsof exited $result): $lock_info"
		fi
	done
}

function copy_permissions() (
	# Keep cleanup active on failures, including partially published sidecar sets.
	unsetopt ERR_EXIT
	local profile=$1 dest=$2 use_sqlite=$3 stage="" source staged suffix integrity bytes
	local -a suffixes=("") published=() link_options
	local -i complete=0
	function cleanup_permissions() {
		local -i result=$?
		trap - EXIT
		if (( ! complete && ${#published} )); then
			rm -f -- "${published[@]}" || result=1
		fi
		[[ -z "$stage" ]] || rm -rf -- "$stage" || result=1
		exit "$result"
	}
	trap cleanup_permissions EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	stage=$(mktemp -d "$SCRIPT_DIR/.permissions-export.XXXXXXXX") || die 'could not create staging directory'
	mkdir -- "$stage/raw" "$stage/out" || die 'could not create staging subdirectories'
	for suffix in -wal -shm; do
		[[ ! -e "$profile/permissions.sqlite$suffix" ]] || suffixes+=("$suffix")
	done
	for suffix in "${suffixes[@]}"; do
		source="$profile/permissions.sqlite$suffix"
		cp -p -- "$source" "$stage/raw/permissions.sqlite$suffix" || die "could not copy $source"
		cmp -s -- "$source" "$stage/raw/permissions.sqlite$suffix" || die "source changed or verification failed: $source"
	done
	# Recheck after capture in case the browser was opened during the copy.
	check_not_running "$profile"
	staged="$stage/raw/permissions.sqlite"
	if (( use_sqlite )); then
		# SQLite may create/update SHM files even for read-only connections. Only
		# open the staged database, and use a fixed backup name to avoid quoting
		# arbitrary directory names inside SQLite dot-command syntax.
		chmod u+rw "$stage/raw/permissions.sqlite"* || die 'could not prepare staged database'
		(cd -- "$stage/out" && sqlite3 ../raw/permissions.sqlite '.backup permissions.sqlite') \
			|| die 'SQLite backup failed'
		staged="$stage/out/permissions.sqlite"
		# A backup can inherit WAL journal mode. Normalize the copy so it opens
		# as a standalone read-only database without needing writable sidecars.
		integrity=$(sqlite3 "$staged" 'PRAGMA journal_mode=DELETE;') || die 'could not finalize SQLite backup'
		[[ "$integrity" == delete ]] || die "could not disable WAL on backup: $integrity"
		integrity=$(sqlite3 -readonly "$staged" 'PRAGMA integrity_check;') || die 'SQLite integrity check failed'
		[[ "$integrity" == ok ]] || die "backup integrity check failed: $integrity"
		suffixes=("")
	fi
	[[ -s "$staged" ]] || die 'backup is missing or empty'
	bytes=$(wc -c < "$staged") || die 'could not determine backup size'
	bytes=${bytes//[[:space:]]/}
	# Hard links publish without replacing existing paths. Disable following
	# destination directory symlinks on both BSD and GNU implementations.
	if [[ "$OSTYPE" == darwin* ]]; then link_options=(-h); else link_options=(-T); fi
	for suffix in "${suffixes[@]}"; do
		ln "${link_options[@]}" -- "$staged$suffix" "$dest$suffix" || die "could not publish backup (destination may already exist): $dest$suffix"
		published+=("$dest$suffix")
	done
	complete=1
	print -r -- "Source: $profile/permissions.sqlite"
	print -r -- "Saved: $dest"
	print -r -- "Size: $bytes bytes"
	if (( use_sqlite )); then
		print -r -- 'Integrity: ok'
	else
		print -r -- 'Verification: byte-for-byte copy (sqlite3 unavailable)'
		for suffix in "${suffixes[@]}"; do
			[[ -z "$suffix" ]] || print -r -- "Sidecar: $dest$suffix"
		done
	fi
	return 0
)

function main() {
	local override="${LIBREWOLF_PROFILE-}" profile stamp dest suffix
	local -i dry_run=0 positional=0 use_sqlite=$+commands[sqlite3]
	while (( $# )); do
		case "$1" in
			-h|--help) usage; return 0 ;;
			--dry-run) dry_run=1; shift ;;
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
	profile=$(find_profile "$override") || return 1
	check_not_running "$profile"
	stamp=$(date '+%Y%m%d-%H%M%S') || die 'could not generate backup timestamp'
	dest="$SCRIPT_DIR/permissions-$stamp.secret.sqlite"
	for suffix in '' -wal -shm; do
		[[ ! -e "$dest$suffix" && ! -L "$dest$suffix" ]] || die "backup already exists: $dest$suffix; retry in the next second"
	done
	if (( dry_run )); then
		print -r -- "Source: $profile/permissions.sqlite"
		print -r -- "Destination: $dest"
		if (( use_sqlite )); then
			print -r -- 'Method: SQLite backup and integrity check on a staged copy'
		else
			print -r -- 'Method: cp -p with WAL/SHM sidecars and byte verification'
		fi
		return 0
	fi
	copy_permissions "$profile" "$dest" "$use_sqlite"
}

main "$@"

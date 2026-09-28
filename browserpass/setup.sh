#!/bin/sh
# Register Homebrew's Browserpass host for installed browsers.
# Runnable from any directory; it uses no files from this repository.

set -eu

app_installed() {
	[ -d "/Applications/$1.app" ] || [ -d "$HOME/Applications/$1.app" ]
}

register_browserpass_host() (
	src=$1 directory=$2
	dest="$directory/$manifest"
	if [ ! -f "$src" ]; then
		printf '%s\n' "Missing Browserpass host manifest (repair the installation): $src" >&2
		return 1
	fi
	if ! executable=$(/usr/bin/plutil -extract path raw -o - "$src" 2>/dev/null) \
		|| [ "${executable#/}" = "$executable" ] || [ ! -f "$executable" ] || [ ! -x "$executable" ]; then
		printf '%s\n' "Invalid Browserpass manifest or executable (repair the installation): $src" >&2
		return 1
	fi
	# ln -sf follows symlinks to directories; never write inside one.
	if [ -d "$dest" ] || { [ -e "$dest" ] && [ ! -L "$dest" ]; }; then
		printf '%s\n' "Conflicting destination; move it aside before rerunning setup: $dest" >&2
		return 1
	fi
	if ! mkdir -p "$directory" || ! ln -sf "$src" "$dest" \
		|| [ ! -L "$dest" ] || [ ! "$dest" -ef "$src" ]; then
		printf '%s\n' "Browserpass registration failed: $dest" >&2
		return 1
	fi
	printf '%s\n' "Browserpass host configured: $dest"
)

configure_browserpass() {
	if [ "$(uname -s)" != Darwin ]; then
		printf '%s\n' "Browserpass setup supports macOS only" >&2
		return 1
	fi

	if ! app_installed Firefox && ! app_installed Floorp && ! app_installed Helium; then
		printf '%s\n' "No supported browsers installed, skipping Browserpass setup"
		return 0
	fi

	if [ ! -x /opt/homebrew/bin/brew ]; then
		printf '%s\n' "Homebrew not installed, skipping Browserpass setup"
		return 0
	fi
	prefix=/opt/homebrew/opt/browserpass
	if [ ! -d "$prefix" ]; then
		printf '%s\n' "Browserpass not installed, skipping native messaging host setup"
		return 0
	fi

	support="$HOME/Library/Application Support"
	manifest=com.github.browserpass.native.json
	failed=0
	# Floorp shares Mozilla's host directory; Helium also searches Chrome's.
	# https://github.com/imputnet/helium/blob/main/patches/helium/core/scan-chrome-native-messaging-hosts.patch
	if app_installed Firefox || app_installed Floorp; then
		register_browserpass_host "$prefix/lib/browserpass/hosts/firefox/$manifest" \
			"$support/Mozilla/NativeMessagingHosts" || failed=1
	fi
	if app_installed Helium; then
		chromium_host="$prefix/lib/browserpass/hosts/chromium/$manifest"
		helium_host="$support/net.imput.helium/NativeMessagingHosts/$manifest"
		if [ -f "$chromium_host" ] && { [ -e "$helium_host" ] || [ -L "$helium_host" ]; } \
			&& [ ! "$helium_host" -ef "$chromium_host" ]; then
			printf '%s\n' "Helium-local manifest overrides Chrome registration; move it aside: $helium_host" >&2
			failed=1
		else
			register_browserpass_host "$chromium_host" \
				"$support/Google/Chrome/NativeMessagingHosts" || failed=1
		fi
	fi
	return "$failed"
}

configure_browserpass

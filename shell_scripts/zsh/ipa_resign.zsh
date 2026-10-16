#!/bin/env zsh
#
# IPA Resign
# Standalone Zsh port of XReSign.app/Contents/Resources/xresign.sh.

emulate -R zsh
# Match the /bin/sh expansion rules used by the application, including its
# unquoted custom-entitlements copy and unmatched globs. Do not enable errexit:
# the original script continues after command failures, including codesign.
setopt SH_WORD_SPLIT GLOB_SUBST NONOMATCH

usage="IPA Resign
Usage: ${0:t} -s IPA -c CERTIFICATE [options]

  -s  Path to the unencrypted source IPA
  -c  Signing certificate Common Name from Keychain
  -p  Replacement app provisioning profile (optional)
  -e  Custom app entitlements plist (optional; otherwise extracted from profile)
  -b  Replacement app bundle identifier (optional)
  -v  Replacement CFBundleVersion and CFBundleShortVersionString (optional)
  -z  Replacement NotificationService.iOS.appex provisioning profile (optional)
  -x  Replacement NotificationService.iOS.appex bundle identifier (optional)
  -u  Entitlements plist for NotificationService.iOS.appex
  -h  Show this help

Output: <app-name>-xresign.ipa beside the source IPA."

# The GUI passes an empty string for each unused option.
SOURCEIPA=''
DEVELOPER=''
MOBILEPROV=''
ENTITLEMENTS=''
BUNDLEID=''
VERSIONNUMBER=''
MOBILEPROVPUSH=''
BUNDLEIDPUSH=''
ENTITLEMENTSPUSHEXT=''
OPTIND=1

while getopts ':s:c:e:u:p:b:v:z:x:h' option; do
    case "$option" in
        s) SOURCEIPA=$OPTARG ;;
        c) DEVELOPER=$OPTARG ;;
        e) ENTITLEMENTS=$OPTARG ;;
        u) ENTITLEMENTSPUSHEXT=$OPTARG ;;
        p) MOBILEPROV=$OPTARG ;;
        b) BUNDLEID=$OPTARG ;;
        v) VERSIONNUMBER=$OPTARG ;;
        z) MOBILEPROVPUSH=$OPTARG ;;
        x) BUNDLEIDPUSH=$OPTARG ;;
        h) print -r -- "$usage"; exit 0 ;;
        \?) print -ru2 -- "invalid option: -$OPTARG" "$usage"; exit 1 ;;
        :) print -ru2 -- "missing argument for -$OPTARG" "$usage"; exit 1 ;;
    esac
done

if [[ -z "$SOURCEIPA" || -z "$DEVELOPER" ]]; then
    print -ru2 -- 'An IPA path (-s) and signing certificate (-c) are required.' "$usage"
    exit 1
fi

# File-picker URLs in the application are absolute. Resolve relative CLI input
# before the packaging step changes directory.
SOURCEIPA=${SOURCEIPA:a}

print -r -- 'Start (re)sign the app...'
OUTDIR=$(dirname "$SOURCEIPA")
TMPDIR="$OUTDIR/tmp"
APPDIR="$TMPDIR/app"

mkdir -p "$APPDIR"
unzip -qo "$SOURCEIPA" -d "$APPDIR"

APPLICATION=$(ls "$APPDIR/Payload/")
APP_PATH="$APPDIR/Payload/$APPLICATION"

if [[ -z "$MOBILEPROV" ]]; then
    print -r -- 'Sign process using existing provisioning profile from payload'
else
    print -r -- 'Coping provisioning profile into application payload'
    cp "$MOBILEPROV" "$APP_PATH/embedded.mobileprovision"
fi

print -r -- 'Extract entitlements from mobileprovision'
if [[ -z "$ENTITLEMENTS" ]]; then
    security cms -D -i "$APP_PATH/embedded.mobileprovision" > "$TMPDIR/provisioning.plist"
    /usr/libexec/PlistBuddy -x -c 'Print:Entitlements' "$TMPDIR/provisioning.plist" > "$TMPDIR/entitlements.plist"
else
    # Deliberately retain the original /bin/sh word splitting and globbing.
    cp ${ENTITLEMENTS} "$TMPDIR/entitlements.plist"
    print -r -- "$ENTITLEMENTS"
fi

if [[ -z "$BUNDLEID" ]]; then
    print -r -- 'Sign using existing bundle identifier from payload'
else
    print -r -- "Changing bundle identifier with: $BUNDLEID"
    /usr/libexec/PlistBuddy -c "Set:CFBundleIdentifier $BUNDLEID" "$APP_PATH/Info.plist"
fi

if [[ -z "$VERSIONNUMBER" ]]; then
    print -r -- 'Sign using existing versionnumber from payload'
else
    print -r -- "Changing versionnumber with: $VERSIONNUMBER"
    /usr/libexec/PlistBuddy -c "Set:CFBundleVersion $VERSIONNUMBER" "$APP_PATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Set:CFBundleShortVersionString $VERSIONNUMBER" "$APP_PATH/Info.plist"
fi

# Keep BSD find's depth-first filesystem order. Sorting or changing to a single
# signing pass would change extension numbering and/or enclosing signatures.
print -r -- "Get list of components and sign with certificate: $DEVELOPER"
find -d "$APP_PATH" \( -name '*.app' -o -name '*.appex' -o -name '*.framework' -o -name '*.dylib' \) > "$TMPDIR/components.txt"

print -r -- 'Sign plugins, frameworks, dylibs'
var=0
while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *NotificationService.iOS.appex ]]; then
        if [[ -z "$MOBILEPROVPUSH" ]]; then
            print -r -- 'Sign process using existing push provisioning profile from payload'
        else
            print -r -- 'Coping push provisioning profile into push extension payload'
            cp "$MOBILEPROVPUSH" "$line/embedded.mobileprovision"
        fi
        if [[ -n "$BUNDLEIDPUSH" ]]; then
            print -r -- "Changing NotificationService.iOS.appex bundle identifier with: $BUNDLEIDPUSH"
            /usr/libexec/PlistBuddy -c "Set:CFBundleIdentifier $BUNDLEIDPUSH" "$line/Info.plist"
        fi
        if [[ -z "$VERSIONNUMBER" ]]; then
            print -r -- 'Sign using existing versionnumber from payload for push extension'
        else
            print -r -- "Changing versionnumber of push extension with: $VERSIONNUMBER"
            /usr/libexec/PlistBuddy -c "Set:CFBundleVersion $VERSIONNUMBER" "$line/Info.plist"
            /usr/libexec/PlistBuddy -c "Set:CFBundleShortVersionString $VERSIONNUMBER" "$line/Info.plist"
        fi

        print -r -- "Changing entitlements of push extension with: $ENTITLEMENTSPUSHEXT"
        /usr/bin/codesign --continue --generate-entitlement-der -f -s "$DEVELOPER" --entitlements "$ENTITLEMENTSPUSHEXT" "$line"
    elif [[ "$line" == *.appex ]]; then
        if [[ -n "$BUNDLEID" ]]; then
            print -r -- "Changing .appex bundle identifier with: $BUNDLEID.extra$var"
            /usr/libexec/PlistBuddy -c "Set:CFBundleIdentifier $BUNDLEID.extra$var" "$line/Info.plist"
            var=$((var + 1))
        fi
        /usr/bin/codesign --continue --generate-entitlement-der -f -s "$DEVELOPER" --entitlements "$TMPDIR/entitlements.plist" "$line"
    elif [[ "$line" == *.framework ]]; then
        print -r -- "Changing signature of: $line without Entitlements!"
        rm -r "$line/_CodeSignature"
        /usr/bin/codesign --continue --generate-entitlement-der -f -s "$DEVELOPER" "$line"
    elif [[ "$line" == *.dylib ]]; then
        /usr/bin/codesign --continue --generate-entitlement-der -f -s "$DEVELOPER" --entitlements "$TMPDIR/entitlements.plist" "$line"
    fi
done < "$TMPDIR/components.txt"

print -r -- 'Sign app'
while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *.app ]]; then
        /usr/bin/codesign --continue --generate-entitlement-der -f -s "$DEVELOPER" --entitlements "$TMPDIR/entitlements.plist" "$line"
    fi
done < "$TMPDIR/components.txt"

cd "$APPDIR"
filename=$(basename "$APPLICATION")
filename="${filename%.*}-xresign.ipa"
print -r -- "Creating the signed ipa: $filename"
zip -qr "../$filename" *
cd ..
mv "$filename" "$OUTDIR"

print -r -- 'Clear temporary files'
rm -rf "$APPDIR"
# Like the application, retain tmp/components.txt, tmp/provisioning.plist
# (when generated) and tmp/entitlements.plist.
print -r -- 'IPA Resign FINISHED'

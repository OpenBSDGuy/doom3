#!/bin/sh
# patch.sh — Fix "Missing 'WEAPON_NETFIRING' field" error in dhewm3
# Patches all weapon scripts across all pak files.
# Usage: sh fix_dhewm3.sh

set -e

DHEWM3_BASE="$HOME/.config/dhewm3/base"
FIELD_NAME="WEAPON_NETFIRING"
TMPDIR="/tmp/dhewm3_fix"

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()   { printf "${GREEN}=>${NC} %s\n" "$1"; }
warn()   { printf "${YELLOW}WARN:${NC} %s\n" "$1"; }
errout() { printf "${RED}ERROR:${NC} %s\n" "$1"; exit 1; }

# --- Checks ---
[ -d "$DHEWM3_BASE" ] || errout "dhewm3 base dir not found at $DHEWM3_BASE"
command -v unzip > /dev/null 2>&1 || errout "'unzip' not found. Install: pkg_add unzip"
command -v zip   > /dev/null 2>&1 || errout "'zip' not found. Install: pkg_add zip"

# --- Remove stray gamex86.so ---
if [ -f "$DHEWM3_BASE/gamex86.so" ]; then
    warn "Removing conflicting gamex86.so..."
    rm "$DHEWM3_BASE/gamex86.so"
fi

# patch_script <filepath>
# Inserts WEAPON_NETFIRING into the first object definition found in the file.
patch_script() {
    FPATH="$1"
    FNAME=$(basename "$FPATH")

    if grep -q "$FIELD_NAME" "$FPATH"; then
        info "  $FNAME: already patched, skipping."
        return 0
    fi

    # Extract object name from file (e.g. 'object weapon_pistol')
    OBJ=$(grep -m1 "^object " "$FPATH" | awk '{print $2}')
    [ -z "$OBJ" ] && OBJ="unknown"

    # Method 1: insert before first closing brace of the object definition
    awk -v obj="$OBJ" '
    $0 ~ ("object " obj) { in_obj=1 }
    in_obj && /^[[:space:]]*\}[[:space:]]*;?[[:space:]]*$/ && !done {
        printf "\tboolean\t\tWEAPON_NETFIRING;\n"
        done=1
    }
    { print }
    ' "$FPATH" > "$FPATH.patched"

    # Method 2: after last boolean WEAPON_ line
    if ! grep -q "$FIELD_NAME" "$FPATH.patched"; then
        awk '
        /boolean[[:space:]]+WEAPON_[A-Za-z_]+;/ { last = NR }
        { lines[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == last) printf "\tboolean\t\tWEAPON_NETFIRING;\n"
            }
        }
        ' "$FPATH" > "$FPATH.patched"
    fi

    # Method 3: append a re-opened object block at end of file
    if ! grep -q "$FIELD_NAME" "$FPATH.patched"; then
        cp "$FPATH" "$FPATH.patched"
        printf "\n// dhewm3 fix\nobject %s {\n\tboolean\t\tWEAPON_NETFIRING;\n}\n" "$OBJ" >> "$FPATH.patched"
    fi

    if grep -q "$FIELD_NAME" "$FPATH.patched"; then
        mv "$FPATH.patched" "$FPATH"
        info "  $FNAME: patched OK."
    else
        rm -f "$FPATH.patched"
        warn "  $FNAME: all methods failed — skipping. Please report this."
    fi
}

# --- Find and patch all weapon scripts across all pak files ---
PATCHED_ANY=0

for PAK in "$DHEWM3_BASE"/pak*.pk4; do
    [ -f "$PAK" ] || continue

    # Find all weapon scripts in this pak
    WEAPON_SCRIPTS=$(unzip -l "$PAK" 2>/dev/null | awk '{print $4}' | grep '^script/weapon_.*\.script$' || true)
    [ -z "$WEAPON_SCRIPTS" ] && continue

    info "Processing $(basename $PAK)..."

    # Backup once per pak
    BACKUP="${PAK}.bak"
    if [ ! -f "$BACKUP" ]; then
        cp "$PAK" "$BACKUP"
        info "  Backup saved to $(basename $BACKUP)"
    fi

    # Set up temp working dir for this pak
    rm -rf "$TMPDIR"
    mkdir -p "$TMPDIR"
    cp "$PAK" "$TMPDIR/target.pk4"
    cd "$TMPDIR"

    # Extract all weapon scripts at once
    echo "$WEAPON_SCRIPTS" | xargs unzip -q target.pk4

    CHANGED=0
    for SCRIPT in $WEAPON_SCRIPTS; do
        if [ -f "$SCRIPT" ]; then
            BEFORE=$(md5 -q "$SCRIPT" 2>/dev/null || md5sum "$SCRIPT" 2>/dev/null | awk '{print $1}')
            patch_script "$SCRIPT"
            AFTER=$(md5 -q "$SCRIPT" 2>/dev/null || md5sum "$SCRIPT" 2>/dev/null | awk '{print $1}')
            [ "$BEFORE" != "$AFTER" ] && CHANGED=1
        fi
    done

    if [ "$CHANGED" = "1" ]; then
        info "  Repacking $(basename $PAK)..."
        echo "$WEAPON_SCRIPTS" | xargs zip -q -u target.pk4
        cp target.pk4 "$PAK"
        PATCHED_ANY=1
    else
        info "  No changes needed in $(basename $PAK)."
    fi

    cd /
    rm -rf "$TMPDIR"
done

# --- Patch any loose weapon scripts too ---
LOOSE_DIR="$DHEWM3_BASE/script"
if [ -d "$LOOSE_DIR" ]; then
    info "Checking loose script files in $LOOSE_DIR..."
    for SCRIPT in "$LOOSE_DIR"/weapon_*.script; do
        [ -f "$SCRIPT" ] || continue
        patch_script "$SCRIPT"
        PATCHED_ANY=1
    done
fi

if [ "$PATCHED_ANY" = "1" ]; then
    printf "\n${GREEN}All done!${NC} All weapon scripts patched. Launch dhewm3.\n"
else
    printf "\n${YELLOW}Nothing to patch${NC} — all weapon scripts already have $FIELD_NAME.\n"
fi

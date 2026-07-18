#!/bin/bash

set -e
set -o pipefail

MANIFEST=Manifest
STAGED_MANIFEST=Manifest.staged
BACKUP_DIR=Backup

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

usage() {
    cat <<EOF
Usage:
  $0 <command> [options]

Commands:
  init
      Initialize backup repository. Creates an empty manifest file. Fails if manifest already exists.

  status
      Show current backup status. Scans backup directory and compares with manifest.

  add
      Stage changes for commit. Builds staged manifest by merging current state.

  diff --staged
      Show differences between manifest and staged manifest.

  verify --staged
      Verify integrity of staged manifest. Checks file hashes against staged manifest.

  verify --full
      Verify integrity of full manifest.

  commit
      Apply staged changes. Replaces manifest with staged manifest.

Examples:
  $0 init
  $0 status
  $0 add
  $0 diff --staged
  $0 verify --staged
  $0 commit

Notes:
  - Backup directory: $BACKUP_DIR
  - Staged manifest is temporary and is removed on each add/commit
EOF
}

check_manifest_exists() {
    if [[ ! -f $MANIFEST ]]; then
        echo "No manifest file" >&2
        exit 1
    fi
}

check_manifest_does_not_exist() {
    if [[ -f $MANIFEST ]]; then
        echo "Manifest file already exists" >&2
        exit 1
    fi
}

check_staged_manifest_exists() {
    if [[ ! -f $STAGED_MANIFEST ]]; then
        echo $1 >&2
        exit 1
    fi
}

init() {
    check_manifest_does_not_exist
    touch $MANIFEST
}

status() {
    check_manifest_exists
    
    declare -A HASH SIZE MTIME
    
    while read -r hash size mtime file; do
        HASH[$file]=$hash
        SIZE[$file]=$size
        MTIME[$file]=$mtime
    done < $MANIFEST
    
    find $BACKUP_DIR -type f -printf "%s %T@ %p\n" | sort -k3 | while read -r size mtime file; do
        if [[ -z ${HASH[$file]} ]]; then
            echo -e "${GREEN}NEW: $file${RESET}"
            continue
        fi
        
        if [[ ${SIZE[$file]} == $size && ${MTIME[$file]} == $mtime ]]; then
            continue
        fi

        read hash file < <(sha256sum "$file")

        if [[ $hash != ${HASH[$file]} ]]; then
            echo -e "${RED}MODIFIED: $file${RESET}"
        else
            echo -e "SAME: $file"
        fi
    done
    
    for file in "${!HASH[@]}"; do
        if [[ ! -f $file ]]; then
            echo -e "${RED}DELETED: $file${RESET}"
            continue
        fi
    done
}

status_check_added_only() {
    check_manifest_exists
    
    declare -A HASH SIZE MTIME
    
    while read -r hash size mtime file; do
        HASH[$file]=$hash
        SIZE[$file]=$size
        MTIME[$file]=$mtime
    done < $MANIFEST
    
    find $BACKUP_DIR -type f -printf "%s %T@ %p\n" | sort -k3 | while read -r size mtime file; do
        if [[ -z ${HASH[$file]} ]]; then
            read hash file < <(sha256sum "$file")

            echo $hash $size $mtime $file

            continue
        fi

        if [[ ${SIZE[$file]} == $size && ${MTIME[$file]} == $mtime ]]; then
            continue
        fi

        read hash file < <(sha256sum "$file")

        if [[ $hash != ${HASH[$file]} ]]; then
            echo "Modified files found" >&2
            exit 1
        fi
    done
    
    for file in "${!HASH[@]}"; do
        if [[ ! -f $file ]]; then
            echo "Removed files found" >&2
            exit 1
        fi
    done
}

add() {
    check_manifest_exists
    cat $MANIFEST <(status_check_added_only) | sort -k4 > $STAGED_MANIFEST
}

diff() {
    case "$1" in
        --staged)
            check_manifest_exists
            check_staged_manifest_exists "No files to diff"
            
            command diff --color=always $MANIFEST $STAGED_MANIFEST
            ;;
        *)
            echo "Unknown parameter: $1" >&2
            usage
            exit 1
            ;;
    esac
}

verify() {
    case "$1" in
        --staged)
            check_manifest_exists
            check_staged_manifest_exists "No files to verify"
            
            sha256sum -c <(command diff --new-line-format='%L' --old-line-format='' --unchanged-line-format='' $MANIFEST $STAGED_MANIFEST |
              while read -r hash size mtime file; do
                  echo "$hash  $file"
              done)
            ;;
        --full)
            check_manifest_exists
            sha256sum -c <(cat $MANIFEST | while read -r hash size mtime file; do
                  echo "$hash  $file"
              done)
            ;;
        *)
            echo "Unknown parameter: $1" >&2
            usage
            exit 1
            ;;
    esac
}

commit() {
    check_manifest_exists
    check_staged_manifest_exists "No files to commit"
    
    mv $STAGED_MANIFEST $MANIFEST
}

case "${1:-}" in
    init|status|add|diff|verify|commit)
        cmd="$1"
        shift
        "$cmd" "$@"
        ;;
    ""|-h|--help|help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac

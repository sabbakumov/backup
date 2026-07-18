# backup
Backup Bash script for archiving data based on a manifest. Data integrity is verified using SHA-256 checksums, file sizes, and modification times

```
Usage:
  ./backup.sh <command> [options]

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
  ./backup.sh init
  ./backup.sh status
  ./backup.sh add
  ./backup.sh diff --staged
  ./backup.sh verify --staged
  ./backup.sh commit

Notes:
  - Backup directory: Backup
  - Staged manifest is temporary and is removed on each add/commit
```

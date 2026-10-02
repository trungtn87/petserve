# Portable backups

Settings → Data → Export backup / Restore from file. The egg screen also exposes the same actions for fresh installs and replacement devices.

Android uses ACTION_CREATE_DOCUMENT / ACTION_OPEN_DOCUMENT through PetVerseBackup, bundled in the existing Android plugin AAR. No broad storage permission is requested. Installed document providers, including Google Drive when available on the device, can store and retrieve the chosen file. This release supports manual provider backups; it does not implement OAuth or scheduled Drive synchronization.

The `.petbackup` file is a ZIP containing a versioned manifest, SHA-256 checksums and allowlisted JSON state / actual rendered images. It excludes credentials, API tokens, logs, caches and unknown files. Limits: 128 MiB total uncompressed data, 16 MiB per entry, 512 data files. ZIP central-directory limits and paths are checked before decompression. Newer backup formats and newer pet/inventory schemas are rejected without replacing data.

Restore validates the complete archive, shows pet name/stage/date/image, saves the current state into `backups/before_restore.petbackup`, and records a write-ahead restore marker before replacing files. On interruption, BackupService rolls back before save readers start. Missing files are removed, including fallback generations, so previous-life state is not resurrected. A recovery error stops startup to avoid overwriting the pending snapshot. Live gameplay saves are suppressed during successful restore and the main scene reloads.

AtomicJson writes via temporary files and preserves the previous valid JSON generation. Egg, hatch, evolution and main save readers use that fallback. Explicit resets remove all generations. The backup is a recovery feature, not a tamper-proof multiplayer authority; offline users can restore older progress.

Backup/restore tests: `XDG_DATA_HOME=/tmp/petverse-backup-test godot --headless --path . tools/test_backup.tscn`.

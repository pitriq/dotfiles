# Reclaim areas

Each area owns the paths listed under it. `clean`, `ask`, and `keep` are the proposals from SKILL.md; where this file and SKILL.md's defaults disagree, SKILL.md wins. Leave paths another area owns to that area. The off-limits list at the end applies to every area.

## A. Workspaces and databases

Owns: Git checkouts under `~/Developer` and the worktree roots (`~/.supacode/repos`, `~/.t3/worktrees`, `~/Developer/apps/conductor/workspaces`, `~/conductor/workspaces`), with their build outputs, leftover folders, and workspace databases.

Start with `python3 scan-workspaces.py` from this directory (`--no-gh` skips PR lookups, extra arguments replace `~/Developer` as the roots). It is read-only, takes about a minute, and prints JSON:

- `checkouts`: every main checkout and worktree with its branch, `locked`, `missing`, `dirty_files`, `unpushed_commits` (commits on no remote branch), `last_commit` and `last_index_change` (Unix times), `merged_into_<base>`, `upstream_gone`, `pr` (the newest PR for the branch), `symlinks` pointing at it, `workspace_db`, `gb`, and `outputs` (Git-ignored build folders such as `node_modules`, `target`, `.dart_tool`, `Pods`, with sizes).
- `orphan_dirs`: folders in the worktree roots that no repo lists as a worktree, and folders whose `.git` points at a gitdir that is gone.
- `databases`: every database (except `postgres`) in a running `postgres_<repo>` container, with its size and the checkout that owns it (`null` when none does). Ownership is the `dbName:` in `<worktree>/.workspace`, otherwise `<repo>_<worktree folder>` lowercased with `-` as `_`, plus companions such as `<that>_console`.
- `errors`: commands that failed or timed out.

Judge each item from that output, and only run more commands to fill a gap:

- **Worktrees.** Clean when there are no uncommitted or untracked files and nothing unpushed, whatever the PR state. Then the worktree, its symlinks, its database, and companion DBs go as one item. Note processes running in it (`lsof +D`) as a precondition. A worktree with uncommitted or untracked work is ask; list the untracked files. A `missing` worktree is housekeeping (`git worktree prune`).
- **Main checkouts.** Keep. Their `outputs` are clean when the repo has had no commit or index change in 30 days, with the rebuild as the cost. In active repos they are keep, apart from Rust `target` dirs, which are clean.
- **Orphan folders.** Clean when they hold no `.git` of their own or the gitdir is gone, after a look at what's inside. A folder with its own repo is ask.
- **Orphan databases.** Clean (the user drops orphans by default); note writes since the container started (`pg_stat_database`). If `postgres_<repo>` isn't running, say so and don't start it. Other `*_<repo>` containers (redis, minio) are only checked for per-workspace data when it is cheap.
- **Leftovers** next to repos that aren't checkouts, such as `~/Developer/apps/trashlab/snapshots`: size them and judge by name and date.

## B. Apple

Owns: `~/Library/Developer`, Xcode apps, CocoaPods caches, device backups.

- **DerivedData.** Read `WorkspacePath` from each entry's `info.plist`. A missing workspace is clean. An existing one untouched for 30 days is clean with the rebuild as the cost. The rest is keep.
- **Xcode.** `Archives` (ask: they hold dSYMs for shipped builds), `iOS DeviceSupport` and `watchOS DeviceSupport` per OS version (clean for versions older than any device you still use), `UserData/Previews`, `XCPGDevices`, `XCTestDevices`, `DVTDownloads`.
- **Simulators.** `xcrun simctl list devices -j`: unavailable devices are clean (`xcrun simctl delete unavailable`). For the rest, size the device's data directory and find its last use; ones not booted in 30 days are clean. `CoreSimulator/Caches` is clean.
- **Runtimes.** `xcrun simctl runtime list -j` with sizes. A runtime is clean when no device with app data that is still kept uses it; its never-booted devices go with it.
- **Xcode apps.** Every `Xcode*.app` in `/Applications` other than the one `xcode-select -p` points at.
- **CocoaPods.** `~/Library/Caches/CocoaPods` and `~/.cocoapods/repos` are clean.
- **Device backups.** `~/Library/Application Support/MobileSync/Backup` is ask.

## C. Android and Flutter

Owns: `~/.android`, `~/Library/Android/sdk`, `~/.gradle`, `~/fvm`, `~/.pub-cache`.

- **AVDs.** For each `~/.android/avd/*.avd`: size, the system image from `config.ini`, and last use (newest mtime among `userdata-qemu.img*` and `snapshots`). Quickboot snapshots are clean; they come back on the next cold boot. An AVD unused for 30 days is clean (`avdmanager delete avd -n <name>`, or `emulator -avd <name> -wipe-data` to keep it but drop its data).
- **System images.** Images under `sdk/system-images` that no AVD's `config.ini` references are clean (`sdkmanager --uninstall`).
- **SDK packages.** `build-tools`, `platforms`, `ndk`, `cmake` versions. Grep the repos for `compileSdk`, `targetSdk`, `ndkVersion`, `buildToolsVersion`, and the Flutter defaults. Unreferenced versions older than the newest one are clean.
- **Gradle.** `~/.gradle/caches` (clean, large rebuild), `~/.gradle/daemon` logs (clean), `~/.gradle/wrapper/dists` versions that no `gradle-wrapper.properties` in the repos references (clean).
- **Flutter.** `~/fvm/versions` that no `.fvmrc` or `.fvm/fvm_config.json` in the repos references and that is not the global default (clean). `~/.pub-cache` (clean).
- `~/.android/cache` is clean.

## D. Docker and OrbStack

Owns: everything inside Docker and OrbStack, and OrbStack's data under `~/Library/Group Containers/*.dev.orbstack` and `~/.orbstack`.

- `docker system df -v` for the breakdown.
- **Images.** Dangling ones are clean. Ones no container uses are clean, at the cost of a re-pull.
- **Containers.** Stopped ones, with their image, age, and the project from the `com.docker.compose.project` label. Clean when stopped for 30 days.
- **Volumes.** Size and the containers that mount them. An unused volume is ask, because it may be the only copy of a database. Volumes behind repo containers (such as `*_trashlab`) are keep; their contents are area A's problem.
- **Build cache** is clean (`docker builder prune`).
- **OrbStack.** Compare the data directory's size with the total from `docker system df`. A large gap is space OrbStack hasn't given back; check `orbctl` help or OrbStack's docs for how to reclaim it, and don't guess. List OrbStack machines (`orbctl list`) with their sizes.

## E. Caches, toolchains, and personal files

Owns: everything not owned above. Skip the paths of areas A to D.

- **`~/Library/Caches`** by top-level directory, mapped to its app. Caches of apps no longer installed are clean. Others are clean with the cost named. If the app is running (`pgrep`), say to quit it first.
- **Package managers.** npm (`~/.npm/_cacache`), pnpm (`pnpm store path`; `pnpm store prune`), bun (`~/.bun/install/cache`), pip (`pip3 cache info`), Homebrew (`brew cleanup -n -s`, `brew autoremove --dry-run`).
- **Rust.** `~/.cargo/registry` and `~/.cargo/git` (clean, redownloaded), `rustup toolchain list` with sizes under `~/.rustup/toolchains` (old nightlies and toolchains no `rust-toolchain*` file in the repos pins are clean).
- **agent-browser.** `~/.agent-browser/browsers/chrome-*`, about 380 MB each. Run `agent-browser install` first: it downloads nothing when the Chrome the installed CLI needs is present, and names that version. Every other version is clean.
- **Node.** `fnm list` with sizes; versions no `.nvmrc`, `.node-version`, or `engines` field in the repos asks for, other than the default, are clean.
- **Agent and editor data.** `~/.t3` (outside `worktrees`) and Cursor and VS Code `workspaceStorage`, `CachedData`, and `CachedExtensionVSIXs`. Caches, logs, and backups are clean; session history is ask.
- **Trash.** Size of `~/.Trash`. Emptying it is its own step, after other cleanup.
- **Large files.** Files over 1 GB in the home directory outside the paths above and the off-limits ones (`find ~ -xdev -size +1G`, with a timeout and the owned paths pruned). Ask.
- **App leftovers.** Directories in `~/Library/Application Support` and `~/Library/Containers` over 500 MB whose app is no longer installed. Ask.
- **Logs.** `~/Library/Logs` and `DiagnosticReports` are clean.
- **Time Machine.** `tmutil listlocalsnapshots /`. List them; macOS frees them when it needs space.

## Off-limits

Never list these for cleanup, in any area or tier. Size them only to explain where the space goes, as keep:

- Personal media and music: `~/Music`, `~/Movies`, `~/Pictures`, the Photos library, and everything that belongs to music apps and audio plugins, caches included (Spotify, Ableton, Logic, Waves, Native Instruments and Native Access, iZotope, Splice, and similar).
- `~/Downloads`.
- Codex and Claude: `~/.codex`, `~/.claude`, `~/.claude.json`, and their caches.

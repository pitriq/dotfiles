---
name: verify
description: "Prove a change works on the real surface (web, iOS, Android, API, CLI) and capture evidence. Use to reproduce a bug before fixing it, before reporting a change as done, or when the user asks to verify, test it in the app, or show it working."
---

# Verify

Drive the real surface the way a user does, and capture what happened as evidence. A green build, a passing typecheck, or a test suite is not verification here.

## Pick the driver

1. **A project skill comes first.** If the repo has a `verify-*` skill, read it and use it. Then read `projects/<project>.md` next to this file if one exists (`projects/trashlab.md` for TrashLab), which adds the project's ports, logins, and logs.
2. **Otherwise pick by surface.**
   - **Web.** Use the `agent-browser` skill. Read it before the first command.
   - **iOS.** Slim the simulator first (see "Slim iOS simulators" below), then use the `serve-sim` skill. Read it before the first command.
   - **Android.** Use the Android lane below, which drives the emulator with the `serve-avd` skill.
   - **API.** Call the endpoint with `curl`, read the server's dev log for the request, and confirm the stored state with a read-only database query.
   - **CLI or TUI.** Run the real command and keep its output.
3. A change that touches two surfaces gets verified on both.

In a T3 thread, the user can watch instead of reading screenshots: `preview_open` shows a web page in the thread, and `device_open` shows a simulator or emulator in the Device panel. Use them when the user asks to see it, or when a visual change is the point.

## Android lane

Drive the `Pixel_9_Pro` emulator with the `serve-avd` skill (read it before the first command), and use raw `adb` for what it does not cover. A physical phone may be plugged in, so pin every call to the emulator's serial: `--device "$S"` for serve-avd and `adb -s "$S"` for adb. Never run a bare `adb` or `serve-avd` command.

1. **Find or start the emulator.** Run `adb devices` and look for an `emulator-NNNN` serial. If none is running, start it with `emulator -avd Pixel_9_Pro -no-snapshot-save &`, record that this run started it, and read the new serial from `adb devices`. Set `S=emulator-NNNN`.
2. **Wait for boot.** Poll `adb -s "$S" shell getprop sys.boot_completed` until it prints `1`.
3. **Guard the launcher ANR.** Right after boot, Pixel Launcher can stop responding. Do not send `keyevent 82` to unlock right after boot. Check first with `serve-avd find "isn't responding" --device "$S"`. If it matches, run `serve-avd tap --text "Wait" --device "$S"` and check again before you drive anything.
4. **Drive the app.** Tap by text, id, or description with `serve-avd tap`, then `serve-avd wait` for the element the next screen should show. Type with `serve-avd type` and press keys with `serve-avd button`. Never hardcode coordinates. If serve-avd fails, fall back to `adb -s "$S" shell uiautomator dump /sdcard/ui.xml`, pull it, read the node's `bounds="[x1,y1][x2,y2]"`, and tap its center with `adb -s "$S" shell input tap`.
5. **Capture evidence.** Screenshots with `serve-avd screenshot <artifact dir>/<step>.png --device "$S"`. Video with `adb -s "$S" shell screenrecord /sdcard/<name>.mp4` (stop it with Ctrl-C or `--time-limit`), then `pull` it. Logs with `adb -s "$S" logcat --pid="$(adb -s "$S" shell pidof -s <package>)" -d > <artifact dir>/logcat.txt`, so only the app's process shows.
6. **Clean up.** Stop any serve-avd server this run started (`serve-avd --kill "$S"`) and delete the snapshots it saved. Kill the emulator (`adb -s "$S" emu kill`) only if step 1 started it.

## Slim iOS simulators

Every simulator an agent drives runs slim by default, including a single one. `simslim` turns off the background daemons a simulator does not need (Siri, Spotlight, widgets, iCloud sync and so on): a stock simulator uses about 4 GB and a slim one about 1 GB. Skip it only when the user asks for a stock simulator, or when the test is about a service slimming turns off.

1. **Check before slimming.** On a booted simulator, `simslim verify <udid> <flags>` exits 0 when it already matches, so run `simslim on` only when it fails. A simulator that is shut down cannot be verified, so go straight to `simslim on`, which is idempotent and applies only the missing part.
2. **Keep what the app uses.** Slimming turns off push, StoreKit, iCloud, Photos, Contacts, and more. The project file names the `--except <category>` and `--keep <launchd label>` flags its apps need (`simslim profiles` lists categories). Pass the same flags to `verify` and `on`. Without a project file, check the app's native dependencies and keep what it uses.
3. **Slim before the app runs.** On a simulator that is shut down, `simslim on <udid> <flags> --preserve-boot-state` slims it and leaves it shut down. On a booted one, add `--no-reboot` so it slims in place without restarting the user's session.
4. **Confirm the features.** `simslim doctor <udid> --requires <features>` (`simslim doctor --list` lists them) exits non-zero if something the app needs is off.

The change is stored in the simulator and survives reboots, so later runs find it already slim. `simslim off <udid>` puts a simulator back to stock. With more than one simulator booted, pass `-d <udid>` to every serve-sim command. Say in the reply which simulators you slimmed.

## When

Verify a bug on its surface before the fix, compare variants when choosing between them, and verify once more before reporting the work done. Never verify after each edit. While the user is iterating visually, verify only when they ask, because they check it themselves.

Invoking `/verify` or `/build` is the user's ask to run the app and drive a browser, simulator, or emulator, which repos such as TrashLab require before those flows. Outside those, when the repo's rules say to run the app only when asked, follow them and report the change as unverified instead of done.

## Evidence

Each check records three things: the action taken, the resulting state, and its side effects (the request in the log, the row in the database, the event sent). Save artifacts under `/tmp/verify/<task-slug>/` and name that directory in the reply. Embed screenshots inline. A claim without an artifact is labeled a guess.

## Cleanup

Stop only what this run started: dev servers, simulators, emulators, browser sessions, and recordings. Leave everything the user already had running. Delete temporary files with `trash`, never `rm`.

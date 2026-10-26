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
   - **iOS.** Use the `serve-sim` skill. Read it before the first command.
   - **Android.** Use the Android lane below.
   - **API.** Call the endpoint with `curl`, read the server's dev log for the request, and confirm the stored state with a read-only database query.
   - **CLI or TUI.** Run the real command and keep its output.
3. A change that touches two surfaces gets verified on both.

In a T3 thread, the user can watch instead of reading screenshots: `preview_open` shows a web page in the thread, and `device_open` shows a simulator or emulator in the Device panel. Use them when the user asks to see it, or when a visual change is the point.

## Android lane

Drive the `Pixel_9_Pro` emulator over `adb`. A physical phone may be plugged in, so pin every `adb` call to the emulator's serial and never run a bare `adb` command.

1. **Find or start the emulator.** Run `adb devices` and look for an `emulator-NNNN` serial. If none is running, start it with `emulator -avd Pixel_9_Pro -no-snapshot-save &`, record that this run started it, and read the new serial from `adb devices`. Use `S=emulator-NNNN` and write every call as `adb -s "$S" ...`.
2. **Wait for boot.** Poll `adb -s "$S" shell getprop sys.boot_completed` until it prints `1`.
3. **Guard the launcher ANR.** Right after boot, Pixel Launcher can stop responding. Do not send `keyevent 82` to unlock right after boot. Dump the screen first (step 4). If it shows "Pixel Launcher isn't responding", tap its "Wait" button and dump again before you drive anything.
4. **Find elements from the UI tree.** Run `adb -s "$S" shell uiautomator dump /sdcard/ui.xml` and `adb -s "$S" pull /sdcard/ui.xml <artifact dir>/ui.xml`. Match the node by `text`, `resource-id`, or `content-desc`, read its `bounds="[x1,y1][x2,y2]"`, and tap the center with `adb -s "$S" shell input tap <(x1+x2)/2> <(y1+y2)/2>`. Never hardcode coordinates. Dump again after every screen change.
5. **Type and press keys.** `adb -s "$S" shell input text '<text>'` (spaces as `%s`) and `adb -s "$S" shell input keyevent <KEYCODE>`.
6. **Capture evidence.** Screenshots with `adb -s "$S" exec-out screencap -p > <artifact dir>/<step>.png`. Video with `adb -s "$S" shell screenrecord /sdcard/<name>.mp4` (stop it with Ctrl-C or `--time-limit`), then `pull` it. Logs with `adb -s "$S" logcat --pid="$(adb -s "$S" shell pidof -s <package>)" -d > <artifact dir>/logcat.txt`, so only the app's process shows.
7. **Clean up.** Kill the emulator (`adb -s "$S" emu kill`) only if step 1 started it.

## When

Verify a bug on its surface before the fix, compare variants when choosing between them, and verify once more before reporting the work done. Never verify after each edit. While the user is iterating visually, verify only when they ask, because they check it themselves.

Invoking `/verify` or `/build` is the user's ask to run the app and drive a browser, simulator, or emulator, which repos such as TrashLab require before those flows. Outside those, when the repo's rules say to run the app only when asked, follow them and report the change as unverified instead of done.

## Evidence

Each check records three things: the action taken, the resulting state, and its side effects (the request in the log, the row in the database, the event sent). Save artifacts under `/tmp/verify/<task-slug>/` and name that directory in the reply. Embed screenshots inline. A claim without an artifact is labeled a guess.

## Cleanup

Stop only what this run started: dev servers, simulators, emulators, browser sessions, and recordings. Leave everything the user already had running. Delete temporary files with `trash`, never `rm`.

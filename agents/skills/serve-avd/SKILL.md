---
name: serve-avd
description: "Drive and stream a running Android Emulator with the installed serve-avd CLI: tap and wait on UI elements by text or resource id, type, swipe, press buttons, take screenshots, dump the UI tree, reset state with snapshots, and set GPS, network, battery, and locale. Use for Android emulator verification and debugging, usually through the verify skill's Android lane. For iOS simulators use serve-sim."
---

# serve-avd

[serve-avd](https://github.com/hsandhu/serve-avd) is an Android port of serve-sim. It drives a running emulator over adb and can also stream it to a browser. It is installed globally with `bun add -g serve-avd`, so call the `serve-avd` binary. If it is missing, ask the user to run `bun add -g serve-avd`. Do not fall back to `npx serve-avd`: inside a large repo npx takes 15 s or more per call.

The `verify` skill's Android lane owns booting the emulator, the launcher ANR guard, port forwarding, and cleanup. This skill covers driving the app.

## Pin the device

A physical phone may be plugged in. With no device given, a serve-avd command falls back to the first online device, and the server attaches to every online device, so a bare command can land on the phone.

- Read the emulator serial (`emulator-NNNN`) from `adb devices` and set `S`.
- Pass `--device "$S"` to every subcommand. Write it out in full: on the top-level command `-d` means `--detach`, not device.
- Start a server only with the serial as a positional argument: `serve-avd --detach -q "$S"`.

## Commands

```sh
serve-avd find "Sign in" --device "$S" --json          # matches with bounds, centers, normalized coords
serve-avd tap --text "Sign in" --device "$S"           # or --id <name> | --desc <text>, plus --index n, --exact, --long
serve-avd wait "Welcome" --timeout 15s --device "$S"   # exit 2 on timeout; --gone waits for it to disappear
serve-avd type "hello" --device "$S"                   # ASCII only, into the focused field
serve-avd button back --device "$S"                    # home | back | app-switch | power | volume-up | ...
serve-avd swipe 0.5 0.8 0.5 0.3 --device "$S"          # normalized 0..1 points
serve-avd tap 0.5 0.9 --device "$S"                    # coordinates, only when nothing matches by text or id
serve-avd screenshot <artifact dir>/<step>.png --device "$S"
serve-avd ax --device "$S"                             # full UI tree as JSON
serve-avd foreground --device "$S"                     # { packageName, activity, pid }
serve-avd open "myapp://orders/42" --device "$S"       # deep link
serve-avd launch <package> --device "$S"
serve-avd snapshot save <name> --device "$S"           # snapshot load | delete <name>, snapshot list
```

Emulator controls (`geo`, `network`, `battery`, `a11y`, `fingerprint`, `sms`, `call`) and app management (`install`, `stop`, `clear-data`) follow the same pattern. Run `serve-avd <command> --help` for flags before using one for the first time.

## Rules

- Target elements by text, id, or description. When a match is ambiguous, run `find` and pick one with `--index`. If nothing matches, report the target as not found instead of tapping a guessed coordinate.
- After an action that changes the screen, `wait` for the element the next screen should show. Do not sleep.
- Every `find`, `tap --text`, and `wait` poll runs a uiautomator dump, which takes 1 to 3 s and longer on screens that never go idle, such as spinners. When you need several facts about one screen, read them from one `ax` call.
- Save a snapshot before a flow that is expensive to set up (login, starting the day), and load it to reset between attempts. Delete the snapshots this run saved when you are done.
- For the user to watch in T3, use `device_open`. Start `serve-avd --detach -q "$S"` only when the user wants a browser or shareable stream, and stop it with `serve-avd --kill "$S"` when done.
- Use raw `adb -s "$S" ...` for what serve-avd does not cover, such as `adb reverse`, `screenrecord`, and logcat filtered by pid.

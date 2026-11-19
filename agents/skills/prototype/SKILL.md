---
name: prototype
description: "Build several genuinely different working versions of one UI piece behind a live picker, so the user can flip through them in the real app and promote the one that feels right. TRIGGER ONLY when the user explicitly invokes /prototype, or accepts /design-explore's offer to prototype its directions. Do not trigger for ordinary UI work or from /build."
disable-model-invocation: true
---

# Prototype

Build several working versions of one piece of UI, put them behind a picker in the real app, and let the user flip through them and choose. The user makes the choice, so this skill never runs inside an autonomous flow. Adapted from Emil Kowalski's `prototype` (MIT, see `LICENSE`).

The whole value is divergence. Three tints of the same idea teach the user nothing when they flip between them. Each variant is a direction you could defend shipping on its own.

## Rules

1. **Production code stays untouched until the user picks.** Variants live in an isolated prototype surface (step 4). Only the winner gets integrated, in step 6.
2. **Variants diverge on a named axis:** layout, density, personality, motion, or interaction model. State each variant's axis in a phrase before building, and no two variants share a position on an axis. Sharing the project's tokens is fine, since every variant should look like it could ship in this product.
3. **Every variant fully works.** Real interactions, real states, product-shaped copy, and plausible names and numbers. No lorem ipsum, no dead buttons, no "imagine this part". Divergence is no excuse for sloppy execution, because a sloppy variant loses on execution and teaches nothing about its direction.
4. **The picker is chrome.** On web it follows [PICKER.md](PICKER.md) verbatim and never adopts the project's look.
5. **Clean up after the choice.** Delete the prototype surface once a winner is promoted, unless the user asks to keep it.

## 1. Scope

One piece per run. If the request spans several components ("the dashboard"), pick the single piece with the most leverage, say which and why, and offer the rest as follow-up runs. Restate the brief in one sentence: what it is, where it lives, what it must do.

Coming from `/design-explore`, its brief and directions are the input. Use its direction names, axes, wireframes, and real field names, and skip to step 4 once you've confirmed the directions still pass Rule 2.

## 2. Recon

Map what the variants must stand on:

- **Stack:** framework, styling system, motion library if any.
- **Tokens:** colors, radii, spacing, fonts, easing and duration variables.
- **Personality:** a playful consumer app or a crisp dashboard. This bounds how far the boldest variant may go.
- **Context:** where the piece renders, against what background, next to what, at what sizes.

With no project (an empty directory, or the user is just exploring), use the standalone branch in step 4 and a restrained default look: neutral grays, one accent, the system font stack.

## 3. Choose directions

Default to 3 variants, and go up to 5 when the user asks or the design space is wide. More than 5 dilutes the comparison.

Before writing code, list the set with a name and an axis for each. Names describe the direction ("Quiet", "Editorial", "Dense"), never "Option A". If two directions would differ only in accent color or copy, they are one direction. Replace one with a real alternative: a different layout, interaction model, or motion story.

## 4. Build the harness

- **Web with a dev server:** a dev-only route (`/prototypes/<slug>` or the framework's equivalent), one file per variant plus a small harness file. Nothing in production imports from it. The picker follows PICKER.md: its markup, styles, keys, and URL param, expressed idiomatically in the framework.
- **Expo or native:** a dev-only screen reachable from the dev menu or a deep link, one file per variant. The picker copies PICKER.md's look and behavior as closely as the platform allows: a dark pill fixed bottom-center, tap to switch, the selection kept across reloads, and switching re-mounts the variant.
- **No project:** one self-contained HTML file with inline CSS and JS, wired with PICKER.md's reference script.

The harness renders one variant at a time, full size, in realistic context. A toast needs a page behind it, a card needs siblings, a button needs a form. Side-by-side thumbnails distort spacing and scale. Switching is instant with no transition, since the user flips a hundred times a session.

## 5. Check and hand off

Flip through every variant yourself with `$verify` before showing the user: every variant renders, every interaction responds, the console is clean, and there's a screenshot of each. In a T3 thread, open the harness for the user with `preview_open` (web) or `device_open` (simulator or emulator).

Then present the set and stop, because the choice belongs to the user:

| # | Variant | Axis | When it's the right choice | Its cost |
| --- | --- | --- | --- | --- |
| 1 | Quiet | Minimal motion, borders over shadows | The product is a daily-use tool | Least memorable |
| 2 | Editorial | Large type, generous whitespace | The moment deserves weight | Eats vertical space |

Close with where the harness runs (URL, deep link, or file path) and how to flip. Don't pre-pick a favorite in the table. If the user asks which you'd choose, give a reason rooted in the product's personality and how often the piece is seen, not aesthetics alone. If two variants converged while you built them, cut one and say so.

## 6. Promote

| User says | Do |
| --- | --- |
| `keep <variant>` | Integrate it where it belongs using the project's conventions, delete the prototype surface, then `$verify` the integrated version |
| `keep <variant>, leave the picker` | Integrate it and keep the prototype surface |
| `riff <variant>` | Keep the harness and run step 3 again, diverging around that variant's direction |
| `<description> x5` | Start over with that many variants, capped at 5 |

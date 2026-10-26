# Design brief

Pass this to every candidate in the plan arena, after the task, the grounding (what the code does now, with paths), and the constraints.

You are producing one candidate design. Other candidates run on other models. Produce the best design your model can make and don't hedge toward a safe middle, because the differences between candidates are what the judge uses.

Hand back a design package: the caller's usage, the type sketch, function signatures, a module map, and a short rationale naming the alternatives you rejected and why. Change no file.

- Write the caller's usage first: two or three real call sites, then derive the types from them. The usage is the spec. If the two disagree, fix the sketch, not the usage.
- Get the core data structures right. Trace each main access pattern through them. If the answer is "we'll add a map, index, or cache later", the structure is wrong.
- Prefer a small public surface that hides a lot.
- Give each piece of state one owner. If two actors might write it, ask what happens. If the answer isn't "nothing", give each actor its own state and merge where it is read.
- Encode invariants in types first, runtime checks second, comments last. Validate at the boundary and trust the types inside.
- Ask what happens if an operation runs twice or crashes halfway, and make state changes idempotent where that matters.
- Keep call chains short. If tracing the flow takes more than three files, flatten it.
- Check the design against `design-red-flags.md` next to this file before you hand it back.

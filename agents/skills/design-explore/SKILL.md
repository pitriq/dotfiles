---
name: design-explore
description: "Explore UI design directions for a specific problem by pulling Mobbin references from Cosign's high taste companies, then propose alternatives and pick the strongest patterns. TRIGGER ONLY when the user explicitly invokes `/design-explore` or asks for design-explore. Do not trigger for ordinary UI implementation, styling fixes, or design reviews."
---

# Design Explore

The user calls this with a context prompt, e.g. `/design-explore a better way of organizing this card's header`. Find how high-taste companies solve the same problem, turn that into a few distinct directions for the user's app, and recommend one.

Requires the Mobbin MCP (`search_screens`, `search_flows`, `search_sections`). If those tools are unavailable, say so and stop.

## 1. Understand the problem

Before searching, build a short brief from the prompt and the codebase:

- **Element**: the exact component or screen ("this card" means find it: open files, recent diff, or the file the user is working in). Read its code and note what it currently shows and in what order.
- **Job**: what the user of the app needs from this element (scan, compare, act, navigate).
- **Content**: the real data it holds (titles, metadata, status, avatars, actions) and which items matter most.
- **Product**: what the app is and its domain, from README, routes, models, copy.
- **Platform**: `ios` or `web` (SwiftUI/UIKit/React Native/Flutter → ios; web frameworks → web). Use both only for cross-platform apps.
- **Constraints**: design system, tokens, component library, density, existing conventions the result must fit.

If a screenshot or running app is available (`$serve-sim`, `$agent-browser`), look at the current state. Ask the user only if the element itself cannot be identified; infer everything else.

## 2. Pick companies

Fetch the current list from https://cosign.co/questions/highest-taste-companies on every run, asking for every company name with its rank. If the fetch fails or returns no companies, say so and stop; do not fall back to a remembered list.

Pick 4 to 7 companies:

- Most should share the product's domain or have a product with the same element (a dense list card → Linear, Attio; a balance header → Mercury, Revolut).
- Include 1 or 2 from outside the domain known for strong craft on this kind of element, for contrast.
- Prefer companies with apps on the user's platform. Studios, hardware, and robotics companies usually have only marketing sites, which suit `search_sections` but rarely app UI.
- Skip companies whose product you cannot identify, unless a Mobbin search by name shows it is the right company and relevant.

State each pick with a one-line reason.

## 3. Search

Run the searches in parallel. Use the same `task_intent` and `output_destination: "code"` on every call.

- `search_screens` once per company, with the company name in the query plus a concrete description of the element: "Linear issue list row with status, priority, and assignee". Use `mode: "deep"` and `limit` around 6 to 10.
- One or two unfiltered `search_screens` queries describing the element alone. Keep only results from listed companies; note strong outliers from other apps separately and label them as off-list.
- `search_flows` when the problem spans several steps (onboarding, creation, checkout). `search_sections` for marketing or landing page work.

If an app-filtered search returns other apps, the company is not on Mobbin for that platform. Swap in another pick rather than forcing it. If results are thin, rephrase around the content rather than the component name ("header showing project name, members, and due date" instead of "card header").

Look at the returned images. Describe what the screens show, never what the metadata suggests.

## 4. Extract patterns

Group references by pattern, not by company. For each pattern: what it does structurally (hierarchy, grouping, alignment, density, how actions and metadata are placed), which references use it as `[App: screen](mobbin_url)` links, and why it works for that product. Discard patterns that do not fit the user's content or constraints, and say why in one line.

## 5. Propose alternatives

Write 3 to 5 directions that differ in structure, not just styling. For each:

- Name and one-sentence idea.
- How it maps onto the user's actual content, with an ASCII wireframe of the element using real field names.
- References it draws from (links).
- Tradeoffs: what it improves and what it costs (scan speed, density, discoverability, implementation surface area in the current codebase).

## 6. Recommend

Pick one direction, or a combination with clear boundaries, and justify it against the brief from step 1. List the specific moves to borrow (e.g. "status as a leading glyph, not a trailing pill") and anything to avoid. Point to the files and components that would change.

Stop after the recommendation. Implement only if the user asks.

## Output

Write in chat, in this order: brief (a few lines), companies picked, patterns, alternatives, recommendation. Cite every reference with its `mobbin_url`; never link `image_url`, which expires. If a Mobbin result includes `ai_usage_notice`, show its `text` verbatim as its own block after the references.

---
name: fact-check
description: Cross-check the previous answer against codebase context, web sources, and official docs. Actively tries to disprove every verifiable claim.
---

# Fact-Check

Re-examine your most recent response and actively try to disprove every verifiable claim in it. Your goal is to catch hallucinations, subtle inaccuracies, and plausible-sounding mistakes before they cause harm.

## Determining the Scope

Parse the user's request to determine what to check:

| User says | Scope |
|-----------|-------|
| `/fact-check` (no args) | The immediately preceding answer |
| `/fact-check <topic>` | A specific claim or topic from the conversation |

## Process

1. **Extract claims** — Go through the response and pull out every factual assertion: API behaviors, library features, language semantics, config options, CLI flags, version-specific behavior, file paths, command syntax, etc. Ignore opinions, suggestions, and hedged statements.

2. **Cross-check against local context** — Read relevant files in the codebase to verify claims about the project:
   - READMEs, docs, and config files
   - Lock files and dependency manifests for version claims
   - Source code for claims about how things work in this project
   - Git history if claims reference when something changed

3. **Cross-check against the web** — For each non-trivial claim, use `WebSearch` and `WebFetch` to check primary sources. Prioritize in this order:
   - Official documentation
   - GitHub repos, changelogs, and release notes
   - GitHub issues and discussions
   - Reputable technical references
   - Blog posts and Stack Overflow (treat as secondary)

4. **Flag hallucination patterns** — Pay special attention to these common failure modes:
   - API methods, options, or parameters that sound plausible but don't exist
   - CLI flags or config keys that are close to real ones but subtly wrong
   - Version numbers or "available since version X" claims
   - Behavioral descriptions that mix up similar tools or libraries
   - Defaults or behaviors that changed between versions
   - URLs that look right but point nowhere

5. **Verify code snippets** — If the previous answer included code:
   - Check that imports/modules exist
   - Confirm function signatures match official docs
   - Validate syntax for the claimed language/framework version
   - Look for deprecated APIs being used as if current

## Output

Structure your response as:

### Confidence: [HIGH | MEDIUM | LOW]

**Verified:**
- [Claim] — confirmed via [source/file]

**Incorrect:**
- [Claim] — actually [correction]. Source: [link or file path]

**Unverifiable:**
- [Claim] — could not confirm or deny with available sources

**Not checked:**
- [Claim] — opinion, suggestion, or not a factual assertion

---

Be thorough and adversarial. The whole point is to catch mistakes. If everything checks out, say so — but don't rubber-stamp claims you couldn't actually verify. When in doubt, mark it unverifiable rather than verified.

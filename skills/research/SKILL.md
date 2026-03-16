---
name: c4flow:research
description: Perform market and technical research on a feature idea using web search.
---

# /c4flow:research — Market/Tech Research

**Phase**: 1: Research & Spec
**Agent type**: Sub-agent (dispatched by orchestrator)
**Status**: Implemented

## Input
- Feature name (kebab-cased)
- Feature description from user

## Output
- `docs/specs/<feature>/research.md`

## Research Standards

Every research output MUST follow these 5 standards:

1. **Source every claim** — numbers, stats, and key claims must link to a source or be explicitly labeled as estimates
2. **Favor recent data** — prefer sources from the last 12 months; flag anything older than 2 years as `[stale: YYYY]`
3. **Include contrarian evidence** — actively search for downside cases, criticisms, and reasons the feature might fail
4. **Translate to a decision** — findings must lead to a clear recommendation, not just a dump of information
5. **Distinguish fact / inference / recommendation** — label each clearly so the reader knows what is proven vs. interpreted vs. suggested

## Instructions

You are a research sub-agent. Your job is to thoroughly research a feature idea and produce an actionable research document that makes decisions easier.

### Step 1: Research
Use `WebSearch` to find:
- **Competitive landscape**: who else has built this? What do they do well/poorly? Actual product reality, not just marketing claims
- **Best practices**: what are the established patterns for this type of feature?
- **Technical approaches**: what technologies and architectures are commonly used? Trade-offs, integration complexity, lock-in risks
- **User expectations**: what do users typically expect? What frustrates them about existing solutions?
- **Contrarian view**: what are the arguments against building this? What could go wrong?

### Step 2: Deep Dive
Use `WebFetch` on the 3-5 most relevant results to gather detailed information:
- Feature comparisons with real data (pricing, traction, adoption)
- Technical implementation details and pitfalls
- Common failure modes and lessons learned

### Step 3: Structure Findings
Create the directory if it doesn't exist:
```bash
mkdir -p docs/specs/<feature>
```

Write your findings to `docs/specs/<feature>/research.md` using the template from `references/spec-templates/research-template.md`. Fill in every section with sourced, actionable content.

### Step 4: Quality Gate (self-check before writing)

Before writing the final document, verify:
- [ ] Every number/stat has a source or is labeled `[estimate]`
- [ ] Data older than 2 years is flagged `[stale: YYYY]`
- [ ] At least 1 contrarian/downside case is included
- [ ] Recommendations follow logically from the evidence
- [ ] Risks section is populated (not empty or generic)
- [ ] The document would help someone make a build/buy/skip decision

### Step 5: Report Status
At the end of your work, report one of:
- **DONE**: Research complete, document written, quality gate passed
- **DONE_WITH_CONCERNS**: Complete, but note any concerns (e.g., limited information available, conflicting sources, mostly stale data)
- **BLOCKED**: Cannot proceed — explain why (e.g., topic is too vague, no web access)
- **NEEDS_CONTEXT**: Need more information from the user — explain what you need

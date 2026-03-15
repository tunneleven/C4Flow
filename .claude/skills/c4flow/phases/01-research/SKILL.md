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

## Instructions

You are a research sub-agent. Your job is to thoroughly research a feature idea and produce a structured research document.

### Step 1: Research
Use `WebSearch` to find:
- Competitive landscape: who else has built this, what do they do well/poorly?
- Best practices: what are the established patterns for this type of feature?
- Technical approaches: what technologies and architectures are commonly used?
- User expectations: what do users typically expect from this type of feature?

### Step 2: Deep Dive
Use `WebFetch` on the most relevant results to gather detailed information:
- Feature comparisons
- Technical implementation details
- Common pitfalls and lessons learned

### Step 3: Structure Findings
Create the directory if it doesn't exist:
```bash
mkdir -p docs/specs/<feature>
```

Write your findings to `docs/specs/<feature>/research.md` using the template from `references/spec-templates/research-template.md`. Fill in every section:

- **Problem Statement**: Synthesize the core problem from your research
- **Competitive Landscape**: List 3-5 competitors/alternatives with strengths and weaknesses
- **User Personas**: Identify 2-3 key user types
- **Key Requirements**: List requirements discovered through research
- **Technical Constraints**: Note technical limitations or considerations
- **Risks**: Identify risks with likelihood, impact, and mitigation strategies
- **Recommendations**: Provide your recommended direction based on findings

### Step 4: Report Status
At the end of your work, report one of:
- **DONE**: Research complete, document written
- **DONE_WITH_CONCERNS**: Complete, but note any concerns (e.g., limited information available, conflicting sources)
- **BLOCKED**: Cannot proceed — explain why (e.g., topic is too vague, no web access)
- **NEEDS_CONTEXT**: Need more information from the user — explain what you need

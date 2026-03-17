# Beads DoltHub Viewer Design

**Date:** 2026-03-17
**Status:** Draft

## Goal

Build a frontend-only website that lets a user view a public beads-backed DoltHub repository as a task tree. The app links users to DoltHub documentation, accepts a repo in either `owner/repo` or full URL form, remembers the last repo in `localStorage`, and lets the user switch between two structural views of the same task data.

## Scope

### In Scope

- Public DoltHub repositories only
- Read-only task visualization
- Repo input that accepts both full DoltHub URLs and `owner/repo`
- Persistence of the last opened repo in `localStorage`
- Repo switching from the UI
- Two presentation modes:
  - `dependency`: render actual dependency roots and descendants
  - `grouped`: render tasks grouped by parent/epic first
- Rich task nodes that show full metadata directly in the tree
- Clear loading, empty, and error states

### Out of Scope

- Private repo access
- Authentication or token management
- Editing tasks, dependencies, assignees, or repo metadata
- Backend proxying, caching, or server-side normalization
- Multi-repo saved lists beyond the single most recently used repo

## Product Behavior

### Entry Flow

1. User opens the site.
2. If a previously used repo is present in `localStorage`, the app restores it and immediately loads that repo.
3. Otherwise, the user enters either:
   - `owner/repo`
   - a full DoltHub repo URL
4. The app normalizes the input to a canonical `owner/repo` form before fetching data.
5. The user can replace the current repo at any time to switch context.

### Primary UI

The page has three clear responsibilities:

- A lightweight header for repo selection and navigation
- A status strip that summarizes the current dataset
- A main content region that renders the task tree

The header contains:

- Repo input
- `Load` action
- Current repo identity
- View-mode toggle: `Dependency` / `Grouped`
- Link to `https://docs.dolthub.com/`
- Badge or helper text indicating that only public repos are supported

The status strip contains:

- Loading or refresh state
- Total task count
- Unique assignee count if available
- Total dependency count
- Parse or data warnings when the repo is reachable but incomplete

The main region shows:

- A multi-root tree in `dependency` mode
- Group sections with nested task trees in `grouped` mode

## Data Model

### RepoConfig

- `rawInput`: exactly what the user typed
- `canonicalRepo`: normalized `owner/repo`
- `sourceUrl`: resolved public DoltHub URL used for fetches

### TaskNode

- `id`
- `title`
- `status`
- `priority`
- `type`
- `assignee`
- `description`
- `parentId`
- `groupId`
- `groupLabel`
- `dependsOnIds`
- `blocksCount`
- `children`
- `raw`: raw source record preserved for diagnostics

### View Models

The fetch layer must not feed raw DoltHub responses directly into components. The app should derive:

- `DependencyTree`
  - Multiple roots allowed
  - Missing dependency targets recorded as warnings, not fatal errors
- `GroupedTree`
  - Tasks first partitioned by deterministic grouping rules
  - Each section may still render nested children and dependency indicators

## Architecture

This app should stay client-only, but the data path must still be split into clear units so planning and testing stay manageable.

### Unit 1: RepoResolver

Responsibility:
- Accept raw user input
- Validate supported formats
- Normalize to canonical `owner/repo`
- Produce a user-facing validation error when normalization fails

Interface:
- Input: raw string
- Output: `RepoConfig` or a validation error

### Unit 2: DoltHubClient

Responsibility:
- Fetch public repo data from DoltHub
- Hide endpoint details from the rest of the app
- Return raw payloads plus transport-level error details
- Encapsulate the assumption that the chosen public DoltHub surface is callable directly from the browser in this version

Interface:
- Input: canonical repo identity
- Output: raw remote data or fetch error

Contract for this version:
- Use DoltHub's public SQL read API on the default branch: `GET https://www.dolthub.com/api/v1alpha1/{owner}/{database}?q=...`
- Expect JSON responses that include at minimum:
  - `query_execution_status`
  - `query_execution_message`
  - `repository_owner`
  - `repository_name`
  - `commit_ref`
  - `schema`
  - `rows`
- The browser-only implementation assumes this endpoint remains callable cross-origin for local and deployed frontend origins. This assumption was validated during design on 2026-03-17 with an `OPTIONS` probe that returned `Access-Control-Allow-Origin` for a localhost origin, but it still remains an external dependency risk.

### Unit 3: BeadsAdapter

Responsibility:
- Interpret raw remote data as beads task records
- Map fields into `TaskNode`
- Detect unsupported or incomplete schema cases

Interface:
- Input: raw DoltHub payloads
- Output: normalized task collection plus non-fatal warnings

### Unit 4: TreeBuilder

Responsibility:
- Build the dependency-oriented view model
- Build the grouped view model
- Preserve stable node identities for UI rendering

Interface:
- Input: normalized `TaskNode[]`
- Output: `DependencyTree`, `GroupedTree`, aggregate counters, warnings

### Unit 5: Viewer UI

Responsibility:
- Render repo controls, summary state, tree content, and error states
- Allow repo switching
- Allow mode switching between dependency and grouped views
- Persist the latest valid repo to `localStorage`

Interface:
- Input: view models and state flags
- Output: rendered interactive UI

## Tree Rendering

Each task node is metadata-rich by default. The node should render:

- Title
- Task ID
- Status
- Assignee
- Priority
- Type
- Dependency counts or explicit dependency labels
- Description content, with long text truncated but expandable inline

Because the user explicitly wants dense nodes, the design must control clutter through layout, not by hiding key fields. The default collapsed form should still show the full requested metadata set in a compact card. Long descriptions and large raw detail blocks can expand on demand.

`raw` metadata is for adapter diagnostics and developer tooling, not for the default end-user UI. If surfaced at all, it should be behind an explicit debug-oriented disclosure, not part of the primary task card.

## Grouping Rules

The grouped view must use deterministic section assignment so planning and testing do not depend on guesswork.

Grouping precedence:

1. If a task has `groupId`, place it in that group.
2. Otherwise, if a task has `parentId`, place it under the parent task's section.
3. Otherwise, place it in an `Ungrouped` section.

For this spec, an "epic" is any source grouping concept that the adapter normalizes into `groupId`. The UI does not need to distinguish whether the source called it an epic, parent bucket, or another grouping label once normalization is complete.

Tasks with both `groupId` and `parentId` use `groupId` for top-level section placement and may still appear as nested children inside that section.

Section title rules:

- If the source data exposes a human-readable grouping name, normalize it into `groupLabel` and use that for the section header.
- Otherwise, if the group maps to another task, use the resolved parent task title.
- Otherwise, fall back to the stable identifier value (`groupId` or `parentId`).
- Tasks with neither value render under the literal section title `Ungrouped`.

## Dependency Graph Rules

The fetched dependency data may be a graph rather than a strict tree. The viewer must convert that graph into a tree-friendly presentation without pretending the underlying structure is simpler than it is.

Rules:

- The dependency view may have multiple roots.
- If a task is referenced by multiple upstream tasks, the UI renders one full canonical card at its first discovered placement and renders subsequent appearances as lightweight reference nodes that link back to the canonical card. The viewer must not duplicate full task cards for the same task ID.
- If the adapter detects a cycle, the app must not recurse indefinitely. It should render the involved nodes up to the point of cycle detection and show a cycle warning on the repeated edge or node.
- Missing dependency targets remain non-fatal warnings.

This keeps the product scoped to a tree viewer while acknowledging that the source data can be DAG-shaped or cyclic.

## External Integration Assumption

This version assumes there is at least one public DoltHub data surface that:

- exposes the beads-backed task data needed by the viewer
- is reachable directly from the browser
- allows the required cross-origin requests for a frontend-only app

The planned fetch sequence is:

1. Run a SQL discovery query such as `SHOW TABLES` against the public SQL API.
2. Use `BeadsAdapter` to determine which beads-owned table or view names contain task, assignee, and dependency data in the target repo.
3. Run read-only SQL queries against those discovered tables/views.
4. Normalize the returned `rows` into `TaskNode` records and relationship edges.

The minimum source capability required from a target beads repo is enough readable table/view data to derive:

- task identity and title
- status
- type and priority if present
- assignee reference or assignee display value if present
- description/body if present
- grouping references
- dependency references

If that assumption proves false during implementation, the plan must stop and surface the issue rather than silently broadening scope into a backend solution. Backend proxying remains explicitly out of scope for this spec.

## Error Handling

### Invalid Input

If the repo input is neither a recognizable DoltHub URL nor `owner/repo`, the app shows a format-specific validation message and does not attempt a fetch.

### Unreachable or Unsupported Repo

If the repo cannot be fetched, the app shows a fetch failure state. If the repo is reachable but not public, the error message should explicitly say that only public repos are supported in this version.

### Non-Beads or Unexpected Schema

If the repo is valid but the expected beads task data cannot be interpreted, the app should show:

- that the repo was reached successfully
- that parsing the expected beads schema failed
- any field-level warning that helps explain the mismatch

### Incomplete Dependency Graph

If a task references a dependency target that is missing from the fetched dataset, the node still renders. The missing edge is represented as a warning so one bad reference does not collapse the whole tree.

### Empty States

If the repo contains no parseable tasks, the app should distinguish between:

- no tasks found
- parse failed
- fetch still loading

## Local Persistence

`localStorage` stores only the most recently opened valid repo identity and enough metadata to restore it on the next visit. Failed or invalid inputs should not overwrite the last known good repo.

Restore rules:

- If persisted data is malformed or cannot be parsed, the app clears that saved value, starts in an empty input state, and shows a non-blocking restore warning.
- If the persisted repo key is valid but the repo now fails to load, the app keeps the repo value visible in the input, shows the fetch error, and does not silently delete the saved repo until the user successfully loads a different valid repo.

## Testing Strategy

### Unit Tests

- Repo input normalization from both supported formats
- Rejection of invalid repo inputs
- Mapping from raw DoltHub payloads into normalized task records
- Dependency tree construction, including multi-root cases
- Grouped tree construction
- Warning generation for missing dependency targets and parse mismatches

### Component Tests

- Initial load from `localStorage`
- Repo switching flow
- View-mode toggle
- Rich node rendering with full metadata
- Error, empty, and loading states

### Deferred Testing

End-to-end browser automation is not required for the first implementation plan. The design should leave room to add it later without restructuring the app.

## Constraints and Assumptions

- The first implementation targets public DoltHub repos only.
- The site is read-only.
- The app persists only one repo locally.
- The same fetched dataset drives both tree modes.
- The exact DoltHub/beads remote shape may evolve, so endpoint-specific assumptions should remain inside `DoltHubClient` and `BeadsAdapter`, never inside presentation components.

## Planning Boundary

This spec covers one coherent deliverable: a public-repo, frontend-only beads task viewer. It does not include auth, mutation flows, collaboration features, or backend services, so it is scoped tightly enough for a single implementation plan.

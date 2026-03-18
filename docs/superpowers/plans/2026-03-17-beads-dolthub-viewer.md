# Beads DoltHub Viewer Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a frontend-only React app that reads a public beads-backed DoltHub repo and renders dependency and grouped task trees with last-repo persistence.

**Architecture:** Add a self-contained frontend app in `apps/beads-viewer/` using Vite, React, and TypeScript. Keep the data path split into `RepoResolver`, `DoltHubClient`, `BeadsAdapter`, and `TreeBuilder`, then render those view models through focused UI components and a single orchestration hook.

**Tech Stack:** Vite, React, TypeScript, Vitest, React Testing Library, jsdom, fetch API, localStorage.

**Spec:** `docs/superpowers/specs/2026-03-17-beads-dolthub-viewer-design.md`

---

## File Structure

### Planned app root

- Create: `apps/beads-viewer/package.json` — app scripts and dependencies
- Create: `apps/beads-viewer/tsconfig.json` — TypeScript config for the app
- Create: `apps/beads-viewer/tsconfig.node.json` — Vite config compilation support
- Create: `apps/beads-viewer/vite.config.ts` — Vite dev/build config
- Create: `apps/beads-viewer/vitest.config.ts` — Vitest config with jsdom
- Create: `apps/beads-viewer/index.html` — Vite HTML entry

### Planned application files

- Create: `apps/beads-viewer/src/main.tsx` — React bootstrap
- Create: `apps/beads-viewer/src/app/App.tsx` — top-level app composition
- Create: `apps/beads-viewer/src/app/App.css` — app styling and tree layout
- Create: `apps/beads-viewer/src/app/types.ts` — shared app-level UI state types
- Create: `apps/beads-viewer/src/app/App.test.tsx` — app integration and smoke tests

### Planned domain files

- Create: `apps/beads-viewer/src/domain/repo/normalizeRepoInput.ts` — normalize `owner/repo` and supported DoltHub URLs
- Create: `apps/beads-viewer/src/domain/beads/types.ts` — `RepoConfig`, `TaskRecord`, tree node, warning, and fetch result types
- Create: `apps/beads-viewer/src/domain/beads/doltHubClient.ts` — fixed SQL query orchestration against the public DoltHub SQL API
- Create: `apps/beads-viewer/src/domain/beads/beadsAdapter.ts` — parse issues/dependencies rows into normalized records plus warnings
- Create: `apps/beads-viewer/src/domain/beads/treeBuilder.ts` — dependency and grouped tree construction

### Planned persistence and orchestration files

- Create: `apps/beads-viewer/src/storage/lastRepoStorage.ts` — read/write last valid repo from `localStorage`
- Create: `apps/beads-viewer/src/hooks/useRepoData.ts` — load lifecycle, error mapping, and view-model assembly

### Planned UI component files

- Create: `apps/beads-viewer/src/components/RepoForm.tsx` — repo input and load action
- Create: `apps/beads-viewer/src/components/ViewModeToggle.tsx` — dependency/grouped toggle
- Create: `apps/beads-viewer/src/components/SummaryBar.tsx` — deterministic counts and warning summary
- Create: `apps/beads-viewer/src/components/TaskCard.tsx` — rich task node card
- Create: `apps/beads-viewer/src/components/ReferenceNode.tsx` — repeated dependency target marker
- Create: `apps/beads-viewer/src/components/DependencyTree.tsx` — blocker-to-blocked tree rendering
- Create: `apps/beads-viewer/src/components/GroupedTree.tsx` — grouped-section rendering with parent nesting
- Create: `apps/beads-viewer/src/components/StatusPanel.tsx` — loading, error, and empty states

### Planned tests

- Create: `apps/beads-viewer/src/test/setup.ts` — RTL/Vitest setup
- Create: `apps/beads-viewer/src/domain/repo/normalizeRepoInput.test.ts`
- Create: `apps/beads-viewer/src/domain/beads/beadsAdapter.test.ts`
- Create: `apps/beads-viewer/src/domain/beads/doltHubClient.test.ts`
- Create: `apps/beads-viewer/src/domain/beads/treeBuilder.test.ts`
- Create: `apps/beads-viewer/src/storage/lastRepoStorage.test.ts`
- Create: `apps/beads-viewer/src/hooks/useRepoData.test.tsx`
- Create: `apps/beads-viewer/src/app/App.test.tsx`

### Repo housekeeping

- Modify: `.gitignore` — ignore `apps/beads-viewer/node_modules`, `apps/beads-viewer/dist`, and coverage output if generated locally

## Chunk 1: App Scaffold And Repo Input

### Task 1: Bootstrap the frontend workspace

**Files:**
- Create: `apps/beads-viewer/package.json`
- Create: `apps/beads-viewer/tsconfig.json`
- Create: `apps/beads-viewer/tsconfig.node.json`
- Create: `apps/beads-viewer/vite.config.ts`
- Create: `apps/beads-viewer/vitest.config.ts`
- Create: `apps/beads-viewer/index.html`
- Create: `apps/beads-viewer/src/main.tsx`
- Create: `apps/beads-viewer/src/app/App.tsx`
- Create: `apps/beads-viewer/src/app/App.css`
- Create: `apps/beads-viewer/src/app/App.test.tsx`
- Create: `apps/beads-viewer/src/app/types.ts`
- Create: `apps/beads-viewer/src/test/setup.ts`
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing app smoke test**

```tsx
import { render, screen } from "@testing-library/react";
import { App } from "./App";

it("renders the viewer shell", () => {
  render(<App />);
  expect(screen.getByRole("heading", { name: /beads dolthub viewer/i })).toBeInTheDocument();
  expect(screen.getByRole("button", { name: /load/i })).toBeDisabled();
});
```

- [ ] **Step 2: Run the smoke test to verify the app does not exist yet**

Run: `cd apps/beads-viewer && npm test -- App.test.tsx`
Expected: FAIL because the app workspace and test file do not exist yet.

- [ ] **Step 3: Create the Vite/React/Vitest app skeleton**

Add `package.json` scripts:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

Install runtime deps: `react`, `react-dom`
Install dev deps: `typescript`, `vite`, `vitest`, `jsdom`, `@testing-library/react`, `@testing-library/jest-dom`, `@vitejs/plugin-react`

Minimum config expectations:
- `vite.config.ts` uses `@vitejs/plugin-react()`
- `vitest.config.ts` sets `environment: "jsdom"` and `setupFiles: ["./src/test/setup.ts"]`
- `main.tsx` mounts `<App />` into `#root`

- [ ] **Step 4: Implement the minimal shell to satisfy the smoke test**

`App.tsx` should render:

```tsx
export function App() {
  return (
    <main>
      <h1>Beads DoltHub Viewer</h1>
      <form>
        <input aria-label="Repository" />
        <button disabled type="submit">
          Load
        </button>
      </form>
    </main>
  );
}
```

This scaffold is intentionally partial. It only establishes the testable app shell and does not yet satisfy the final spec-level header, status strip, or tree UI requirements.

- [ ] **Step 5: Add test setup and ignore rules**

Add `src/test/setup.ts`:

```ts
import "@testing-library/jest-dom";
```

Extend `.gitignore` with:

```gitignore
apps/beads-viewer/node_modules/
apps/beads-viewer/dist/
apps/beads-viewer/coverage/
```

- [ ] **Step 6: Run the smoke test to verify it passes**

Run: `cd apps/beads-viewer && npm test -- App.test.tsx`
Expected: PASS with 1 passing test.

- [ ] **Step 7: Commit**

```bash
git add .gitignore apps/beads-viewer
git commit -m "feat: scaffold beads DoltHub viewer app"
```

### Task 2: Implement repo normalization and persistence primitives

**Files:**
- Create: `apps/beads-viewer/src/domain/repo/normalizeRepoInput.ts`
- Create: `apps/beads-viewer/src/domain/repo/normalizeRepoInput.test.ts`
- Create: `apps/beads-viewer/src/storage/lastRepoStorage.ts`
- Create: `apps/beads-viewer/src/storage/lastRepoStorage.test.ts`
- Modify: `apps/beads-viewer/src/app/types.ts`

- [ ] **Step 1: Write failing normalization tests**

```ts
import { describe, expect, it } from "vitest";
import { normalizeRepoInput } from "./normalizeRepoInput";

describe("normalizeRepoInput", () => {
  it("accepts owner/repo", () => {
    expect(normalizeRepoInput("vanhiep99w/test").canonicalRepo).toBe("vanhiep99w/test");
  });

  it("accepts supported repository URLs", () => {
    expect(
      normalizeRepoInput("https://www.dolthub.com/repositories/vanhiep99w/test/?tab=tables#readme")
        .canonicalRepo,
    ).toBe("vanhiep99w/test");
  });

  it("rejects branch URLs", () => {
    expect(() =>
      normalizeRepoInput("https://www.dolthub.com/repositories/vanhiep99w/test/main"),
    ).toThrow(/unsupported repository url/i);
  });

  it("rejects extra path segments and non-DoltHub URLs", () => {
    expect(() =>
      normalizeRepoInput("https://www.dolthub.com/repositories/vanhiep99w/test/pulls"),
    ).toThrow(/unsupported repository url/i);
    expect(() => normalizeRepoInput("https://example.com/vanhiep99w/test")).toThrow(
      /unsupported repository url/i,
    );
  });

  it("rejects empty input", () => {
    expect(() => normalizeRepoInput("   ")).toThrow(/repository is required/i);
  });
});
```

- [ ] **Step 2: Write failing localStorage tests**

```ts
it("restores the last valid repo", () => {
  window.localStorage.setItem(
    "beads-viewer:last-repo",
    JSON.stringify({
      rawInput: "vanhiep99w/test",
      canonicalRepo: "vanhiep99w/test",
      sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test",
    }),
  );
  expect(readLastRepo().repo?.canonicalRepo).toBe("vanhiep99w/test");
  expect(readLastRepo().warning).toBeNull();
});

it("writes the full repo config", () => {
  writeLastRepo({
    rawInput: "vanhiep99w/test",
    canonicalRepo: "vanhiep99w/test",
    sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test",
  });

  expect(JSON.parse(window.localStorage.getItem("beads-viewer:last-repo")!)).toEqual({
    rawInput: "vanhiep99w/test",
    canonicalRepo: "vanhiep99w/test",
    sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test",
  });
});

it("clears saved state explicitly", () => {
  window.localStorage.setItem(
    "beads-viewer:last-repo",
    JSON.stringify({
      rawInput: "vanhiep99w/test",
      canonicalRepo: "vanhiep99w/test",
      sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test",
    }),
  );

  clearLastRepo();
  expect(window.localStorage.getItem("beads-viewer:last-repo")).toBeNull();
});

it("clears malformed saved state", () => {
  window.localStorage.setItem("beads-viewer:last-repo", "{bad json");
  expect(readLastRepo().repo).toBeNull();
  expect(readLastRepo().warning).toBe("restore_invalid_state");
  expect(window.localStorage.getItem("beads-viewer:last-repo")).toBeNull();
});

it("clears parseable but invalid saved state", () => {
  window.localStorage.setItem(
    "beads-viewer:last-repo",
    JSON.stringify({ canonicalRepo: "vanhiep99w/test" }),
  );
  expect(readLastRepo().repo).toBeNull();
  expect(readLastRepo().warning).toBe("restore_invalid_state");
  expect(window.localStorage.getItem("beads-viewer:last-repo")).toBeNull();
});

it("does not overwrite the last known good repo when invalid input is rejected", () => {
  writeLastRepo({
    rawInput: "vanhiep99w/test",
    canonicalRepo: "vanhiep99w/test",
    sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test",
  });

  expect(() => normalizeRepoInput("   ")).toThrow();
  expect(readLastRepo().repo?.canonicalRepo).toBe("vanhiep99w/test");
  expect(readLastRepo().warning).toBeNull();
});
```

- [ ] **Step 3: Run the targeted tests and verify they fail**

Run: `cd apps/beads-viewer && npm test -- normalizeRepoInput.test.ts lastRepoStorage.test.ts`
Expected: FAIL because the new modules do not exist yet.

- [ ] **Step 4: Implement normalization and storage minimally**

`normalizeRepoInput.ts` should:
- preserve exactly what the user typed in `rawInput`
- trim only for validation and canonicalization
- accept exactly `owner/repo`
- accept only `https://www.dolthub.com/repositories/<owner>/<repo>` with optional trailing slash, query, or fragment
- reject branch/path variants
- return:

```ts
{
  rawInput,
  canonicalRepo: `${owner}/${repo}`,
  sourceUrl: `https://www.dolthub.com/repositories/${owner}/${repo}`,
}
```

`lastRepoStorage.ts` should export `readLastRepo`, `writeLastRepo`, and `clearLastRepo`.

Persisted storage shape for v1 is the full `RepoConfig` object:

```ts
{
  rawInput: "vanhiep99w/test",
  canonicalRepo: "vanhiep99w/test",
  sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test"
}
```

Any parseable object missing one of those three string fields should be treated as malformed, cleared, and reported as restore-invalid state.

Define the restore warning contract in `src/app/types.ts` now:

```ts
export type RestoreWarning = "restore_invalid_state" | null;
```

`readLastRepo` should return both the restored repo and warning state:

```ts
{
  repo: RepoConfig | null;
  warning: RestoreWarning;
}
```

- [ ] **Step 5: Run the targeted tests to verify they pass**

Run: `cd apps/beads-viewer && npm test -- normalizeRepoInput.test.ts lastRepoStorage.test.ts`
Expected: PASS with assertions covering valid URLs, invalid inputs, write/clear behavior, malformed storage, invalid storage shape, and last-known-good preservation.

- [ ] **Step 6: Commit**

```bash
git add apps/beads-viewer/src/domain/repo apps/beads-viewer/src/storage apps/beads-viewer/src/app/types.ts
git commit -m "feat: add repo normalization and local persistence"
```

## Chunk 2: DoltHub Fetching And Beads Parsing

### Task 3: Implement the fixed-query DoltHub client

**Files:**
- Create: `apps/beads-viewer/src/domain/beads/types.ts`
- Create: `apps/beads-viewer/src/domain/beads/doltHubClient.ts`
- Create: `apps/beads-viewer/src/domain/beads/doltHubClient.test.ts`

- [ ] **Step 1: Write the failing DoltHub client test**

```ts
import { vi, expect, it } from "vitest";
import { fetchRepoData } from "./doltHubClient";

it("runs the fixed DoltHub SQL query sequence", async () => {
  const fetchMock = vi.fn()
    .mockResolvedValueOnce(new Response(JSON.stringify({ query_execution_status: "Success", rows: [{ Tables_in_test: "issues" }, { Tables_in_test: "dependencies" }] })))
    .mockResolvedValueOnce(new Response(JSON.stringify({ query_execution_status: "Success", rows: [] })))
    .mockResolvedValueOnce(new Response(JSON.stringify({ query_execution_status: "Success", rows: [] })));

  const result = await fetchRepoData("vanhiep99w/test", fetchMock);

  expect(fetchMock).toHaveBeenCalledTimes(3);
  expect(result.kind).toBe("success");
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd apps/beads-viewer && npm test -- doltHubClient`
Expected: FAIL because the client and shared types do not exist yet.

- [ ] **Step 3: Implement the minimal DoltHub client**

`doltHubClient.ts` should:
- split `owner/repo`
- call:
  - `SHOW TABLES`
  - `SELECT id, title, description, status, priority, issue_type, assignee, metadata FROM issues`
  - `SELECT issue_id, depends_on_id, type, metadata FROM dependencies`
- classify:
  - network / HTTP / missing response as `fetch_failure`
  - non-success `query_execution_status` as `query_failure`
  - missing `issues` or `dependencies` tables as `unsupported_schema`

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd apps/beads-viewer && npm test -- doltHubClient`
Expected: PASS and confirm the client issues exactly 3 fetches for a supported repo.

- [ ] **Step 5: Commit**

```bash
git add apps/beads-viewer/src/domain/beads/types.ts apps/beads-viewer/src/domain/beads/doltHubClient.ts apps/beads-viewer/src/domain/beads/doltHubClient.test.ts
git commit -m "feat: add DoltHub fixed-query client"
```

### Task 4: Implement the beads adapter

**Files:**
- Create: `apps/beads-viewer/src/domain/beads/beadsAdapter.ts`
- Create: `apps/beads-viewer/src/domain/beads/beadsAdapter.test.ts`
- Modify: `apps/beads-viewer/src/domain/beads/types.ts`

- [ ] **Step 1: Write the failing adapter tests**

```ts
it("maps issues and blocks dependencies into task records", () => {
  const result = adaptRepoData({
    issues: [
      { id: "test-004", title: "Parent", description: "desc", status: "open", priority: 1, issue_type: "task", assignee: "Person C", metadata: "{\"group_id\":\"epic-1\",\"group_label\":\"Epic 1\"}" },
      { id: "test-1e5", title: "Child", description: "desc", status: "open", priority: 1, issue_type: "task", assignee: "", metadata: null },
    ],
    dependencies: [{ issue_id: "test-004", depends_on_id: "test-1e5", type: "blocks", metadata: "{}" }],
  });

  expect(result.records[0].dependsOnIds).toEqual(["test-1e5"]);
  expect(result.records[0].groupLabel).toBe("Epic 1");
});

it("warns and ignores unsupported dependency types", () => {
  const result = adaptRepoData({
    issues: [{ id: "test-004", title: "Parent", description: "", status: "open", priority: 1, issue_type: "task", assignee: "", metadata: null }],
    dependencies: [{ issue_id: "test-004", depends_on_id: "test-1e5", type: "relates_to", metadata: "{}" }],
  });

  expect(result.records[0].dependsOnIds).toEqual([]);
  expect(result.warnings[0].code).toBe("unsupported_dependency_type");
});
```

- [ ] **Step 2: Run the adapter tests and verify they fail**

Run: `cd apps/beads-viewer && npm test -- beadsAdapter.test.ts`
Expected: FAIL because the adapter does not exist yet.

- [ ] **Step 3: Implement the minimal adapter**

`beadsAdapter.ts` should:
- treat `metadata: null` as empty object
- parse JSON strings safely
- warn on invalid JSON or non-object metadata
- derive only `group_id`, `group_label`, `parent_id`
- ignore unsupported dependency `type` values with warnings
- populate `blocksCount` from downstream reverse edges

- [ ] **Step 4: Run the adapter tests to verify they pass**

Run: `cd apps/beads-viewer && npm test -- beadsAdapter.test.ts`
Expected: PASS with normalized records and warnings working.

- [ ] **Step 5: Commit**

```bash
git add apps/beads-viewer/src/domain/beads/beadsAdapter.ts apps/beads-viewer/src/domain/beads/beadsAdapter.test.ts apps/beads-viewer/src/domain/beads/types.ts
git commit -m "feat: adapt DoltHub beads rows into task records"
```

## Chunk 3: Tree Construction

### Task 5: Implement dependency tree building

**Files:**
- Create: `apps/beads-viewer/src/domain/beads/treeBuilder.ts`
- Create: `apps/beads-viewer/src/domain/beads/treeBuilder.test.ts`
- Modify: `apps/beads-viewer/src/domain/beads/types.ts`

- [ ] **Step 1: Write failing dependency-tree tests**

```ts
it("builds blocker-to-blocked roots in task id order", () => {
  const tree = buildDependencyTree([
    { id: "test-1", title: "A", dependsOnIds: [], blocksCount: 1, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
    { id: "test-2", title: "B", dependsOnIds: ["test-1"], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
  ]);

  expect(tree.roots.map((node) => node.record.id)).toEqual(["test-1"]);
  expect(tree.roots[0].children[0].record.id).toBe("test-2");
});

it("uses reference nodes for repeated targets", () => {
  const tree = buildDependencyTree([
    { id: "test-1", title: "A", dependsOnIds: [], blocksCount: 2, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
    { id: "test-2", title: "B", dependsOnIds: ["test-1"], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
    { id: "test-3", title: "C", dependsOnIds: ["test-1"], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
    { id: "test-4", title: "D", dependsOnIds: ["test-2", "test-3"], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
  ]);
  expect(tree.referenceNodeCount).toBe(1);
});

it("flags cycles without infinite recursion", () => {
  const tree = buildDependencyTree([
    { id: "test-1", title: "A", dependsOnIds: ["test-2"], blocksCount: 1, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
    { id: "test-2", title: "B", dependsOnIds: ["test-1"], blocksCount: 1, status: "open", priority: 1, type: "task", assignee: "", description: "", parentId: null, groupId: null, groupLabel: null, raw: {} },
  ]);
  expect(tree.warnings[0].code).toBe("dependency_cycle");
});
```

- [ ] **Step 2: Run the dependency-tree tests and verify they fail**

Run: `cd apps/beads-viewer && npm test -- treeBuilder.test.ts`
Expected: FAIL because tree construction is not implemented yet.

- [ ] **Step 3: Implement dependency-tree construction minimally**

`buildDependencyTree` should:
- derive downstream edges from `dependsOnIds`
- sort roots by task ID ascending
- sort child nodes by downstream task ID ascending
- traverse depth-first
- use full nodes for first encounter and `ReferenceNodeModel` entries for repeats
- start rootless cyclic components at lexicographically smallest task ID

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/beads-viewer && npm test -- treeBuilder.test.ts`
Expected: PASS with repeat-node and cycle coverage green.

- [ ] **Step 5: Commit**

```bash
git add apps/beads-viewer/src/domain/beads/treeBuilder.ts apps/beads-viewer/src/domain/beads/treeBuilder.test.ts apps/beads-viewer/src/domain/beads/types.ts
git commit -m "feat: build deterministic dependency trees"
```

### Task 6: Implement grouped tree building

**Files:**
- Modify: `apps/beads-viewer/src/domain/beads/treeBuilder.ts`
- Modify: `apps/beads-viewer/src/domain/beads/treeBuilder.test.ts`

- [ ] **Step 1: Write failing grouped-tree tests**

```ts
it("groups by groupId before parentId and falls back to Ungrouped", () => {
  const tree = buildGroupedTree([
    { id: "test-1", title: "A", groupId: "epic-1", groupLabel: "Epic 1", parentId: null, dependsOnIds: [], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", raw: {} },
    { id: "test-2", title: "B", groupId: null, groupLabel: null, parentId: "test-1", dependsOnIds: [], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", raw: {} },
  ]);

  expect(tree.sections[0].title).toBe("Epic 1");
  expect(tree.sections[1].title).toBe("A");
});

it("renders out-of-section parents as top-level warnings", () => {
  const tree = buildGroupedTree([
    { id: "test-1", title: "Group Parent", groupId: "epic-1", groupLabel: "Epic 1", parentId: null, dependsOnIds: [], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", raw: {} },
    { id: "test-2", title: "Other Group Parent", groupId: "epic-2", groupLabel: "Epic 2", parentId: null, dependsOnIds: [], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", raw: {} },
    { id: "test-3", title: "Child", groupId: "epic-1", groupLabel: "Epic 1", parentId: "test-2", dependsOnIds: [], blocksCount: 0, status: "open", priority: 1, type: "task", assignee: "", description: "", raw: {} },
  ]);
  expect(tree.sections[0].nodes[0].warnings).toContainEqual(
    expect.objectContaining({ code: "parent_out_of_section" }),
  );
});
```

- [ ] **Step 2: Run the grouped-tree tests and verify they fail**

Run: `cd apps/beads-viewer && npm test -- treeBuilder.test.ts`
Expected: FAIL on grouped-tree assertions.

- [ ] **Step 3: Implement grouped-tree construction minimally**

`buildGroupedTree` should:
- assign sections by `groupId`, then `parentId`, then `Ungrouped`
- resolve section titles by `groupLabel`, parent title, then stable ID
- nest only by `parentId`
- keep dependency info as secondary card metadata, not tree edges
- warn on missing or out-of-section parents

- [ ] **Step 4: Run the grouped-tree tests to verify they pass**

Run: `cd apps/beads-viewer && npm test -- treeBuilder.test.ts`
Expected: PASS for dependency and grouped builders.

- [ ] **Step 5: Commit**

```bash
git add apps/beads-viewer/src/domain/beads/treeBuilder.ts apps/beads-viewer/src/domain/beads/treeBuilder.test.ts
git commit -m "feat: add grouped beads task trees"
```

## Chunk 4: UI Integration And Verification

### Task 7: Implement the repo-loading hook and status handling

**Files:**
- Create: `apps/beads-viewer/src/hooks/useRepoData.ts`
- Create: `apps/beads-viewer/src/hooks/useRepoData.test.tsx`
- Modify: `apps/beads-viewer/src/domain/beads/types.ts`

- [ ] **Step 1: Write the failing hook tests**

```tsx
import { act, renderHook, waitFor } from "@testing-library/react";

it("loads saved repo on mount and persists successful replacements", async () => {
  window.localStorage.setItem("beads-viewer:last-repo", JSON.stringify({ rawInput: "vanhiep99w/test", canonicalRepo: "vanhiep99w/test", sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test" }));
  const { result } = renderHook(() => useRepoData({ fetchRepoData: fakeFetchRepoData }));

  await waitFor(() => {
    expect(result.current.repo?.canonicalRepo).toBe("vanhiep99w/test");
  });
});

it("keeps the saved repo when a new load fails", async () => {
  window.localStorage.setItem("beads-viewer:last-repo", JSON.stringify({ rawInput: "vanhiep99w/test", canonicalRepo: "vanhiep99w/test", sourceUrl: "https://www.dolthub.com/repositories/vanhiep99w/test" }));
  const { result } = renderHook(() => useRepoData({ fetchRepoData: fakeFetchRepoDataOnceThenFail }));

  await waitFor(() => {
    expect(result.current.repo?.canonicalRepo).toBe("vanhiep99w/test");
  });

  await act(async () => {
    await result.current.loadRepo("vanhiep99w/other");
  });

  expect(window.localStorage.getItem("beads-viewer:last-repo")).toContain("vanhiep99w/test");
});
```

- [ ] **Step 2: Run the hook tests and verify they fail**

Run: `cd apps/beads-viewer && npm test -- useRepoData.test.tsx`
Expected: FAIL because the hook does not exist yet.

- [ ] **Step 3: Implement the minimal hook**

`useRepoData.ts` should:
- restore the last saved repo on mount
- normalize manual input before loading
- call `DoltHubClient`, `BeadsAdapter`, then `TreeBuilder`
- map failures into `fetch_failure`, `unsupported_schema`, or `parse_failure`
- persist only the most recent successful repo

- [ ] **Step 4: Run the hook tests to verify they pass**

Run: `cd apps/beads-viewer && npm test -- useRepoData.test.tsx`
Expected: PASS with restore and failure-retention behavior green.

- [ ] **Step 5: Commit**

```bash
git add apps/beads-viewer/src/hooks/useRepoData.ts apps/beads-viewer/src/hooks/useRepoData.test.tsx apps/beads-viewer/src/domain/beads/types.ts
git commit -m "feat: orchestrate repo loading and persistence"
```

### Task 8: Implement viewer components and end-to-end app composition

**Files:**
- Create: `apps/beads-viewer/src/components/RepoForm.tsx`
- Create: `apps/beads-viewer/src/components/ViewModeToggle.tsx`
- Create: `apps/beads-viewer/src/components/SummaryBar.tsx`
- Create: `apps/beads-viewer/src/components/TaskCard.tsx`
- Create: `apps/beads-viewer/src/components/ReferenceNode.tsx`
- Create: `apps/beads-viewer/src/components/DependencyTree.tsx`
- Create: `apps/beads-viewer/src/components/GroupedTree.tsx`
- Create: `apps/beads-viewer/src/components/StatusPanel.tsx`
- Modify: `apps/beads-viewer/src/app/App.tsx`
- Modify: `apps/beads-viewer/src/app/App.css`
- Modify: `apps/beads-viewer/src/app/App.test.tsx`

- [ ] **Step 1: Write the failing app integration tests**

```tsx
import userEvent from "@testing-library/user-event";

it("renders dependency mode by default and switches to grouped mode", async () => {
  const user = userEvent.setup();
  render(<App />);
  expect(await screen.findByRole("button", { name: /dependency/i })).toHaveAttribute("aria-pressed", "true");
  await user.click(screen.getByRole("button", { name: /grouped/i }));
  expect(screen.getByRole("button", { name: /grouped/i })).toHaveAttribute("aria-pressed", "true");
});

it("shows task metadata and the DoltHub docs link", async () => {
  render(<App />);
  expect(await screen.findByRole("link", { name: /dolthub docs/i })).toHaveAttribute("href", "https://docs.dolthub.com/");
  expect(screen.getByText(/priority/i)).toBeInTheDocument();
  expect(screen.getByText(/assignee/i)).toBeInTheDocument();
});
```

- [ ] **Step 2: Run the app integration tests and verify they fail**

Run: `cd apps/beads-viewer && npm test -- App.test.tsx`
Expected: FAIL because the real app composition does not exist yet.

- [ ] **Step 3: Implement the minimal UI components**

Requirements:
- `RepoForm` disables submit when input is empty
- `ViewModeToggle` uses `aria-pressed`
- `SummaryBar` applies deterministic counter rules from the spec
- `TaskCard` shows title, ID, status, assignee, priority, type, dependencies, truncated description
- `ReferenceNode` links back to canonical node label
- `StatusPanel` covers loading, fetch failure, unsupported schema, parse failure, and empty states

- [ ] **Step 4: Compose the app shell**

`App.tsx` should:
- show the repo form, view-mode toggle, summary bar, and DoltHub docs link
- render `DependencyTree` by default
- switch to `GroupedTree` without refetching
- show warnings inline without breaking the tree

- [ ] **Step 5: Run the app integration tests to verify they pass**

Run: `cd apps/beads-viewer && npm test -- App.test.tsx`
Expected: PASS with UI composition and mode switch working.

- [ ] **Step 6: Run the full test suite**

Run: `cd apps/beads-viewer && npm test`
Expected: PASS for all unit, hook, and app tests.

- [ ] **Step 7: Run a production build**

Run: `cd apps/beads-viewer && npm run build`
Expected: PASS and emit `dist/` output without TypeScript errors.

- [ ] **Step 8: Commit**

```bash
git add apps/beads-viewer
git commit -m "feat: render beads DoltHub viewer UI"
```

### Task 9: Final verification and repo-level documentation touch-up

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing documentation expectation**

Add this checklist to the task notes before editing and treat any unchecked item as a failure:

- [ ] app location is documented
- [ ] dev/test/build commands are documented
- [ ] public-repo-only limitation is documented

- [ ] **Step 2: Update the README minimally**

Add one concise section describing:
- app location: `apps/beads-viewer/`
- local commands:

```bash
cd apps/beads-viewer
npm install
npm run dev
npm test
npm run build
```

- [ ] **Step 3: Run focused verification**

Run:

```bash
cd apps/beads-viewer && npm test
cd apps/beads-viewer && npm run build
```

Expected: both commands PASS after the README update.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add beads viewer usage notes"
```

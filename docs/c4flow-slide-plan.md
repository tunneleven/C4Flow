# 📊 Plan: Slide trình bày Hackathon — Cách sử dụng AI với C4Flow

> **Mục tiêu:** Trình bày cách đội sử dụng AI trong cuộc thi hackathon, và cách tự xây dựng C4Flow để tối ưu workflow.
> **Bối cảnh:** Slide dùng để thi hackathon — kể câu chuyện đội đã dùng AI + tooling tự xây để thi đấu.
> **Số lượng:** 13 slides
> **Thời lượng:** ~20 phút

---

## Slide 1 — Title Slide

**Tiêu đề:** Cách chúng tôi sử dụng AI trong Hackathon

**Subtitle:** Từ ý tưởng đến sản phẩm — Xây dựng C4Flow để thi đấu

**Visual:**
- Logo đội / tên cuộc thi
- Tagline: *"AI không chỉ viết code — AI điều khiển cả workflow"*

**Speaker notes:**
- Giới thiệu team, cuộc thi
- Hook: "Chúng tôi không chỉ dùng AI để code — chúng tôi xây hẳn một hệ thống để AI điều khiển toàn bộ quy trình phát triển."

---

## Slide 2 — Bài toán: AI Coding trong Hackathon

**Tiêu đề:** Vấn đề: Dùng AI coding trong hackathon không đơn giản

**Nội dung:**
- Thời gian giới hạn → cần tốc độ tối đa
- AI giỏi viết code — nhưng **ai quản lý workflow?**
- Mỗi session AI mới = **mất toàn bộ context** trước đó
- Research riêng, spec riêng, code riêng → **fragmented, không liên kết**
- Kết quả: code chất lượng thấp, lặp lại công việc, mất thời gian quý báu

**Visual:**
- Diagram: nhiều AI sessions rời rạc, mũi tên đỏ gãy giữa các bước
- Clock ticking icon

**Speaker notes:**
- Kể trải nghiệm thực: "Lần đầu dùng AI trong hackathon, chúng tôi mất 2 tiếng chỉ vì AI quên context giữa chừng."

---

## Slide 3 — Nguồn cảm hứng: Hệ sinh thái Spec-Driven & Agentic Skills

**Tiêu đề:** Chúng tôi học được gì từ cộng đồng

**Nội dung — 3 dự án gốc:**

### 🔷 Superpowers (obra/superpowers) — ⭐ 125k stars
- Agentic skills framework & software development methodology
- Ý tưởng cốt lõi: **Skills tự động kích hoạt** — Agent tự biết khi nào brainstorm, khi nào plan, khi nào code
- Workflow: Brainstorming → Writing Plans → Subagent-Driven Development → TDD → Code Review
- **Triết lý:** TDD bắt buộc, systematic over ad-hoc, evidence over claims

### 🔷 OpenSpec (Fission-AI/OpenSpec) — ⭐ 35.6k stars
- Spec-Driven Development (SDD) cho AI coding assistants
- Workflow: `/opsx:propose` → specs → design → tasks → implement → archive
- **Ý tưởng hay:** Mỗi change có folder riêng (proposal, specs, design, tasks)
- Fluid, iterative — không rigid phase gates

### 🔷 Spec Kit (github/spec-kit) — ⭐ 83.7k stars
- GitHub official — toolkit cho Spec-Driven Development
- Workflow: Constitution → Specify → Plan → Tasks → Implement
- **Ý tưởng hay:** Specifications become executable, trực tiếp generate implementations
- Hệ thống extensions & presets mở rộng

**Speaker notes:**
- "Ba dự án này đều giải quyết cùng 1 vấn đề: làm sao để AI coding có structure, không phải vibe coding. Chúng tôi học rất nhiều từ họ."

---

## Slide 4 — C4Flow: Lấy cảm hứng, nhưng vượt xa

**Tiêu đề:** C4Flow — Xây dựng riêng cho hackathon

**Nội dung:**

### Điểm chung với 3 dự án trên:
- ✅ Spec-driven: Research → Spec → Design → Code
- ✅ Sub-agent driven: mỗi phase có agent chuyên biệt  
- ✅ Skills system: markdown + shell, zero dependencies
- ✅ TDD bắt buộc, quality gates

### C4Flow làm **KHÁC** và **THÊM** gì:
| Tính năng | OpenSpec / Spec Kit / Superpowers | C4Flow |
|-----------|----------------------------------|--------|
| Task management | **Markdown file** (`tasks.md`) | **Beads** — version-controlled DB |
| Task tracking giữa session | ❌ Mất khi compact | ✅ Persist qua Dolt |
| Dependency enforcement | Text mô tả, agent tự hiểu | Database enforce, tự động block |
| State machine | Không / implicit | **Explicit** — `.state.json` persist |
| Design system | Không có | OKLCH tokens + Pencil MCP mockups |
| Infra & Deploy | Không có | AWS EC2 + nginx + SSL + Cloudflare |

**Speaker notes:**
- "Chúng tôi không reinvent the wheel — chúng tôi đứng trên vai người khổng lồ. Nhưng thiếu 1 mảnh ghép quan trọng: task management cho AI agent."

---

## Slide 5 — Tại sao Beads, không phải Markdown?

**Tiêu đề:** Bài học đắt giá: Markdown tasks không đủ cho AI Agent

**Nội dung — Vấn đề của Markdown tasks:**

### 🔴 Agent Amnesia — Mất trí nhớ
```
Agent làm Task 1 được 50%
→ Context window đầy → Compact
→ Agent đọc lại tasks.md
→ Thấy "- [ ] Task 1" (chưa check!)
→ LÀM LẠI TỪ ĐẦU! 😱
```

### 🔴 Implicit dependencies — Agent phải tự suy luận
- "depends on" nghĩa là block hay chỉ liên quan?
- Suy luận = tốn tokens + **có thể sai**

### 🔴 Chỉ có 2 trạng thái
- `[ ]` TODO vs `[x]` DONE
- Không có: "đang làm 50%", "đang đợi review", "bị block"

### 🔴 Không scale
- File 500 dòng = 2000 tokens mỗi lần đọc
- Agent đọc 3 lần = 6000 tokens chỉ để biết task nào cần làm

**Visual:**
- So sánh 2 flow: Markdown (đỏ, phức tạp) vs Beads (xanh, đơn giản)

**Speaker notes:**
- "Trong hackathon, mỗi phút đều quý. Mất 10 phút vì AI làm lại task đã làm 50% là không chấp nhận được."

---

## Slide 6 — Beads: Task Management cho AI Agent

**Tiêu đề:** Beads — Issue Tracker thiết kế riêng cho AI

**Nội dung:**

> *"Markdown là danh sách task để ĐỌC và TỰ HIỂU.*
> *Beads là hệ thống quản trị task để HỎI và NHẬN câu trả lời."*

### So sánh trực tiếp:

**Markdown:**
```
Agent đọc tasks.md (2000 tokens)
→ Parse text, tìm [ ] và [x]
→ Suy luận dependency
→ Có thể sai, tốn tokens
```

**Beads:**
```bash
$ bd ready --json              # 50 tokens
[{"id":"bd-1","title":"Setup database","priority":1}]
# → Chính xác, đã filter + sort, agent không cần suy luận
```

### Tính năng killer:
- **Auto-ready detection** — chỉ tasks không bị block mới trả về
- **Rich status** — open / in_progress / blocked / closed + notes chi tiết
- **Hash-based ID** — không conflict khi nhiều agent song song
- **Git-native** — sync qua git, không cần server
- **Discovered work** — track bug phát sinh giữa chừng

**Speaker notes:**
- Demo nhanh: `bd ready --json` → output, `bd update --status in_progress` → claim task

---

## Slide 7 — C4Flow State Machine

**Tiêu đề:** 12 Phases, 1 State Machine — Không mất context

**Nội dung (Flowchart):**
```
IDLE → RESEARCH → SPEC → DESIGN → BEADS → CODE ↻ → TEST → REVIEW → VERIFY → PR → MERGE → DEPLOY → DONE
```

**3 nhóm chính:**
1. 🔍 **Discovery:** Research → Spec → Design
2. 🔨 **Build:** Beads → Code Loop (TDD)  
3. 🚀 **Ship:** Review → Verify → PR → Merge → Deploy

**Điểm đặc biệt:**
- State persist tại `docs/c4flow/.state.json`
- Mỗi `/c4flow:run` advance 1 phase → dừng/resume bất cứ lúc nào
- Feedback loops: TEST fail → CODE, REVIEW fail → SPEC
- Graceful degradation: không có Pencil → skip Design, không có `bd` → fallback `tasks.md`

**Speaker notes:**
- "Trong hackathon, có khi bạn phải tắt máy đi ăn. Quay lại, gõ `/c4flow:run` — nó tự biết đang ở phase nào."

---

## Slide 8 — Phase: Research & Spec

**Tiêu đề:** Discovery: Từ ý tưởng thô → Spec chất lượng

**Nội dung:**

### Research (`/c4flow:research`)
- Sub-agent tự web research
- 2 layers: **Market Analysis** + **Technical Research**
- Output: `research.md` — competitive landscape, tech options, risks

### Spec (`/c4flow:spec`)
- **Interactive** — agent hỏi bạn ở quyết định quan trọng
- Output 4 files:

| File | Nội dung |
|------|----------|
| `proposal.md` | Why + what to build |
| `tech-stack.md` | Technology decisions |
| `spec.md` | GIVEN/WHEN/THEN behavioral specs |
| `design.md` | Technical architecture |

**Speaker notes:**
- "Trong hackathon, research phase có thể rất ngắn — nhưng spec phase là critical. Spec tốt = code nhanh."

---

## Slide 9 — Phase: Design — Generate shared components & design system

**Tiêu đề:** Design: AI tự tạo Design System + Reusable Components

**Nội dung:**

### Vấn đề khi không có Design phase:
- AI code mỗi screen riêng lẻ → **inconsistent** (mỗi button 1 kiểu, mỗi form 1 style)
- Copy-paste UI code → **duplication**, khó maintain
- Không có shared tokens → thay đổi 1 màu phải sửa 50 chỗ

### C4Flow Design skill làm gì:

**Bước 1 — Generate Design Tokens (OKLCH color system):**
```
Primary:    oklch(0.65 0.24 265)   → Brand color
Secondary:  oklch(0.55 0.18 300)   → Accent
Neutral:    oklch(0.92 0.01 265)   → Backgrounds
Danger:     oklch(0.65 0.22 25)    → Error states
```
- Typography scale (font sizes, weights, line heights)
- Spacing system (4px grid: 4, 8, 12, 16, 24, 32, 48...)
- Border radius, shadow tokens

**Bước 2 — Generate Shared Components:**
- Đọc spec → xác định **components cần dùng lại** (Button, Input, Card, Modal, Table, Nav...)
- Tạo component library **dùng chung** cho tất cả screens
- Output: `MASTER.md` — danh sách components + tokens + usage guidelines

**Bước 3 — Screen Mockups (Pencil MCP):**
- Agent dùng shared components để compose screens
- Tạo file `.pen` với interactive mockups
- Output: `screen-map.md` — breakdown từng screen + components sử dụng

### Tác dụng thực tế:

| Không có Design phase | Có Design phase |
|----------------------|-----------------|
| Mỗi screen code riêng lẻ | Shared components, code 1 lần dùng nhiều nơi |
| AI tự chọn màu → mỗi lần 1 kiểu | OKLCH tokens → consistent toàn app |
| Đổi brand color = sửa 50 files | Đổi 1 token = đổi toàn bộ |
| Code phase chậm (phải quyết định UI) | Code phase nhanh (design đã quyết) |
| PR review: "button này sao khác button kia?" | PR review: focus vào logic, không tranh cãi UI |

**Visual:**
- Trước/Sau: 2 screenshots — app không có design system vs app có design system
- Component library diagram

**Speaker notes:**
- "Design phase không phải vẽ đẹp — nó là tạo ra 'hợp đồng UI' giữa các screens. Agent code phase sau chỉ việc import component, không cần tự quyết định style. Trong hackathon, điều này tiết kiệm RẤT NHIỀU thời gian vì bạn không phải fix inconsistency sau khi code xong."

---

## Slide 10 — Phase: Beads + Code Loop

**Tiêu đề:** Task Breakdown → TDD Code Loop

**Nội dung:**

### Beads Breakdown (`/c4flow:beads`):
- Đọc spec → tạo **epic** với dependency graph
- Chọn granularity: compact → balanced → atomic
- Agent ước lượng task count → bạn approve

### Code Loop — serial task implementation:
```
Pick task (bd ready) → Claim (bd update --status in_progress)
→ TDD (RED→GREEN→REFACTOR) → Test → Review → Verify
→ Close (bd close) → Next task
```

### TDD bắt buộc:
- **RED:** Viết test fail trước
- **GREEN:** Code vừa đủ để pass
- **REFACTOR:** Clean up
- Agent không được skip RED phase

### Recovery sau compact:
```bash
$ bd ready --json              # Không có task ready
$ bd list --status in_progress # Tìm task đang làm dở
$ bd show bd-1                 # Đọc notes → biết đang ở đâu
→ TIẾP TỤC ĐÚNG CHỖ!         # Không làm lại từ đầu
```

**Speaker notes:**
- "Đây là nơi Beads tỏa sáng. Sau compact, agent không làm lại từ đầu — nó đọc notes từ Beads và tiếp tục."

---

## Slide 11 — Bonus Tool: GitNexus — Code Intelligence cho AI Agent

**Tiêu đề:** GitNexus: Codebase Knowledge Graph cho AI Agent

**Nội dung:**

### Vấn đề khi codebase lớn dần:
- AI edit `UserService.validate()` → **không biết 47 functions depend on nó** → breaking changes
- AI chỉ thấy file đang mở → **thiếu toàn cảnh kiến trúc**
- Mỗi lần AI search code = duyệt file → **tốn tokens, chậm, bỏ sót**

### GitNexus (⭐ 20.8k) giải quyết gì:
> *"Like DeepWiki, but deeper. DeepWiki helps you understand code. GitNexus lets you analyze it."*

- **Knowledge Graph** — index toàn bộ codebase: functions, classes, calls, dependencies, imports
- **MCP Server** — expose 7 tools cho AI agent qua MCP protocol
- **Zero-server** — chạy local, code không rời máy

### Tại sao nên dùng cùng C4Flow:

| Không có GitNexus | Có GitNexus |
|-------------------|-------------|
| AI search code bằng grep → bỏ sót | Knowledge graph → tìm mọi dependency |
| AI sửa function → không biết ai gọi nó | `impact()` → blast radius analysis trước khi sửa |
| AI phải đọc nhiều file → tốn context | Pre-computed clusters → compact context |
| Model nhỏ → hay miss dependencies | Model nhỏ cũng reliable → tools làm heavy lifting |

### Công cụ chính cho AI agent:
```bash
npx gitnexus analyze          # Index codebase
# Agent tự động có:
# - impact()  → blast radius analysis
# - query()   → semantic code search
# - context() → architectural overview
# - detect_changes() → what changed since last index
```

### C4Flow không có GitNexus built-in — nhưng rất bổ sung:
- C4Flow quản lý **workflow** (research → code → deploy)
- GitNexus cung cấp **code intelligence** (dependencies, impact, clusters)
- Dùng cùng nhau: agent biết **task nào cần làm** (Beads) VÀ **code nào bị ảnh hưởng** (GitNexus)

**Speaker notes:**
- "GitNexus không nằm trong C4Flow, nhưng chúng tôi dùng song song. Khi codebase lớn lên trong hackathon, GitNexus giúp AI agent không phá code cũ khi thêm feature mới. Nó bổ sung cho Beads: Beads nói 'làm task gì', GitNexus nói 'sửa code nào an toàn'."

---

## Slide 12 — Quality Gate System

**Tiêu đề:** Quality Gates — 2 lớp bảo vệ, kể cả AI cũng không cheat được

**Nội dung:**

### Layer 1 — Beads Gates (Primary):
- `bd close` từ chối đóng task khi chưa pass gates
- Phải `--force` để bypass (logged)

### Layer 2 — Claude Code Hooks (Safety Net):
| Hook | Trigger | Action |
|------|---------|--------|
| `PreToolUse` | `bd close` | Check quality-gate-status.json |
| `Stop` | Session end | Block nếu gates open |
| `TaskCompleted` | Task done | Verify gates |

**Tại sao quan trọng trong hackathon?**
- Tốc độ không có nghĩa là bỏ qua chất lượng
- Quality gates đảm bảo code merge-ready
- Ban giám khảo thấy: code có test, có review, có quality process

**Speaker notes:**
- "Hackathon hay tempt bạn skip testing. Quality gates ngăn chặn điều đó — ngay cả khi bạn muốn."

---

## Slide 13 — Closing: Tư duy đúng về AI Workflow

**Tiêu đề:** Đừng copy C4Flow — Hãy xây workflow của riêng bạn

**Nội dung:**

### 🎯 Thông điệp cốt lõi:

> **C4Flow KHÔNG được xây dựng cho tất cả mọi thứ.**
> Nó được xây dựng **chỉ cho cuộc thi này** — với team này, project này, timeline này.

### Điều chúng tôi muốn chia sẻ:

#### 1. Học cách sử dụng MCP & Skills — không phải học C4Flow
- **MCP (Model Context Protocol)** là standard kết nối AI với tools bên ngoài
- **Skills** là cách dạy AI agent quy trình cụ thể
- C4Flow chỉ là **1 cách triển khai** — có hàng trăm cách khác
- Đầu tư thời gian vào hiểu MCP & skills system → dùng được mọi nơi

#### 2. Mỗi project nên có workflow riêng
- Project khác nhau → yêu cầu khác nhau → workflow khác nhau
- Solo project? Không cần Beads, `tasks.md` đủ
- Team 10 người? Có thể cần Jira integration, không phải Dolt
- Hackathon 24h? Skip research, fast-track spec
- Enterprise? Cần compliance gates, audit trail
- **Không có workflow "one-size-fits-all"** — đừng tìm, hãy xây

#### 3. Công thức chung:
```
Bước 1: Hiểu tools → MCP servers, Skills, Hooks
Bước 2: Hiểu vấn đề → Project này cần gì? Team này thiếu gì?
Bước 3: Combine → Lắp ghép tools phù hợp thành workflow riêng
Bước 4: Iterate → Dùng → gặp vấn đề → sửa → dùng tiếp
```

### 📚 Nên học & khám phá:
| Concept | Tại sao quan trọng | Bắt đầu từ đâu |
|---------|--------------------|-|
| **MCP Protocol** | Kết nối AI agent với bất kỳ tool nào | modelcontextprotocol.io |
| **Skills/Plugins** | Dạy AI quy trình cụ thể cho project bạn | superpowers, OpenSpec |
| **Hooks** | Tự động trigger hành động ở key events | Claude Code docs |
| **Spec-Driven Dev** | AI code tốt hơn khi có spec rõ ràng | spec-kit, OpenSpec |
| **Beads/Task tracking** | AI cần "bộ nhớ" persistent | beads CLI docs |
| **GitNexus** | AI cần hiểu kiến trúc codebase | github.com/abhigyanpatwari/GitNexus |

### Key takeaway:
> *"AI agent mạnh nhất không phải agent thông minh nhất — mà là agent có workflow tốt nhất.*
> *Và workflow tốt nhất là workflow bạn tự xây cho project của mình."*

### Links tham khảo:
- C4Flow: `github.com/tunneleven/C4Flow`
- Beads article: `github.com/thientranhung/agentic-coding-lab`
- Superpowers: `github.com/obra/superpowers`
- OpenSpec: `github.com/Fission-AI/OpenSpec`
- Spec Kit: `github.com/github/spec-kit`
- GitNexus: `github.com/abhigyanpatwari/GitNexus`

**Speaker notes:**
- "Chúng tôi chia sẻ C4Flow không phải để mọi người copy. Mà để truyền cảm hứng: hãy tìm hiểu tools, hiểu vấn đề project của bạn, rồi xây workflow phù hợp. Nếu bạn chỉ rút ra 1 thứ từ bài này: hãy học cách dùng MCP và Skills — đó là nền tảng cho tất cả."

---

## 📝 Ghi chú sản xuất

### Style Guide:
- **Theme:** Dark mode, tech-forward (tương tự screenshots Savvycom đã attach)
- **Colors:** Gradient xanh teal → cyan
- **Font:** Inter hoặc Outfit
- **Code blocks:** Syntax highlighting, terminal style

### Thời gian ước tính:
| Slide | Thời gian |
|-------|-----------|
| 1-2 (Intro & Problem) | 2-3 phút |
| 3-4 (Inspirations & C4Flow) | 3-4 phút |
| 5-6 (Beads deep-dive) | 3-4 phút |
| 7-8 (State machine & Discovery) | 2-3 phút |
| 9 (Design — components) | 2-3 phút |
| 10 (Beads + Code Loop) | 2-3 phút |
| 11 (GitNexus) | 2-3 phút |
| 12 (Quality gates) | 1-2 phút |
| 13 (Closing — build your own) | 2-3 phút |
| **Tổng** | **~19-28 phút** |

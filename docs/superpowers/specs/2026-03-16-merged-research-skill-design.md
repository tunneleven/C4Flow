# Design: Merged Research Skill

> Date: 2026-03-16
> Status: Draft
> Replaces: `skills/research/SKILL.md` (viết lại hoàn toàn)
> Extends: `references/spec-templates/research-template.md` (thêm sections mới từ market-research)

---

## Context

C4Flow có skill `research` chạy như sub-agent trong phase 1. Market-research (github.com/CongChu99/market-research) là một standalone skill chuyên phân tích thị trường với 4 analysis layers sâu hơn.

**Vấn đề hiện tại:**
- C4Flow `research` thiếu: Feature Comparison matrix, Gap Analysis, Differentiation Strategy, MVP Scope, Business Domain analysis — những thứ cần thiết để spec phase ra quyết định tốt
- Market-research thiếu: Technical Approaches, Contrarian View, Risks — dễ bỏ qua downside cases
- Hai tool không nói chuyện được với nhau, user phải copy-paste thủ công

**Mục tiêu:** Merge cả hai thành một skill duy nhất thay thế `skills/research/SKILL.md` trong C4Flow, giữ nguyên interface với orchestrator.

---

## Architecture Overview

Skill mới là sub-agent, chạy trong C4Flow pipeline giữa IDLE→RESEARCH→SPEC. Interface với orchestrator không thay đổi. Nội dung bên trong gồm 2 layer phân tích chạy tuần tự.

```
Orchestrator
    │
    └─▶ c4flow:research (sub-agent)
            │
            ├─ Step 1: Parse input + determine mode
            │
            ├─ Layer 1: Market Analysis (10 sections)
            │   ├─ Business Domain (personas, workflows, entities, rules)
            │   ├─ Competitive Landscape
            │   ├─ Feature Comparison (✓/△/✗ matrix)
            │   ├─ Gap Analysis (5 loại)
            │   ├─ Differentiation Strategy
            │   └─ Initial MVP Scope
            │
            ├─ Layer 2: Technical Research (4 sections)
            │   ├─ Technical Approaches (pros/cons/complexity)
            │   ├─ Contrarian View (bắt buộc)
            │   ├─ Risks
            │   └─ Recommendations
            │
            ├─ Quality Gate (8 core checks + 1 fast-mode check)
            │
            ├─ Executive Summary (sinh sau khi cả 2 layers + gate xong)
            │
            └─ Ghi research.md → báo status
```

---

## Components

### Component 1: Mode Resolver

**Purpose:** Xác định execution mode từ input của orchestrator.

**Interface:** Đọc field `Mode: fast | research` trong sub-agent prompt.

**Logic:**
- Default: `fast`
- Override: nếu prompt chứa `Mode: research` → `research`

**Dependencies:** Không có.

---

### Component 2: Layer 1 — Market Analysis

**Purpose:** Phân tích business domain và thị trường, lấy từ market-research.

**Interface:** Nhận feature name + description. Output là data để điền vào 10 sections đầu của template (Problem Statement → Initial MVP Scope).

**Sections:**
- Problem Statement
- Target Users (2-4 personas: role, goal, frustration)
- Core Workflows (3-6 workflows dạng numbered steps)
- Domain Entities (key data objects + attributes)
- Business Rules (constraints hệ thống phải enforce)
- Competitive Landscape (4-8 competitors)
  - Per competitor: Name, Type (direct/indirect/adjacent), Target segment, Pricing model, Platform, Key differentiator
  - Research mode: WebSearch từng competitor để verify và enrich (tối đa 3 searches/competitor: pricing, features, reviews)
- Feature Comparison (✓/△/✗ matrix: ≥10 features × ≥4 competitors + "Your Product" column)
- Gap Analysis (Feature / Segment / UX / Pricing / Integration gaps)
- Differentiation Strategy (3-5 điểm cụ thể)
- Initial MVP Scope (5-10 features với must/should/later)

**Behavior per mode:**
- `fast`: dùng AI internal knowledge, không web search
- `research`: WebSearch từng competitor (pricing, features, reviews), tối đa 3 searches/competitor

**Dependencies:** Không có.

---

### Component 3: Layer 2 — Technical Research

**Purpose:** Phân tích kỹ thuật và rủi ro, lấy từ C4Flow research gốc.

**Interface:** Nhận feature context từ Layer 1. Output là data cho 3 section cuối.

**Sections:**
- Technical Approaches (approaches × pros/cons/complexity/lock-in risk)
- Contrarian View (bắt buộc ≥1 lý do không nên build)
- Risks (risk × likelihood × impact × mitigation)
- Recommendations (label rõ fact/inference/recommendation)

**Behavior per mode:**
- `fast`: dùng AI internal knowledge
- `research`: WebFetch 3-5 nguồn kỹ thuật quan trọng nhất

**Dependencies:** Layer 1 phải hoàn thành trước (dùng competitive context để đánh giá technical approaches).

---

### Component 4: Quality Gate

**Purpose:** Tự kiểm tra output trước khi ghi file. Fix nếu fail.

**Interface:** Chạy sau khi cả 2 layer xong, trước khi ghi file.

**8 core checks:**

Market checks (từ market-research):
1. Feature Comparison có ≥10 features và ≥4 competitors
2. Gap Analysis có entry ở ít nhất 3/5 loại gap
3. Differentiation Strategy có ≥3 điểm (không generic)
4. MVP Scope có 5-10 features với priority labels

Technical checks (từ C4Flow):
5. Mọi số liệu có source hoặc ghi `[estimate]`
6. Data cũ hơn 2 năm ghi `[stale: YYYY]`
7. Có ít nhất 1 contrarian/downside case
8. Risks section không rỗng

Conditional check (fast mode only):
9. Disclaimer có ở đầu file

**Nếu fail:** Fix ngay trước khi ghi, không báo DONE_WITH_CONCERNS chỉ vì thiếu section.

**Dependencies:** Layer 1 + Layer 2 đều xong.

---

### Component 5: Executive Summary

**Purpose:** Sinh tóm tắt quyết định (build/buy/skip) dựa trên tất cả findings.

**Interface:** Chạy sau Quality Gate, trước khi ghi file. Output là 2-3 câu verdict.

**Content:** Trả lời: "Nên build, buy/integrate, hay skip? Tại sao?" — dựa trên competitive landscape, gaps, technical feasibility, và risks đã phân tích.

**Dependencies:** Quality Gate pass.

---

## Data Model

### Input (từ orchestrator)

```
Feature: {feature name}
Description: {feature description}
Mode: fast | research         ← mới thêm, default: fast
```

> **Note:** Market-research standalone hỗ trợ 3 input modes (string, structured, file). Trong C4Flow pipeline, input luôn đi qua orchestrator nên chỉ nhận feature name + description. Nếu cần structured input, orchestrator parse trước và truyền vào.

### Output file: `docs/specs/<feature>/research.md`

```markdown
# Research: <feature-name>

> Mode: fast | research
> Date: YYYY-MM-DD
> ⚠️ [disclaimer — fast mode only]

## Executive Summary
## Problem Statement
## Target Users
## Core Workflows
## Domain Entities
## Business Rules
## Competitive Landscape
## Feature Comparison
## Gap Analysis
## Differentiation Strategy
## Initial MVP Scope
## Technical Approaches
## Contrarian View
## Risks
## Recommendations
## Sources         ← research mode only
```

### State — không thay đổi

Orchestrator `.state.json` không cần thay đổi. Gate condition vẫn là: `docs/specs/<feature>/research.md` tồn tại.

---

## API Design

### Status codes báo về orchestrator — không thay đổi

| Status | Điều kiện |
|--------|-----------|
| `DONE` | Tất cả checks pass, file ghi xong |
| `DONE_WITH_CONCERNS` | File xong nhưng có giới hạn — niche topic không đủ 4 competitors, nguồn conflicting, data mostly stale |
| `BLOCKED` | Không thể tiến hành — idea quá mơ hồ sau 2 câu hỏi, không có web access ở research mode |
| `NEEDS_CONTEXT` | Cần thêm info từ user — target market chưa rõ, platform chưa xác định |

### Clarifying questions (nếu input mơ hồ)

Tối đa 2 câu hỏi trước khi chạy. Ưu tiên reasonable assumptions hơn hỏi nhiều.

---

## Error Handling

| Tình huống | Xử lý |
|------------|-------|
| Idea quá broad (ví dụ: "social media app") | Hỏi tối đa 2 câu để thu hẹp scope |
| Niche topic, ít competitor (<4) | Dùng adjacent/indirect competitors, ghi rõ trong DONE_WITH_CONCERNS |
| Web search fail (research mode) | Retry 1 lần với broader query; nếu vẫn fail → mark `?`, ghi "search failed" trong Sources |
| Rate limit giữa searches (research mode) | Wait 1-2 giây giữa các search |
| Quality gate fail | Fix nội dung, không skip gate |

---

## Goals / Non-Goals

**Goals:**
- Skill mới có output đủ phong phú để spec phase ra quyết định build/buy/skip tốt hơn
- Giữ nguyên interface orchestrator ↔ research sub-agent
- Fast mode cho phép brainstorm nhanh không tốn token
- Tích hợp 100% nội dung từ cả C4Flow research và market-research

**Non-Goals:**
- Không thay đổi spec phase, beads phase, hoặc bất kỳ phase nào khác
- Không thêm output file mới (vẫn chỉ là `research.md`)
- Không thay đổi `.state.json` schema
- Không support multi-platform (Codex, Gemini) — C4Flow là Claude Code only

---

## Decisions

### D1: 2 layers tuần tự thay vì gộp phẳng

**Quyết định:** Layer 1 (market) → Layer 2 (technical), không gộp phẳng.

**Lý do:** Hai loại phân tích có mục đích khác nhau. Market analysis trả lời "nên build không và build gì"; technical research trả lời "build như thế nào". Layer 2 dùng context từ Layer 1 (competitors, gaps) để đánh giá technical approaches tốt hơn.

**Thay thế đã xét:** Gộp phẳng — bị loại vì prompt quá dài, khó maintain.

### D2: Giữ nguyên interface với orchestrator

**Quyết định:** Không thay đổi status codes, input format (trừ thêm `Mode`), output path.

**Lý do:** Orchestrator, gate conditions, và state machine không cần sửa. Giảm blast radius của thay đổi.

### D3: Mode truyền từ orchestrator, không phải user tự gọi skill

**Quyết định:** Orchestrator đọc `--research` flag từ `/c4flow:run` và truyền `Mode:` vào sub-agent prompt.

**Lý do:** User không gọi skill trực tiếp — họ gọi `/c4flow:run`. Flag phải đi qua orchestrator.

---

## Risks / Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Prompt quá dài làm sub-agent miss instructions | Medium | High | Tổ chức skill thành steps rõ ràng, numbered; dùng headers |
| Research mode tốn quá nhiều token | Low | Medium | Document rõ trade-off; fast mode là default |
| Quality gate quá strict làm skill stuck | Low | Medium | Gate chỉ check cấu trúc, không check chất lượng nội dung |
| Spec phase nhận quá nhiều context, confuse agent | Low | Low | Section thứ tự logic, Executive Summary tóm tắt ở đầu |

---

## Testing Strategy

**Manual test — fast mode:**
1. Chạy `/c4flow:run "app quản lý chi tiêu cho sinh viên"` (không flag)
2. Kiểm tra `research.md` có đủ 16 sections
3. Kiểm tra disclaimer có ở đầu
4. Kiểm tra Feature Comparison có ≥10 rows, ≥4 columns competitor

**Manual test — research mode:**
1. Chạy `/c4flow:run "app quản lý chi tiêu cho sinh viên" --research`
2. Kiểm tra Sources section có URLs
3. Kiểm tra không có disclaimer
4. Kiểm tra data có sources hoặc `[estimate]`

**Regression test:**
- Spec phase vẫn đọc được `research.md` và generate proposal.md bình thường
- Orchestrator state transition RESEARCH → SPEC vẫn hoạt động

---

## Files cần thay đổi

| File | Loại thay đổi |
|------|--------------|
| `skills/research/SKILL.md` | Viết lại hoàn toàn — merge market-research layers + C4Flow technical research |
| `references/spec-templates/research-template.md` | Mở rộng: thêm 7 sections mới (Business Domain, Feature Comparison, Gap Analysis, Differentiation, MVP Scope, Executive Summary, Sources) |
| Orchestrator file (chứa logic dispatch sub-agent) | Sửa nhỏ: đọc `--research` flag, truyền `Mode:` vào sub-agent prompt |

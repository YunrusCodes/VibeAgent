# 修法紀錄 `__amendments`

本 skill 自身引導層的修改史。對應 `five-layer-agent` 的 H-12（append-only）與 H-13（排除壓縮）。

**規則**

- append-only。既有條目不得改寫或刪除；更正靠新增條目並註明它取代誰。
- `from_version` 恆為創建版 `v1`，不是上一版。逐次審查一定會通過，累積審查才擋得下來。
- `loosen` / `retarget` 的 `worst_case` 必填**且必須由人類撰寫**。agent 不得代擬。
- `tighten` / `clarify` 可自動套用；`loosen` / `retarget` 需人類明確簽署。

---

## 累積狀態（對照創建版 v1）

| direction | 次數 |
|---|---|
| loosen | 0 |
| retarget | 0 |
| tighten | 0 |
| clarify | 3 |

**有效權限變化**：無。**條文文字變化**：無（A-1 至 A-3 皆為識別碼、路徑與職責歸屬，未動任何條文語意）。

---

## A-0 — 創建

- **日期**：2026-08-27
- **direction**：創建版，非修法
- **依據**：三個手寫案例——科普帳號（15 subagent / 3 編制 / 2 meta）、記帳（3 subagent）、花園澆灌（4 subagent）。R1–R12 是從這三題實際的推導過程反推出來的，不是先驗設計。
- **內容**：R1–R12 產生式規則、M-1…M-3、F-1…F-7、10 條反例、編制稽核清單、系統規格模板。
- **依賴**：`five-layer-agent v1` 的 H-1…H-13，全部繼承，不放副本。

---

## 未決事項（人類決定，agent 不得代決）

### 一、H-14 候選條文 — **已關閉（已簽署併入 five-layer-agent，2026-08-27，見其 A-8）**

原候選內容留存如下（花園澆灌案跑出來的新規則）：

```
[H-14] require | scope: dispatch | risk: high
  拒絕的同步回傳無接收者時，預設動作為最保守選項。
  「最保守」必須在引導層明確定義，不得由執行期判斷。
  hard_check: default-action-declared
```

**理由**：H-11 要求拒絕「同步回傳 + 非同步留痕」，但那條規則**假設父層存在且會收**。排程執行（半夜三點的澆灌）時無人在場，假設不成立。見 `references/antipatterns.md` A-7。

**注意**：加這條需要同時修改 `five-layer-agent`，屬於跨 skill 的修法。

### 二、`five-layer-agent` 已知缺口 — **已關閉（five-layer A-6，2026-08-27）**

`five-layer-agent` 遞迴節已補為「完整的五層，或一組 subagent 的編制」，`contracts.md` 骨架已註明內部可為編制。兩者現已一致。

### 三、`five-layer-agent` 自我稽核四項 — **已關閉／緩解（five-layer A-10，2026-08-27）**

`guidance-write-gate` 已落地為 PreToolUse hook（`.claude/hooks/guidance-write-gate.ps1`），本 skill 的 M-1 引用的同一機制連帶補上。詳見 `../five-layer-agent/__amendments.md` 未決事項表與 A-10。

### 四、安裝時的目錄命名 — **已關閉（A-1）**

目錄名與 `name` 已對齊為 `agent-composition`，安裝時直接複製即可。

`version` 是非標準 frontmatter 欄位，若載入器抱怨，移到內文。

---

## A-1 — 更名為 `agent-composition`

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：null（識別碼，非條文）
- **觸發**：原名 `meta-agent-factory` 有兩個問題。其一，本 skill 只有時候產出 meta-agent——三個驗證案例中兩個產出的是複合 subagent，名字承諾了它不保證的輸出。其二也是主要理由：與 `sub-agent` 並排時暗示「一個造小的、一個造大的」，**而 meta 不是階層高低，是輸出型別**。名字把已經澄清過的誤解裝了回去。
- **動作**：
  1. frontmatter `name` 改為 `agent-composition`（按產出命名，與 `five-layer-agent` 對稱：一個產出五層，一個產出編制）。
  2. 目錄 `Skills/MetaAgentFactory` → `Skills/agent-composition`，使目錄名等於 `name`。
  3. 同步 `Skills/SubAgentFactory` → `Skills/five-layer-agent`。
  4. 全專案 7 處引用更新。
- **條文語意變動**：無。
- **worst_case**：不適用（非 loosen）。

---

## A-2 — R11 改為委派，消除與 `five-layer-agent` 的重複

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：R11
- **觸發**：R11 原本複製了一份塌縮判準，而判準的正本在 `five-layer-agent`。兩份判準就是版本偏移，與本 skill「不放 H-1…H-13 副本」的原則自相矛盾。
- **動作**：R11 改為「逐個展開，交給 `five-layer-agent`」，只保留填表所需的一句話判準，並明示交接物是**一份引導層 + 它在編制裡的位置**。
- **條文語意變動**：無（判準不變，只改由誰持有正本）。
- **worst_case**：不適用。

---

## A-3 — 跨 skill 引用改可移植路徑，H-15 引用更新

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：依賴宣告、R8（識別碼與路徑，非條文語意）
- **觸發**：外部稽核。其一，本 skill 以 `Skills/five-layer-agent/...` 的專案根路徑引用憲章正本，安裝到 `.claude/skills/` 後全部斷鏈——「不放副本」的代價是路徑必須可移植。其二，`five-layer-agent` A-5 為覆蓋規則指派了凍結 ID [H-15]，本 skill 的引用需跟上。
- **動作**：
  1. `SKILL.md` 與 `references/checker.md` 的跨 skill 路徑全部改為 `../five-layer-agent/...` 相對引用，並註明「安裝時兩者必須一起裝」。
  2. 依賴宣告改為「H-1…H-13 與 H-15」，明示 H-14 為未決候選。
  3. R8 與 `references/antipatterns.md` A-4 的行號引用改指 H-15。
  4. `references/checker.md` 補 M1–M13（檢查項）與 M-1…M-3（條文）的命名空間註記。
- **條文語意變動**：無。
- **worst_case**：不適用（非 loosen）。

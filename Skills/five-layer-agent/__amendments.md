# 修法紀錄 `__amendments`

這個 skill 自身引導層的修改史。對應 [H-12] append-only 與 [H-13] 排除壓縮的同類保存規則。

**規則**

- append-only。既有條目不得改寫或刪除；更正靠新增條目並在新條目註明它取代誰。
- `from_version` 恆為創建版 `v1`，不是上一版（`references/dev-loop.md:42`）。逐次審查一定會通過，累積審查才擋得下來。
- `direction: loosen` 或 `retarget` 者，`worst_case` 必填**且必須由人類撰寫**。agent 不得代擬（`references/report-schema.md:47`）。
- `tighten` / `clarify` 可自動套用；`loosen` / `retarget` 需人類明確簽署（`references/dev-loop.md:36`）。

---

## 累積狀態（對照創建版 v1）

| direction | 次數 |
|---|---|
| loosen | 1（A-9，已簽署，worst_case 待人類補填） |
| retarget | 0 |
| tighten | 2（A-8 新增 H-14；A-10 落地 guidance-write-gate） |
| clarify | 7 |

**有效權限變化**：無新增 grant，未放寬任何 forbid。
**條文文字變化**：A-8 新增 require 條文 [H-14]（收緊）；A-9 將 `RefusalReport.minimal_amendment` 由必填改為可 null（放寬，已由使用者簽署）。其餘七次僅動識別碼、路徑、觸發描述與非規範性骨架。

---

## A-1 — 檔案結構與引用路徑對齊

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：null（結構性，非條文）
- **觸發**：使用者檢視時發現 `SKILL.md` 通篇引用 `references/` 與 `assets/`，但 7 個檔案全部平鋪在根目錄，8 處引用全部無法解析。
- **動作**：建立 `references/` 與 `assets/`，搬入對應檔案；`references/` 內 6 處裸檔名互引改為根目錄基準，與 `SKILL.md` 及 `assets/spec-template.md` 既有慣例統一。
- **條文語意變動**：無。
- **worst_case**：不適用（非 loosen）。

---

## A-2 — 硬約束改用凍結 ID

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：H-1 … H-13（識別碼層級，非條文層級）
- **觸發**：依 `references/checker.md` 自我稽核。13 條硬約束使用序數編號，違反 `references/contracts.md:45`「穩定，跨版本不重用」，也違反 `SKILL.md` 自己對「帶穩定 ID 的版本化產物」的要求。當時共 15 處跨檔引用綁在序數上，在清單中間插入任何一條都會使其全部靜默指錯。
- **動作**：
  1. `1.`–`13.` 改為 `[H-1]`–`[H-13]`，序數與 ID 合一。
  2. `SKILL.md` 硬約束節新增「條目 ID 凍結」規則。
  3. frontmatter 補 `version: v1`，使 `RefusalReport.guidance_version` 有值可填。
  4. 15 處引用改指 ID：`references/antipatterns.md` 9 處、`references/contracts.md` 5 處、`references/report-schema.md` 1 處、`SKILL.md` 1 處。
- **條文語意變動**：無。文字一字未改。
- **worst_case**：不適用（非 loosen）。

---

## 未決事項（人類決定，agent 不得代決）

依 `assets/spec-template.md:128`。以下為自我稽核尚未關閉的發現，**均涉及引導層實質內容，依 G-SELF-1 不得自行套用**。

| # | 發現 | 依據 | 狀態 |
|---|---|---|---|
| 1 | `guidance-write-gate` 只在 `references/dev-loop.md:94` 宣告一次，無定義、無對應 precheck。G-SELF-1 是全套架構唯一保護自身的 high-risk 條目，其 hard_check 懸空 → 依 `references/contracts.md:54`，**本規格目前不合法** | M3 | **已落地（A-10，2026-08-27）**——PreToolUse hook，重啟 session 後生效 |
| 2 | skill 自身的不可逆動作（寫規格檔、改自身引導層）無 allowlist，僅有 G-SELF-1 一條 forbid，是純 denylist | H-5 / J3 | 緩解（A-10）——hook 使每次引導層修改都需人類逐次核准，實質等同法律保留 |
| 3 | G-SELF-1 的 `refused` 無不可重試機制。重複請求即可繞過 | H-8 / M13 | 隨發現 1 關閉——重複請求每次都會再彈人類確認，繞不過 |
| 4 | 五層同處單一 Claude context，不滿足「互相不完整」。實質修正取決於發現 1 是否落地為 hook | J1 | 隨發現 1 關閉——攔截點在 harness（hook），不在 context 內，無法被說服 |

**發現 1 曾是其餘三項的共同前提**，已由 A-10 落地關閉。

---

## A-3 — 修法紀錄接上引導層

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：null（結構性）
- **觸發**：A-1 與 A-2 事後補記時發現，`__amendments.md` 建立後沒有任何檔案指向它。依 `references/report-schema.md:76` 的判準，只存在而不被送達是**留痕不是送達**，父層不去讀，這筆紀錄就是黑洞。
- **動作**：`SKILL.md` 參考檔案節新增 `__amendments.md` 條目，並註明「修改 `SKILL.md` 或 `references/` 之前先讀，改完必須 append」。
- **條文語意變動**：無。
- **worst_case**：不適用（非 loosen）。

---

## A-4 — 收窄觸發描述，讓出多 agent 領域

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：frontmatter `description`（觸發描述，非條文）
- **觸發**：`description` 原本寫「設計、生成、稽核 agent **與 meta agent** 的規格……設計 multi-agent 或 meta agent 系統」。那是本 skill 還是唯一一個 skill 時寫的。`agent-composition` 建立後，多 agent 的拆分與組合已移交該 skill，兩者的觸發條件重疊——使用者說「幫我設計一個 multi-agent 系統」時可能叫錯。
- **動作**：
  1. `description` 收窄為**單一 agent 的內部規格**，並明示「多個 agent 如何拆分、組合、判定拓撲，改用 `agent-composition`」。
  2. 目錄 `Skills/SubAgentFactory` → `Skills/five-layer-agent`，使目錄名等於 `name`，安裝時可直接複製。
- **條文語意變動**：無。H-1…H-13 一字未改，僅縮小觸發範圍。
- **注意**：這是**收窄**（`tighten` 性質的 `clarify`）——本 skill 少接一類請求，不多接。放寬才需要簽署。
- **worst_case**：不適用（非 loosen）。

---

## A-5 — 覆蓋規則指派凍結 ID [H-15]，漂移的行號引用改指 ID

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：覆蓋規則（原無 ID）
- **觸發**：外部稽核發現「L3 不得直接接不可逆動作」是全架構最重要的單一規則（R8 亦複述），卻沒有凍結 ID，跨檔只能用行號引用——而 `SKILL.md:104` 的三處引用（GARDEN-SPEC、agent-composition antipatterns A-4）已因 A-2 插行漂移到 107，正是 A-2 凍結 H-ID 想防止的失敗模式。
- **動作**：
  1. 覆蓋規則標為 **[H-15]**。取 15 不取 14，因 H-14 已被未決候選條文佔用（見 agent-composition `__amendments.md`）；依 ID 凍結規則，候選編號一經公開即不重用。
  2. `SKILL.md` 硬約束節新增「目前已指派」清單，明示 H-14 保留中。
  3. 三處行號引用改指 H-15；`SUBAGENTS.md`、`LEDGER-SPEC.md` 另兩處漂移行號改為節名引用。
- **條文語意變動**：無。條文一字未改，僅指派識別碼。
- **worst_case**：不適用（非 loosen）。

---

## A-6 — 遞迴描述補全為「五層或編制」，contracts 骨架同步修正

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：null（遞迴節描述與非規範性骨架，非條文）
- **觸發**：agent-composition `__amendments.md` 未決事項二早已標記本 skill「從內部看是完整的五層」少了一半，與 `composition.md` 的正本不一致；外部稽核另發現 `contracts.md` 的 `SubAgent` 骨架引用 `env.guidance`，而 `Envelope` 介面只有 `guidance_version: string`，型別對不上。
- **動作**：
  1. 遞迴節改為「完整的五層，**或一組 subagent 的編制**」，並指向 `agent-composition/references/composition.md` 為編制正本。
  2. `contracts.md` `SubAgent` 骨架：父層 `Guidance` 改為建構時顯式傳入（`Envelope` 維持只帶 version），並註明內部可為編制。
- **條文語意變動**：無。narrowing 檢查四項不變。
- **worst_case**：不適用（非 loosen）。

---

## A-7 — 模板語言中立註記、checker 命名空間註記

- **日期**：2026-08-27
- **direction**：`clarify`
- **target_clause**：null（模板與檢查清單，非條文）
- **觸發**：外部稽核。其一，`assets/spec-template.md` 硬編 `.py` 檔名，與 `contracts.md`「實作語言不限」不一致。其二，`references/checker.md` 的檢查項 M1–M13 與 agent-composition 的 meta 條文 M-1…M-3 命名空間相撞，僅靠連字號區分，跨檔引用「M8–M12」時易誤讀。
- **動作**：模板加註「檔名以 Python 為例，實作語言不限」；checker 機械可檢節加命名注意（兩邊 checker 各一份）。
- **條文語意變動**：無。
- **worst_case**：不適用（非 loosen）。

---

## A-8 — 簽署併入 [H-14]

- **日期**：2026-08-27
- **direction**：`tighten`（新增 require 條文）
- **target_clause**：新增 [H-14]
- **簽署**：使用者於本對話明確選擇「簽署併入」。
- **觸發**：花園案 A-7——排程執行時拒絕的同步回傳無人接收，H-11 的「父層存在且會收」假設不成立。候選條文原掛於 `agent-composition/__amendments.md` 未決事項一。
- **動作**：H-14 加入 `SKILL.md` 硬約束「拒絕」節；`agent-composition` 依賴宣告、`ARCHITECTURE.md`、`GARDEN-SPEC.md` 同步更新。
- **worst_case**：不適用（tighten）。

---

## A-9 — `minimal_amendment` 改為可 null

- **日期**：2026-08-27
- **direction**：**`loosen`**（放寬 schema 的必填要求）
- **target_clause**：`references/report-schema.md` 的 `RefusalReport.minimal_amendment`
- **簽署**：使用者於本對話明確選擇「改為可 null」。
- **觸發**：外部稽核發現必填與 `dev-loop.md`「拒絕不預設為缺陷」相斥——第一類拒絕（約束正確、拒絕正確）被迫附修正提案，結構性地把每次拒絕推向「提案改規則」，正是棘輪的方向。
- **動作**：型別改為 `Amendment | null`，`null` 語意明確定義為「第一類拒絕，無需修法」；`blocking_clauses` 非空門檻（H-10）不變。
- **當初放寬的理由**（供日後回收判斷）：反棘輪。若日後發現 null 被濫用為偷懶出口（同一 clause 反覆拒絕卻無提案），應考慮收回。
- **worst_case**：<!-- 依規則必須由人類親筆撰寫，agent 不得代擬。建議思考方向：若第一類分類被濫用，父層失去修正線索的最壞情況是什麼？ -->（**待填**）

---

## A-10 — guidance-write-gate 落地為 PreToolUse hook

- **日期**：2026-08-27
- **direction**：`tighten`（為 G-SELF-1 補上實際存在的 hard_check）
- **target_clause**：G-SELF-1 的 `hard_check: guidance-write-gate`
- **簽署**：使用者於本對話明確選擇「建詢問式 hook」。
- **動作**：`.claude/hooks/guidance-write-gate.ps1` ＋ 專案 `.claude/settings.json` 的 PreToolUse hook（matcher `Edit|Write`）。本專案任何 `SKILL.md` 的修改一律轉為「詢問使用者」——人類簽署從願望變成機制。管道測試通過（正例攔截、反例放行、junction 路徑亦攔）。
- **生效條件**：`.claude/` 於本 session 中途建立，hook 需重啟 session（或開一次 `/hooks`）後生效。
- **連帶**：關閉未決事項 1、3、4，緩解 2（見上表）。
- **worst_case**：不適用（tighten）。

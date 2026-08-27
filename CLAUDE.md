# VibeAgent

用兩個 skill 實現「規劃並製造一組小 agent，組成系統達成複雜抽象目標」：

- **`five-layer-agent`** — 產出**單一** agent 的內部規格（引導/調度/邊界/演算/資料五層）
- **`agent-composition`** — 把需求拆成 subagent **編制**（憲章＋拓撲＋budget），再逐個交回 five-layer-agent 展開

正本在 `Skills/`；`.claude/skills/` 底下是 **junction 目錄連結**（不是複本），讓本專案的 session 自動載入。**不要複製出第二份，不要動連結。**

## 憲章狀態（2026-08-27）

- 硬約束 **H-1…H-15** 全部已簽署生效（H-14、H-15 於 2026-08-27 併入）。條目 ID 凍結，跨檔引用一律用 ID 不用行號。
- `RefusalReport.minimal_amendment` 已改為可 null（null＝第一類拒絕，見 report-schema.md）。
- **待使用者補填**：`Skills/five-layer-agent/__amendments.md` A-9 的 `worst_case` 欄（依規則 agent 不得代擬）。

## 修法協議（改 skill 前必讀）

1. 修改任何 `SKILL.md` 或 `references/` 之前，先讀該 skill 的 `__amendments.md`；改完**必須 append** 一筆紀錄。
2. `tighten`/`clarify` 可自行套用；**`loosen`/`retarget` 必須使用者明確簽署**，且 `worst_case` 由使用者親筆填寫。
3. `.claude/settings.json` 掛了 **guidance-write-gate** hook（`.claude/hooks/guidance-write-gate.ps1`）：對本專案任何 `SKILL.md` 的 Edit/Write 一律彈出使用者確認。這是 G-SELF-1 的 hard_check 落地。若 hook 沒觸發，請使用者重啟 session 或開一次 `/hooks` 重載設定。

## 測試指引（接手 session 要做的事）

現階段目標是**在本目錄內測試這兩個 skill**，驗證它們可用、觸發正確、產出合規：

1. **觸發測試**——確認 description 分流正確：
   - 「幫我設計一個 agent」／單一 agent 護欄、權限問題 → 應觸發 `five-layer-agent`
   - 「幫我拆成幾個 agent」／多 agent 系統、拓撲 → 應觸發 `agent-composition`
2. **生成測試**——拿一個新題目（不要用科普帳號/記帳/花園三個舊案）走模式 A，產出後用 `references/checker.md` 自我稽核，確認：R2 風險判定先行、張力對有拆、L3→不可逆路徑有關卡、不可逆動作有 grant＋idempotency＋數值上界。
3. **稽核測試**——把 `GARDEN-SPEC.md` 或 `LEDGER-SPEC.md` 餵給模式 B，看能否穩定重現已知發現（輸出格式必須是「違反條號＋位置＋最小修正」）。
4. **交接測試**——用 agent-composition 拆完後，確認 R11 的交接物（一份引導層＋編制位置）能被 five-layer-agent 接住展開。

已知落地缺口（測試時不要誤判為 bug）：checker 的機械檢查（M1–M13、E1–E9、F 系列）目前只是清單，**尚未寫成可執行的測試**；contracts.md 的 runtime 介面尚無實作。

## 邊界

- 一切留在本目錄。**不要**寫入 `~/.claude`（使用者層級設定/skill），**不要**建立帳號層級的記憶或全域 hook。
- 三份案例規格（`SUBAGENTS.md`、`GARDEN-SPEC.md`、`LEDGER-SPEC.md`）是驗證素材，各自的「未決事項」節屬使用者決定，agent 不得代決。

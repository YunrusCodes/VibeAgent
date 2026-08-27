# 記帳 Agent 規格

> 題目二。一句話＋一張圖 → 當日消費與熱量。
> 依 `Skills/five-layer-agent/assets/spec-template.md` 產出。**未定案**——第 9 節待你決定。

---

## 1. 分層決策

| 層 | 保留 | 理由 |
|---|---|---|
| 引導 | 是 | 恆真 |
| 調度 | **塌縮** | 單一固定流程，退化為一個函式 |
| 邊界 | 是（極小） | 有一個不可逆動作 `append-entry` |
| 演算 | 是 | 解析與估算為 L2 |
| 資料 | 是 | **本系統的核心**，帳本即產品 |

最高確定性等級：**L2**
權力分立是否必要：**是**（任一單元 ≥ L2）
子 agent：**無**。meta-agent：**無**——每次同一批角色、同一組權限，不符動態組閣判準。

---

## 2. 唯一真正的風險

> 看不清照片，猜一個熱量，寫進去，不告訴你那是猜的。

`SKILL.md`「每層放 LLM 的代價不對稱」表：資料層放 LLM 的失敗模式是**靜默污染真相來源**，高危。錯誤不可觀測——三個月後打開帳本，數字不會告訴你哪些是量的、哪些是猜的。

整份規格繞著一條約束建：**每筆數字必須帶來源與信心度，估算不得偽裝成測量。**

---

## 3. 引導層

版本：`v1`（創建版，此後所有 diff 對照此版）

目標：把一句話與一張圖轉成一筆可信的記錄，並回報當日累計。

| ID | kind | risk | 條文 | scope | hard_check |
|---|---|---|---|---|---|
| C-1 | grant | high | 可 append 記錄至帳本 | boundary | `entry-fields-complete` |
| C-2 | forbid | high | 不得修改或刪除既有記錄，更正僅能以 `annotate` 疊加 | all | `store-no-update-delete` |
| C-3 | forbid | high | 不得寫入缺 `basis` 或 `confidence` 的記錄 | boundary | `entry-fields-complete` |
| C-4 | require | high | `confidence` 低於閾值必須反問，不得逕自寫入 | compute | `confidence-gate` |
| C-5 | forbid | high | 不得推測未經確認的攝取事件 | compute | `ingestion-requires-flag` |
| C-6 | forbid | **low** | 不得提供營養或減重建議，只報數字 | all | — |

**C-6 標為 low 是刻意的。** 它配不出有效硬檢查（關鍵詞黑名單擋不住換句話說），而依 `contracts.md:58`，配不出硬檢查的 high 條目只是願望。此處輸出僅對使用者本人、後果可逆，故依 H-5 用 denylist，不假裝它被擋住了。

---

## 4. 邊界層

| action_id | reversible | idempotency_key | precheck（純函式） | 對應 grant |
|---|---|---|---|---|
| `append-entry` | **false** | `date + hash(input)` | 欄位齊全；`basis ∈ {使用者明說, 包裝標示, 資料庫查表, 模型估算}`；`confidence` 為數值；若含攝取事件則 `eaten == true` | C-1 |

`precheck` 不含模型呼叫。**這是整個系統唯一能改變狀態的地方**，所以硬檢查全部集中在此。

budget：`boundary_calls` 設**寬鬆日上限**（數值見未決事項 5），單次呼叫只能寫一筆。原寫「無日上限」不合規——R3／E6 要求每個不可逆動作有不依賴理解能力的數值上界，上界的用途不是限制記帳，是擋住失控迴圈。

---

## 5. 演算層

| unit_id | level | input | output | proposed_writes |
|---|---|---|---|---|
| `parse` | **L2** | 一句話 + 圖 | `Intent{items[], amount?, eaten}` | — |
| `estimate` | **L2** | item | `{kcal, basis, confidence}` | — |
| `summarize` | **L0** | date | `{spend, kcal, pending[]}` | — |

無狀態，無 store handle。L2 兩者輸出皆 schema 化。

**`summarize` 是 L0**：加總不需要理解能力。放 LLM 進去只會讓結果不可重播。

**`parse` 與 `estimate` 分開**，是為了讓 `estimate` 將來能從 L2 降級成 L1（查營養資料庫）。分開才降得動。

---

## 6. 資料層

| key | 內容 | 壽命 | 可壓縮 |
|---|---|---|---|
| `__entries` | 帳本 | 永久 | **否** |
| `__pending` | 待確認的攝取事件 | 至結清 | **否** |
| `__annotations` | 更正疊加 | 永久 | **否** |
| `__refusals` | 拒絕紀錄 | 永久 | **否** |

介面只有 `read` / `append` / `annotate`。**沒有 `update`，沒有 `delete`。**

### 消費與攝取解耦

「是否馬上吃」把一筆事件拆成兩個時間點：

```
消費事件   付錢時      金額確定
攝取事件   吃的時候    熱量確定
```

沒有這個問題，系統必須推測「買了咖啡＝喝了咖啡」。**用一個問題換掉一次猜測**——而猜測正是第 2 節那個唯一風險的來源。

買了沒吃 → 只記消費，熱量進 `__pending`。

---

## 7. 調度層（塌縮）

```
parse → estimate
      → confidence < 閾值？ ── 是 ──→ 反問使用者（不寫入）
                            └─ 否 ──→ append-entry（precheck → execute）
      → summarize（查詢時才跑）
```

無 `Decision` 型別，因為只有一條路徑。若之後出現分支，此節須展開為完整調度層。

---

## 8. 反向通道與監控

| 通道 | 觸發 | 去向 |
|---|---|---|
| 調度 → 引導 | `confidence` 反覆過低 | `RefusalReport` |
| 邊界 → 引導 | `append-entry` 攔截數 | 統計告警 |
| 引導 → 開發期 | 任何 `loosen` 提案 | 人類簽署 |

| 指標 | 意義 | 閾值 |
|---|---|---|
| `basis == 模型估算` 佔比 | 越高代表帳本越不可信 | 持續上升即異常 |
| **反問率歸零** | **可能不是變準了，而是閾值被調鬆** | **紅旗** |
| `append-entry` 攔截數 | 調度層失職 | > 0 即異常 |

第二項是 `report-schema.md:86`「拒絕率突然歸零」在本題的形式。

---

## 9. 未決事項（你決定，agent 不得代決）

1. **`__pending` 結清策略**——三選一：
   - 系統之後主動追問（最完整，但變成會騷擾你的 agent）
   - 下次記帳時順帶確認（折衷）
   - 過期即作廢（最誠實，但會漏）
2. **`confidence` 閾值定多少。** 這是唯一會影響使用體驗的參數：閾值高＝照片模糊時系統會問你，而不是給你一個好看的數字。**這題的品質完全取決於你願不願意接受這種摩擦。**
3. **C-6 是否升為 high。** 若要升，必須同時給出有效的 hard_check，否則它只是願望。
4. **哪些條文永遠不可 `loosen`。** 建議至少 C-2、C-3。
5. **`append-entry` 的日上限數值。** R3／E6 要求不可逆動作有數值上界。建議取正常使用永遠碰不到的寬鬆值（如 50 筆/日）——正常人不會一天記 50 筆，但失控的迴圈會。

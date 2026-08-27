# Agent 規格模板

產出時照這個結構。**每一節都要能對應到實際的檔案與函式簽章**——對應不上的就是心智模型不是架構，重寫。各節檔名以 Python 為例；實作語言不限（`references/contracts.md`）。

塌縮掉的層直接刪掉整節，並在「分層決策」註明原因。引導層永不刪除。

---

# <agent-name>

## 分層決策

| 層 | 保留 | 理由 |
|---|---|---|
| 引導 | 是 | 恆真 |
| 調度 | 是/塌縮 | |
| 邊界 | 是/塌縮 | |
| 演算 | 是 | |
| 資料 | 是/省略 | |

最高確定性等級：L<n>
權力分立是否必要：<是／否，判準為任一單元 ≥ L2>

---

## 引導層

版本：`v1`（創建版，此後所有 diff 對照此版）

目標：<一句話>

| ID | kind | risk | 條文 | scope | hard_check |
|---|---|---|---|---|---|
| C-1 | grant | high | | boundary | |
| C-2 | forbid | high | | all | |
| C-3 | require | low | | dispatch | |

**檢查**：所有 `risk: high` 的條目都有 `hard_check`。不可逆動作全部以 `grant` 表述（allowlist），不是 `forbid`。

---

## 邊界層

| action_id | reversible | idempotency_key | precheck（確定性） | 對應 grant |
|---|---|---|---|---|
| | | | | C-1 |

`precheck` 必須是純函式，不含模型呼叫。

檔案：`boundary/<action_id>.py`

---

## 演算層

| unit_id | level | input | output | proposed_writes |
|---|---|---|---|---|
| | L2 | | | |

無狀態。無 store handle。L2 以上必須有 schema 化輸出定義。

檔案：`compute/<unit_id>.py`

---

## 資料層

| key | 內容 | 壽命 | 可壓縮 |
|---|---|---|---|
| `__refusals` | 拒絕紀錄 | 永久 | **否** |
| `__amendments` | 修法紀錄 | 永久 | **否** |
| | | | |

介面只有 `read` / `append` / `annotate`。

檔案：`store.py`

---

## 調度層

執行迴圈：

```
step(state, env) → Decision
  ├─ vet(decision, guidance, env)   # 事前自審
  ├─ compute  → unit.run → proposed_writes → store.append
  ├─ boundary → precheck → execute
  ├─ done
  └─ refuse   → RefusalReport（同步回傳 + append __refusals）
```

Decision 型別中不得存在「計算結果」選項。

檔案：`dispatch.py`

---

## 子 Agent（若有）

| child_id | 繼承的 forbid | 收窄的 grants | budget | depth 上限 |
|---|---|---|---|---|

narrowing 檢查：M8–M12（見 `references/checker.md`）。回報路徑不受收窄影響。

---

## 反向通道

| 通道 | 觸發條件 | 去向 |
|---|---|---|
| 調度 → 引導 | 目標在現行約束下不可達 | `RefusalReport` |
| 邊界 → 引導 | 同一 action 攔截數 > 閾值 | 統計告警 |
| 引導 → 開發期 | 任何 `loosen` 提案 | 人類簽署 |

---

## 監控

| 指標 | 意義 | 閾值 |
|---|---|---|
| 邊界攔截數 | 調度層失職 | > 0 即異常 |
| 同一 clause 拒絕次數 | 規範與現實脫節 | |
| 拒絕率歸零 | **可能是護欄已被架空** | 紅旗 |

---

## 未決事項

<列出需要人類決定、agent 不得代決的項目。至少包含所有 `loosen` 提案的 `worst_case`。>

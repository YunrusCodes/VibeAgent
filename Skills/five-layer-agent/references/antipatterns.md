# 反例庫

每個案例都是「看起來對但錯」。正面規則的遵守率遠低於對具體反例的辨識率，所以生成與稽核時都掃一遍這份。

格式：**設計 → 錯在哪 → 修正 → 違反的硬約束**

---

## 1. 工具同時計算與寫檔

```python
def analyze_and_save(data):
    result = heavy_analysis(data)
    open("report.txt", "w").write(result)   # ← 副作用混在演算裡
    return result
```

**錯在哪**：這個單元同時是演算層與邊界層。它不可重播（重跑會覆蓋檔案），也無法被授權系統管理——`grants` 檢查看不到這個寫入。

**修正**：拆成 `analyze` 演算單元回傳 `result`，與 `save_report` 邊界動作。由調度層串接。

**違反**：H-4、H-5

---

## 2. 演算單元自己快取

```python
class Summarizer:
    def __init__(self):
        self.cache = {}          # ← 跨呼叫狀態藏在演算層
    def run(self, text):
        ...
```

**錯在哪**：狀態不在資料層，導致無法重播、無法測試、換模型時行為漂移，而且 `__refusals` 之類的稽核紀錄看不到它。

**修正**：cache 走 `proposed_writes` 回資料層，由調度層決定落盤；讀取時由調度層從資料層取出後當作 input 傳入。

**違反**：H-1、H-2

---

## 3. 調度層「順便判斷一下」

```python
def step(state, env):
    if llm_says_urgent(state.message):        # ← 未記錄的演算
        return Decision(kind="boundary", action="send_alert", ...)
```

**錯在哪**：`llm_says_urgent` 是一次有變異性的推理，但它不是一個顯式的演算單元——沒有 ID、沒有 level、不在追蹤裡、無法單獨評測。事後看 trace 只會看到「調度層決定發警報」，看不到它為什麼這樣決定。

**修正**：`urgency_classifier` 是 L2 演算單元，`step` 呼叫它、拿到 schema 化輸出、再依輸出決定。

**違反**：H-3

---

## 4. 邊界層用 LLM 判斷該不該放行

```python
def precheck(payload, env):
    return llm_ask("這個轉帳合理嗎？", payload)   # ← 可以被說服
```

**錯在哪**：第二道防線跟第一道用同一種材料。調度層被話術繞過的手法，對這裡一樣有效——你沒有第二道防線，你只有兩個一樣的第一道。

**修正**：`precheck` 是確定性純函式（額度上限、收款人白名單、時間窗）。若確實需要語意判斷，把它做成 L2 演算單元放在調度層之前，硬檢查仍然保留在後面。

**違反**：H-4

---

## 5. 子 agent 直接讀父層記憶

```python
sub = SubAgent(store=self.store)    # ← 共享指標
```

**錯在哪**：巢狀一深就變成全域變數。子 agent 可以讀到與它任務無關的資料，隔離失效；父層也無法確知子層看見了什麼。

**修正**：`SubAgent(input={...})`，顯式傳入需要的片段。子 agent 有自己的 store。

**違反**：遞迴規則

---

## 6. 純 denylist 管理不可逆動作

```
[C-3] forbid: 不得刪除使用者的重要檔案
```

**錯在哪**：「重要」沒有定義，而且窮舉不完——沒禁止的就會被視為可以。模型一定會找到縫，而且找到縫時它是「合規」的。

**修正**：不可逆動作改用 allowlist。邊界層只註冊 `delete_temp_cache` 一個刪除動作，其餘刪除路徑不存在。條文改成 `grant` 而非 `forbid`。

**違反**：H-5

---

## 7. 拒絕被包成例外

```python
raise RefusalError("目標與約束衝突")
```

**錯在哪**：上游的 retry 裝飾器會抓到它並重送。同一個任務被反覆丟回來，模型會逐漸把約束往寬解釋——**重試是逼出違規的最強壓力**。而且這句話沒有引用任何條目 ID，父層無從判斷該修哪裡。

**修正**：回傳 `{kind: "refused", report: RefusalReport}`，`blocking_clauses` 非空，runtime 的重試邏輯顯式跳過 `refused`。

**違反**：H-8、H-10

---

## 8. 拒絕只寫進 log

```python
store.append("__refusals", report)
return None                          # ← 父層看到 None
```

**錯在哪**：留痕不等於送達。父層看到的是一個結束了的子 agent，它會按自己的邏輯繼續走，可能當成成功、可能當成逾時。制衡在遞迴中靜靜斷掉。

**修正**：同步回傳 + 非同步留痕，兩條都要。

**違反**：H-11

---

## 9. LLM 整理記憶

```python
store.set("history", llm_summarize(store.get("history")))   # ← 改寫真相
```

**錯在哪**：它安靜地改寫歷史，而且錯誤不可觀測——之後查到的就是被改過的版本，沒有東西可以對照。如果摘要磨掉了過去的拒絕紀錄，agent 會重新嘗試同一件事，並在第二、三次的壓力下鬆動。

**修正**：`append` 摘要為新條目，原始 log 保留。`__refusals` 與 `__amendments` 完全排除在壓縮外。介面上不提供 `set` / `delete`。

**違反**：H-12、H-13

---

## 10. 高風險條文沒有硬檢查

```
[C-7] forbid | risk: high
不得對外揭露使用者的個人資料
（無 hard_check）
```

**錯在哪**：這是願望不是約束。語意約束只能機率性成立，會被 injection 攻破、被長對話稀釋、被話術繞過。後果不可接受的事不能只靠這個。

**修正**：配一個邊界層檢查——對外訊息經過 PII 掃描，命中即 block。條文填上 `hard_check: pii-egress-scan`。

**違反**：引導層契約（`risk: high` 必須有 `hard_check`）

---

## 11. 子 agent 的引導層重寫

```python
child_guidance = llm_generate_guidance(task)    # ← 憑空生成
```

**錯在哪**：沒有經過 narrowing 檢查，子層可能獲得父層沒有的權限或放寬父層的禁區。巢狀幾層之後最外層的約束已經不存在了。

**修正**：`child_guidance = narrow(parent_guidance, task_scope)`。父層所有 `forbid` 條目必須出現在子層，`grants` 必須是子集，且條目 ID 沿用不重新編號——ID 是對照鍵。

**違反**：遞迴規則 narrowing-only

---

## 12. 每次拒絕都放寬條文

```
v1 → v2: C-3 放寬（子 agent 需要寫暫存檔）
v2 → v3: C-3 再放寬（需要寫設定檔）
v3 → v4: C-3 再放寬（需要寫使用者目錄）
```

**錯在哪**：每一步都有具體理由、都經過人類點頭，但總體上護欄已經消失。逐次審查一定會通過。

**修正**：`loosen` 需人類簽署且必須自己填 `worst_case`；呈遞時附上對照**創建版**的累積 diff，不是對照上一版。並且先問一次：是護欄錯了，還是目標一開始就要求了不該要求的東西？

**違反**：`references/dev-loop.md` 棘輪防制

---

## 13. 為小工具生成完整五層

使用者要一個「把 CSV 轉成圖表」的 agent，產出五個目錄、一份 12 條的引導層、一個空的邊界層。

**錯在哪**：沒有不可逆動作、沒有跨呼叫狀態、單一固定流程——所有單元都在 L0/L1，程式碼本身就是約束，沒有東西需要被制衡。生成這種東西，使用者第二次就不會用了。

**修正**：套用塌縮規則，退回傳統三層。**引導層仍然保留**（它是唯一不可交易的），但可以只有兩三條。

**違反**：塌縮規則

---

## 14. 把橫切關注點做成第六層

```
guidance / dispatch / boundary / compute / data / observability
```

**錯在哪**：可觀測性、權限、預算是**每次跨層呼叫都要帶的東西**，不是一個被呼叫的層。做成層會導致它散落各處，而且它沒有自己的職責邊界——五層都在寫 log。

**修正**：做成 `Envelope`，隨呼叫傳遞。見 `references/contracts.md`。

**違反**：分層原則（層必須通過「它獨自能闖什麼禍」的檢驗，觀測層的答案是「沒有，因為它不是一層」）

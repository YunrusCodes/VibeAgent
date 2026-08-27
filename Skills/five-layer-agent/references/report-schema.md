# 回報物件 Schema

這是唯一被四層碰到的資料結構：調度層產生它、資料層存它、邊界層的攔截統計餵進它、開發期的引導層依它修改。把它定死，其他介面大多會被它反推出來。

## Schema

```ts
interface RefusalReport {
  kind: "refused";              // 三值終止的第三值，不是 error 的子型別

  trace_id: string;
  guidance_version: string;     // 對照開發期原始碼的鍵
  agent_id: string;
  depth: number;                // 遞迴深度，用來定位是哪一層子 agent

  blocked_goal: string;         // 被阻擋的是哪個目標，引用 Guidance.goal 或子目標 ID
  blocking_clauses: string[];   // 條目 ID，非空。空的話這不是 refused，是 failed

  attempted: Attempt[];         // 試過哪些替代路徑
  minimal_amendment: Amendment | null; // 能解除死結的最小修正；null 僅限第一類拒絕（約束正確，無需修法）

  evidence?: {
    boundary_blocks?: { action: string; count: number }[];
  };
}

interface Attempt {
  path: string;                 // 試過的做法
  outcome: "blocked" | "infeasible" | "out_of_budget";
  clause?: string;              // 若 blocked，被哪一條擋住
}

interface Amendment {
  target_clause: string | null; // null 代表提議新增條目
  direction: "loosen" | "tighten" | "clarify" | "retarget";
  proposed_text: string;
  worst_case: string | null;    // 若 loosen，此欄必填，且必須由人類撰寫
}
```

## 為什麼每個欄位都在

**`blocking_clauses` 非空是硬門檻。** 引用不出具體條目的不算拒絕，只算失敗。既然回報永遠被允許、又能乾淨地終止任務，它就是成本最低的結束方式；能力弱或推理預算不足的模型會發現這一點，開始把「有點難」包裝成「有衝突」。這道門檻是唯一擋得住的東西。

**`minimal_amendment` 是整份回報最有價值的部分。** 「我不能做，因為衝突」對父層沒有用，它得自己重新推導一遍。附上最小修正，父層的決策就從「重新設計整個子 agent」降級成「批准或駁回一項具體修正」——這是遞迴系統裡唯一能收斂的形式。行政機關碰到窒礙難行時提的是修正條文，不是一句辦不到。

**但它可為 `null`，且 `null` 是第一類拒絕的正確值。**（2026-08-27 簽署修改，見 `__amendments.md` A-9。）`dev-loop.md` 的第一類——約束正確、拒絕正確——本來就不該產出修法提案；必填會把每一次拒絕都結構性地推向「提案改規則」，正是棘輪的方向。`null` 的語意是「什麼都不用修」，不是「懶得寫」：父層收到 `null` 的正確動作是歸檔，不是追問。判斷屬不屬於第一類仍是開發期的事——agent 對 null 的濫用，會在 `__refusals` 統計裡以「同一 clause 反覆出現卻無提案」的形狀現形。

**`worst_case` 在 `loosen` 時必填，且必須由人類撰寫。** 人類會蓋橡皮圖章，這是可預期的，不是靠提醒能解決的。唯一有效的做法是讓放寬帶有成本——要人動筆的地方，橡皮圖章才蓋不下去。**agent 不得代擬此欄。**

**`direction: "retarget"` 存在，是因為第三類最常被誤判成第二類。** 當目標本身要求了不該做的事，正確的修法是縮小目標，不是拆掉護欄。

## 三值終止

```ts
type Outcome =
  | { kind: "completed"; result: unknown }
  | { kind: "failed";    error: Error; retryable: boolean }
  | { kind: "refused";   report: RefusalReport };
```

多數框架只有成功 / 錯誤兩種。把規範性拒絕塞進任何一種都會壞：

- **塞進 `completed`** → 父層以為做完了，靜默 no-op，錯誤往上游擴散。
- **塞進 `failed`** → 觸發重試邏輯。而**重試一個合法的拒絕，正是逼出違規的最強壓力**。同一個任務被反覆丟回來，模型會逐漸把約束往寬解釋，因為它認定「一定有辦法，是我沒想到」。

`refused` 必須是不可重試的終止態。除非引導層被修改，重送同一個任務只會得到同一個答案——重試沒有意義而且有害。

runtime 的重試邏輯必須顯式檢查 `kind`，不能只看有沒有拋出例外。

## 兩條路都要走

```
同步：Outcome 回傳值走控制流，父層無法錯過
非同步：append 到 __refusals，供稽核與統計
```

內容相同，用途不同。只寫進資料層是**留痕**不是**送達**——父層不去輪詢，這筆紀錄就是黑洞，它只會看到子 agent 結束了，然後按自己的邏輯繼續走，可能當成成功、可能當成逾時。少了同步這條，制衡在遞迴中會靜靜地斷掉。

## 統計訊號

`__refusals` 聚合之後才有意義，單次拒絕大多沒有資訊量。三個值得驚動人類的模式：

| 訊號 | 意義 |
|---|---|
| 同一 `clause_id` 反覆出現 | 規範與現實脫節，該條目要改 |
| `boundary_blocks` 上升 | 調度層的依法行政失效 |
| **拒絕率突然歸零** | 可能不是變乖了，而是約束已被放寬到不會擋到任何東西 |

第三項是驗證單向棘輪有沒有發生的最直接證據，見 `references/dev-loop.md`。

## 保存規則

`__refusals` **排除在記憶壓縮之外**（硬約束 H-13）。如果摘要磨掉了「我曾經拒絕過這件事、理由是這條」，agent 下一輪會重新嘗試同一件事，然後在第二次、第三次的壓力下鬆動。拒絕紀錄的完整保存，是防止長時間運行中約束緩慢腐蝕的必要條件。

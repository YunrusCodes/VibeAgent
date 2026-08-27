# 層間介面契約

規格如果不能對應到函式簽章，它就不是架構。這份文件定義最小可實作的介面。

語言用 TypeScript 型別表示，實作語言不限。

## Context Envelope

橫切關注點（權限、追蹤、預算）不是層，是**每次跨層呼叫都要帶的信封**。把它們做成層會導致它們散落在各處。

```ts
interface Envelope {
  trace_id: string;        // 貫穿整條呼叫鏈，含子 agent
  span_id: string;         // 這一次呼叫
  parent_span?: string;

  guidance_version: string; // 當下生效的引導層版本，拒絕時要引用
  depth: number;            // 遞迴深度，用來擋無限巢狀

  budget: {                 // 遞減，不可由子層放大
    tokens?: number;
    wall_ms?: number;
    boundary_calls?: number; // 對外動作次數上限，最有效的一道
  };

  grants: string[];         // 本次授權的邊界動作 ID，allowlist
}
```

**budget 與 grants 只能遞減。** 子層拿到的信封必須是父層的子集。這是 narrowing-only 在執行期的具體形式，而且它是機械可檢查的，不需要 LLM 判斷。

## 引導層

不是程式，是**版本化、帶 ID 的條文集**。

```ts
interface Guidance {
  version: string;
  goal: string;               // 一句話，這個 agent 存在的理由

  clauses: Clause[];
}

interface Clause {
  id: string;                 // 穩定，跨版本不重用。拒絕時引用這個
  kind: "forbid" | "require" | "grant";
  text: string;               // 人類可讀，也是餵給 LLM 的那份
  scope: Layer[];             // 這條約束哪幾層
  hard_check?: string;        // 對應的邊界層硬檢查 ID
  risk: "low" | "high";       // high 者必須有 hard_check
}
```

**硬規則：`risk: "high"` 且沒有 `hard_check` 的條目，規格不合法。**

引導層是五層裡唯一無法用執行來驗證的——腳本可以測試，資料可以查詢，副作用可以稽核，語意約束只能機率性成立。所以每一條後果不可接受的約束，都必須在邊界層有一個對應的硬性檢查。引導層說「不要刪除使用者資料」，邊界層就要有 delete 的白名單；引導層說「金額超過 X 要先問」，邊界層就要有一道 gate。

**沒有硬性配對的高風險條目，本質上是願望，不是約束。**

## 調度層

```ts
interface Dispatcher {
  step(state: StateView, env: Envelope): Promise<Decision>;
}

type Decision =
  | { kind: "compute";  unit: string; input: unknown }
  | { kind: "boundary"; action: string; payload: unknown; grant: string }
  | { kind: "done";     result: unknown }
  | { kind: "refuse";   report: RefusalReport };   // 見 references/report-schema.md
```

`step` 回傳**意圖**，不直接執行。執行由外層 runtime 做。這樣才擋得住硬約束 H-3（調度層不做運算）——它的回傳型別裡根本沒有「計算結果」這個選項。

`kind: "boundary"` 必須帶 `grant`，而且 `grant` 必須在 `env.grants` 裡。這是法律保留在型別層級的實現：**拿不出授權就編不出合法的 Decision。**

### 依法行政

`step` 內部在產生 Decision 之前要先自審。實作上是一個顯式的檢查函式，不是「模型應該會注意」：

```ts
function vet(d: Decision, g: Guidance, env: Envelope): "ok" | Clause[]
```

回傳被違反的條目。非空就不得送出，改為 `refuse`。

注意：這是**守法**，不是**認定**。事後的違規認定必須由看不到調度層推理過程的獨立單元執行，否則它會替自己的行為找理由——模型合理化的能力遠強於誠實承認錯誤。

## 邊界層

```ts
interface BoundaryAction {
  id: string;
  reversible: boolean;
  idempotency_key?: string;

  precheck(payload: unknown, env: Envelope): "pass" | "block";  // 純函式，不得含 LLM
  execute(payload: unknown, env: Envelope): Promise<unknown>;
}
```

`precheck` 必須是**確定性純函式**。這是它唯一的優點——無法被說服。一旦裡面放了模型，它就跟調度層一樣可以被話術繞過，那就沒有第二道防線了。

`reversible: false` 的動作必須有 `idempotency_key`，否則重試會造成重複副作用。

每次 `precheck` 回傳 `block` 都要記錄。**這個計數是調度層的失職指標，不是邊界層的績效。**

## 演算層

```ts
interface ComputeUnit {
  id: string;
  level: 0 | 1 | 2 | 3;              // 確定性階梯
  run(input: unknown, env: Envelope): Promise<ComputeResult>;
}

interface ComputeResult {
  output: unknown;
  proposed_writes?: Write[];          // 建議，不是執行
}
```

沒有 `state` 欄位，這是刻意的——硬約束 H-1。任何跨呼叫的狀態必須經由 `proposed_writes` 回到調度層，由調度層決定落盤。

`proposed_writes` 而非直接寫入，是硬約束 H-2。演算層拿不到資料層的 handle。

## 資料層

```ts
interface Store {
  read(key: string, env: Envelope): Promise<unknown>;
  append(key: string, value: unknown, env: Envelope): Promise<void>;
  annotate(key: string, note: unknown, env: Envelope): Promise<void>;
}
```

**沒有 `update`，沒有 `delete`。** 這是硬約束 H-12 在型別層級的實現。修正靠 `annotate` 疊加，不是改寫。

保留鍵：`__refusals`（拒絕紀錄，永不參與壓縮）、`__amendments`（修法紀錄）。

## 子 Agent 作為演算單元

遞迴的具體形式：

```ts
class SubAgent implements ComputeUnit {
  level = 3;

  // 父層 Guidance 於建構時顯式傳入。Envelope 只帶 guidance_version（對照鍵），
  // 不帶 Guidance 本體——需要本體的地方必須顯式持有，不從信封裡撈。
  constructor(private parentGuidance: Guidance, private guidance: Guidance) {}

  async run(input: unknown, env: Envelope): Promise<ComputeResult> {
    const childEnv = narrow(env, this.grants, this.budget);
    const childGuidance = narrowGuidance(this.parentGuidance, this.guidance);
    // 子 agent 內部是完整五層，資料層獨立。
    // 內部也可以是一組編制（憲章 + 拓撲 + budget）而非單體五層，
    // 見 agent-composition 的 references/composition.md——narrowing 檢查不變。
  }
}
```

從父層看，它就是一個 `ComputeUnit`，簽章跟一個純函式沒有差別。從內部看，它是完整的系統——單體五層，或一組編制。

### narrowing 的機械式檢查

這四項不需要 LLM 判斷，寫成單元測試：

1. `child.grants ⊆ parent.grants`
2. `child.budget[k] ≤ parent.budget[k]` 對所有 k
3. 父層所有 `kind: "forbid"` 的條目，都出現在子層（可以更嚴，不可以更鬆）
4. `child.depth = parent.depth + 1`，且有上限

**唯一例外**：回報路徑永遠可用，`grants` 收窄不影響它（硬約束 H-9）。

檢查 3 只能擋住「條目被刪掉」，擋不住「條文被改弱」。文字層級的放寬需要人類審查，見 `references/dev-loop.md`。

## 呼叫順序

一次完整的迴圈：

```
runtime → dispatcher.step(state, env)
        → vet(decision, guidance, env)          // 事前自審
        → 若 refuse: 寫 __refusals + 同步回傳    // 兩條路都要
        → 若 compute: unit.run() → proposed_writes → store.append()
        → 若 boundary: precheck() → execute()   // block 則計數並回到 step
        → 迴圈直到 done / refuse / budget 耗盡
```

budget 耗盡是 `failed` 不是 `refused`——它不是規範性拒絕，可以重試。

# guidance-write-gate — G-SELF-1 的 hard_check 落地
# five-layer-agent 引導層規定：引導層（SKILL.md）的修改提案一律 refused 給人類。
# 本 hook 把「人類簽署」變成機制：對本專案任何 SKILL.md 的 Edit/Write，
# 一律轉為 "ask" —— 由使用者當場核准或駁回，任何權限模式下都攔。
$raw = [Console]::In.ReadToEnd()
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$p = $payload.tool_input.file_path
if (-not $p) { exit 0 }
if (($p -replace '\\', '/') -match '/SKILL\.md$') {
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'ask'
            permissionDecisionReason = 'guidance-write-gate (G-SELF-1)：這是引導層修改，需要人類當場簽署。核准前請確認 __amendments.md 會同步 append，且 loosen/retarget 已有人類填寫 worst_case。'
        }
    } | ConvertTo-Json -Depth 5 -Compress
    Write-Output $out
}
exit 0

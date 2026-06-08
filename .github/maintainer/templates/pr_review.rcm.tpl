name = "PR Review ({{REPO}}#{{PR_NUMBER}})"

model kimi-k2-6 {
    protocol = "openai"
    endpoint = "https://api.kimi.com/coding/v1"
    credentials = { env = "KIMI_CODING_API_KEY" }
    headers = { User-Agent = "KimiCLI/1.5" }
    limit = { context = "262144", output = "32768" }
    modalities = { input = ["text"], output = ["text"] }
    thinking = "true"
}

graph {
    accelerator meta {
        purpose = "拉取 PR #{{PR_NUMBER}} 来自 {{REPO}} 的元数据:执行 `gh pr view {{PR_NUMBER}} --repo {{REPO}} --json number,title,body,author,additions,deletions,changedFiles,files,labels,baseRefName,headRefName`。输出紧凑的 PR 描述(标题/作者/目标),以及逐文件清单(path | +增 | -删)与变更总行数——这是后续 diff 预算的依据。只读,不改任何文件,不发评论。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator diff_review {
        purpose = "审查 PR #{{PR_NUMBER}} 的代码改动。diff 是用来定位的,不要把全量 diff 倒进上下文:\n- 若 meta 给出的变更总行数 ≤ 1500,执行 `gh pr diff {{PR_NUMBER}} --repo {{REPO}}` 看全量;\n- 若超过 1500,只挑风险最高的文件深入:用 `gh api repos/{{REPO}}/pulls/{{PR_NUMBER}}/files --paginate --jq '.[] | {filename, additions, deletions, status}'` 定位重点文件,对它们取 patch,其余写明\"已省略(N 个文件 / M 行)\"。\n工作目录已 checkout 到本 PR 的代码,**用 fs 按需读取任意文件来核对 diff 是否合理**:读 hunk 周围的完整函数、追到调用点、确认是否有对应测试。\n评估并给出带依据(文件:行 / 函数)的结论:1) 正确性可疑点(逻辑 / 边界 / 错误处理);2) 测试覆盖(逻辑变更但无 tests 为 risk);3) 安全嗅探(SwiftUI 权限 / 强制解包 / UserDefaults 存密钥 / WebView 渲染用户内容);4) 不符合项目约定(命名、架构、并发标注)。只读,不改文件,不发评论。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell", "fs"]
    }

    accelerator intent_check {
        purpose = "判断 PR #{{PR_NUMBER}} 的**目标是否成立、是否真的达成**。依据 meta 的标题/正文(声称要做什么)+ diff_review 的改动结论(实际做了什么):\n1) 目标是否清晰合理(说清了 why,还是只有 what);\n2) 改动是否确实实现了该目标(有没有声称却没做的部分);\n3) 是否有范围漂移(夹带与目标无关的改动);\n4) 有无明显遗漏的配套改动(改了接口却没改调用方 / 文档 / 测试)。可用 fs / gh 进一步核对。\n输出 verdict(目标达成 / 部分达成 / 未达成 / 目标不清)+ 一句话理由 + 关键证据(文件:行)。只读,不改文件,不发评论。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell", "fs"]
    }

    accelerator respond {
        purpose = "综合 diff_review(代码改动结论)与 intent_check(目标是否达成)写一条 review 评论:开头一句总体判断(可合并 / 需调整,并点明目标是否达成);中间用 markdown checklist 列出关键发现(正面 ✓ 负面 ⚠),分「代码质量」与「目标 / 范围」两块;末尾给 1-3 条具体修改建议。中文撰写,代码标识符保持英文。\n发评论只能用带引号 heredoc 经 --body-file 传入,严禁内联 -b——正文里的反引号、$、引号会被 shell 解释甚至注入:\ngh pr comment {{PR_NUMBER}} --repo {{REPO}} --body-file - <<'RCM_BODY'\n<在此写完整评论正文>\nRCM_BODY\n闭合标记 RCM_BODY 必须独占一行、行首顶格,且正文里不得出现这一行。\n发完必须自检确实发出去了:1) 上面命令要 exit 0 并打印评论 URL;2) 再跑 `gh pr view {{PR_NUMBER}} --repo {{REPO}} --json comments` 确认出现了本评论。如果没发出去,重试。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    flux meta_to_diff {
        channel = context
        mode = digest
        arity = 1
    }

    flux meta_diff_to_intent {
        channel = context
        mode = digest
        arity = 2
    }

    flux diff_intent_to_respond {
        channel = context
        mode = digest
        arity = 2
    }

    meta.context -> meta_to_diff.slot(0)
    meta_to_diff.out -> diff_review.context
    meta.done -> diff_review.trigger

    meta.context -> meta_diff_to_intent.slot(0)
    diff_review.context -> meta_diff_to_intent.slot(1)
    diff_review.done -> intent_check.trigger
    meta_diff_to_intent.out -> intent_check.context

    diff_review.context -> diff_intent_to_respond.slot(0)
    intent_check.context -> diff_intent_to_respond.slot(1)
    intent_check.done -> respond.trigger
    diff_intent_to_respond.out -> respond.context

    respond.done -> output.done
    respond.context -> output.context
    respond.purpose -> output.purpose
}

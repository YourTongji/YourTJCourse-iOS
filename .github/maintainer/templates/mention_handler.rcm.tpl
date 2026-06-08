name = "Mention Handler ({{REPO}} {{TRIGGER_KIND}}#{{TRIGGER_NUMBER}})"

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
    accelerator fetch_thread {
        purpose = "拉取 {{TRIGGER_KIND}} #{{TRIGGER_NUMBER}} from {{REPO}} 的完整 thread:执行 `gh {{TRIGGER_KIND}} view {{TRIGGER_NUMBER}} --repo {{REPO}} --json number,title,body,labels,author,comments`。重点关注触发本次执行的 mention 评论(作者:{{COMMENT_AUTHOR}}, id={{COMMENT_ID}}),其原文为:\"\"\"{{COMMENT_BODY}}\"\"\"。仅 fetch,不要修改任何文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator scan_issues {
        purpose = "从 mention 评论和 thread 内容提炼 3-5 个核心关键词,扫描 {{REPO}} 历史 issues(含 closed)找相关:`gh search issues --repo {{REPO}} --state all <关键词>`。输出 top-5 候选,标注 #编号 | 标题 | state | 与本次 mention 的相关性。若 mention 明显是问候/感谢类无技术含量,直接输出 \"no scan needed\"。不要修改文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator scan_prs {
        purpose = "同样基于关键词,扫描 {{REPO}} 历史 PRs(含 merged)找相关:`gh search prs --repo {{REPO}} --state all <关键词>`。输出 top-5 候选,标注 #编号 | 标题 | state | merged?。重点判断:本次 mention 提到的问题是否已在某个 merged PR 中被 fix。若 mention 无技术含量则输出 \"no scan needed\"。不要修改文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator scan_code {
        purpose = "基于 mention 内容里的代码线索(文件名、函数名、模块名、错误信息),用 find 定位相关源文件,用 fs 读取代码上下文。输出涉及到的关键文件路径 + 关键片段。若 mention 无明显代码指向,输出 \"no scan needed\"。不要修改文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell", "find", "fs"]
    }

    accelerator classify_intent {
        purpose = "综合 fetch_thread + scan_issues + scan_prs + scan_code 的全部结果。输出严格 JSON(不要多余文字):{\"action_kind\": \"comment_only|metadata_edit|code_change|no_action\", \"rationale\": \"中文一句话理由\", \"plan\": \"中文具体步骤,executor 会严格按此执行\"}。判定规则:(1) spam / bot 回环 / 纯感谢 → no_action;(2) 问问题 / 解释 / 指向 dup → comment_only;(3) 要求加 label / close / assignee → metadata_edit;(4) 明确要求修复且不是已知 dup/已 fix → code_change。code_change 必须在 plan 中给出明确的目标文件和修改思路。不调用工具。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = []
    }

    accelerator executor {
        purpose = "读 classify_intent 输出的 JSON。**严格按 plan.action_kind 执行,不得越权**。\n所有评论/正文一律用带引号 heredoc 经 --body-file 传入,严禁内联 -b / --body——正文里的反引号、$、引号会被 shell 解释甚至注入。范式(闭合标记 RCM_BODY 必须独占一行、行首顶格,正文里不得出现这一行):\ngh {{TRIGGER_KIND}} comment {{TRIGGER_NUMBER}} --repo {{REPO}} --body-file - <<'RCM_BODY'\n<在此写完整正文>\nRCM_BODY\n按 action_kind:\n- no_action:直接退出,什么都不做。\n- comment_only:按上面范式发一条评论;禁止 fs/git。\n- metadata_edit:用 `gh {{TRIGGER_KIND}} edit {{TRIGGER_NUMBER}} --repo {{REPO}} ...` 改 label/assignee 等;如需说明再按范式附评论。\n- code_change:按 classify_intent.plan 修改代码。改完后:用 `git diff` 确认改动干净;创建一个新分支 `maintainer/fix-{{TRIGGER_KIND}}-{{TRIGGER_NUMBER}}`;commit + push;用 `gh pr create` 开 PR,标题\"fix: ...\"。开 PR 后发一条评论告知 PR 已创建。\n发完后必须自检。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell", "fs", "find", "git"]
    }

    flux fetch_to_scan_issues {
        channel = context
        mode = digest
        arity = 1
    }

    flux fetch_to_scan_prs {
        channel = context
        mode = digest
        arity = 1
    }

    flux fetch_to_scan_code {
        channel = context
        mode = digest
        arity = 1
    }

    flux scans_to_classify {
        channel = context
        mode = digest
        arity = 4
    }

    flux classify_to_executor {
        channel = context
        mode = digest
        arity = 1
    }

    fetch_thread.context -> fetch_to_scan_issues.slot(0)
    fetch_to_scan_issues.out -> scan_issues.context
    fetch_thread.done -> scan_issues.trigger

    fetch_thread.context -> fetch_to_scan_prs.slot(0)
    fetch_to_scan_prs.out -> scan_prs.context
    fetch_thread.done -> scan_prs.trigger

    fetch_thread.context -> fetch_to_scan_code.slot(0)
    fetch_to_scan_code.out -> scan_code.context
    fetch_thread.done -> scan_code.trigger

    fetch_thread.context -> scans_to_classify.slot(0)
    scan_issues.context -> scans_to_classify.slot(1)
    scan_prs.context -> scans_to_classify.slot(2)
    scan_code.context -> scans_to_classify.slot(3)
    scan_code.done -> classify_intent.trigger
    scans_to_classify.out -> classify_intent.context

    classify_intent.context -> classify_to_executor.slot(0)
    classify_to_executor.out -> executor.context
    classify_intent.done -> executor.trigger

    executor.done -> output.done
    executor.context -> output.context
    executor.purpose -> output.purpose
}

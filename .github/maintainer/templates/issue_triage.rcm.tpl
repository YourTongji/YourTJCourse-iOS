name = "Issue Triage ({{REPO}}#{{ISSUE_NUMBER}})"

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
    accelerator fetch {
        purpose = "拉取 issue #{{ISSUE_NUMBER}} 来自 {{REPO}}:执行 `gh issue view {{ISSUE_NUMBER}} --repo {{REPO}} --json number,title,body,labels,author,createdAt,comments`。汇总 issue 完整内容(含全部评论)。仅 fetch,不要修改任何文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator search_dups {
        purpose = "基于 fetch 阶段拿到的 issue 标题和正文,从 {{REPO}} 搜索历史相关 issue(含 closed)。提炼 3-5 个核心关键词,用 `gh search issues --repo {{REPO}} --state all <关键词>` 查询。输出 top-5 候选,每条标注:#编号 | 标题 | state | 相似度判断(高/中/低)。不要修改任何文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator analyze {
        purpose = "综合 fetch 拿到的 issue 内容和 search_dups 的候选列表。输出严格 JSON(不要多余文字):{\"category\": \"bug|feature|enhancement|question|docs|onboarding|other\", \"priority\": \"P0|P1|P2|P3\", \"duplicates\": [候选 issue 编号数组,无则空], \"suggested_labels\": [标签数组], \"summary\": \"两句中文摘要\"}。不调用工具,不修改文件。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = []
    }

    accelerator respond {
        purpose = "读 analyze 输出的 JSON。\n1) 对 suggested_labels 中每个标签执行 `gh issue edit {{ISSUE_NUMBER}} --repo {{REPO}} --add-label \"<label>\"`(失败多半是标签不存在,忽略继续)。\n2) 发分析评论,只能用带引号 heredoc 经 --body-file 传入,严禁内联 -b——正文里的反引号、$、引号会被 shell 解释甚至注入:\ngh issue comment {{ISSUE_NUMBER}} --repo {{REPO}} --body-file - <<'RCM_BODY'\n<在此写完整评论正文>\nRCM_BODY\n闭合标记 RCM_BODY 必须独占一行、行首顶格,且正文里不得出现这一行。评论中文撰写,含:分类与优先级判断、是否疑似重复(如有 duplicates 列出 #编号 引用)、一句话总结。\n发完必须自检确实发出去了:comment 命令要 exit 0 并打印评论 URL,再跑 `gh issue view {{ISSUE_NUMBER}} --repo {{REPO}} --json comments` 确认出现了本评论。如果没发出去,重试。"
        models = ["kimi-k2-6"]
        policy = "captain"
        tools = ["shell"]
    }

    flux fetch_to_search {
        channel = context
        mode = digest
        arity = 1
    }

    flux fetch_search_to_analyze {
        channel = context
        mode = digest
        arity = 2
    }

    flux analyze_to_respond {
        channel = context
        mode = digest
        arity = 1
    }

    fetch.context -> fetch_to_search.slot(0)
    fetch_to_search.out -> search_dups.context
    fetch.done -> search_dups.trigger

    fetch.context -> fetch_search_to_analyze.slot(0)
    search_dups.context -> fetch_search_to_analyze.slot(1)
    search_dups.done -> analyze.trigger
    fetch_search_to_analyze.out -> analyze.context

    analyze.context -> analyze_to_respond.slot(0)
    analyze_to_respond.out -> respond.context
    analyze.done -> respond.trigger

    respond.done -> output.done
    respond.context -> output.context
    respond.purpose -> output.purpose
}

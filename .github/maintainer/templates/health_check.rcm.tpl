name = "Health Check ({{REPO}})"

model deepseek-v4-flash {
    protocol = "openai"
    endpoint = "https://api.deepseek.com"
    credentials = { env = "DEEPSEEK_API_KEY" }
    limit = { context = "1000000", output = "393216" }
    modalities = { input = ["text"], output = ["text"] }
}

graph {
    accelerator issue_fetcher {
        purpose = "使用 shell 工具执行 gh 命令,获取仓库 {{REPO}} 的 open issues。执行:1) `gh issue list --repo {{REPO}} --state open --limit 50 --json number,title,labels,createdAt,updatedAt,comments,author`;2) 对 issue 数量不超过 10 个的逐个执行 `gh issue view {number} --repo {{REPO}} --json body,comments` 获取详情。汇总所有 issue 信息。不要修改任何文件。"
        models = ["deepseek-v4-flash"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator pr_fetcher {
        purpose = "使用 shell 工具执行 gh 命令,获取仓库 {{REPO}} 的 PRs。执行:1) `gh pr list --repo {{REPO}} --state open --limit 30 --json number,title,author,createdAt,updatedAt,additions,deletions,changedFiles,reviewDecision`;2) `gh pr list --repo {{REPO}} --state merged --limit 10 --json number,title,author,mergedAt`。汇总所有 PR 信息。不要修改任何文件。"
        models = ["deepseek-v4-flash"]
        policy = "captain"
        tools = ["shell"]
    }

    accelerator issue_triage {
        purpose = "阅读上面的 context 中所有 issue 数据。对每个 issue:1) 分类为 bug / feature / enhancement / question / docs / onboarding / other;2) 评估优先级 P0-P3(P0=紧急阻塞, P1=重要, P2=正常, P3=低优先);3) 判断是否 stale(超过30天无更新);4) 标记可能重复的 issues。输出分类后的 issue 列表,按优先级排序。格式:优先级 | #编号 | 标题 | 分类 | 状态。不要修改任何文件。"
        models = ["deepseek-v4-flash"]
        policy = "captain"
        tools = []
    }

    accelerator pr_summary {
        purpose = "阅读上面的 context 中所有 PR 数据。对每个 open PR:1) 总结变更方向(哪个模块/功能);2) 评估规模(小<100行/中<500行/大);3) review 状态(approved/changes-requested/pending);4) 是否长期停滞(>14天无更新)。对最近合并的 PR:总结合并节奏和活跃贡献者。输出 PR 分析报告。不要修改任何文件。"
        models = ["deepseek-v4-flash"]
        policy = "captain"
        tools = []
    }

    accelerator health_report {
        purpose = "阅读上面的 context 中 issue 分类报告和 PR 分析报告。生成项目健康度报告:1) 概览:open issues/PRs 数量、合并节奏;2) 紧急事项:P0/P1 issues + 需要 maintainer 关注的 PRs;3) Issue 健康:stale 比例、分类分布、重复情况;4) PR 健康:review 积压、停滞 PR、可合并 PR;5) 建议行动:maintainer 接下来优先处理什么(最多 5 条具体行动)。中文撰写,技术术语保持英文。不要修改任何文件。"
        models = ["deepseek-v4-flash"]
        policy = "captain"
        tools = []
    }

    flux issue_fetch_to_triage {
        channel = context
        mode = digest
        arity = 1
    }

    flux pr_fetch_to_summary {
        channel = context
        mode = digest
        arity = 1
    }

    flux analysis_to_report {
        channel = context
        mode = digest
        arity = 2
    }

    issue_fetcher.context -> issue_fetch_to_triage.slot(0)
    issue_fetch_to_triage.out -> issue_triage.context
    issue_fetcher.done -> issue_triage.trigger

    pr_fetcher.context -> pr_fetch_to_summary.slot(0)
    pr_fetch_to_summary.out -> pr_summary.context
    pr_fetcher.done -> pr_summary.trigger

    issue_triage.context -> analysis_to_report.slot(0)
    pr_summary.context -> analysis_to_report.slot(1)
    pr_summary.done -> health_report.trigger
    analysis_to_report.out -> health_report.context

    health_report.done -> output.done
    health_report.context -> output.context
    health_report.purpose -> output.purpose
}

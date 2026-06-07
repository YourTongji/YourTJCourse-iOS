# Contributing to YourTJ Course

## Branch Strategy

```
master  ← 稳定发布分支。仅通过 PR 合并，需要 CI 全绿 + 至少 1 人 review。
  ↑
dev     ← 开发集成分支。所有功能分支合入这里，日常 CI 构建目标。
  ↑
feature/*  ← 功能分支。从 dev 拉出，命名：feat/<scope>-<description>
fix/*      ← 修复分支。从 dev 拉出，命名：fix/<scope>-<description>
```

| 分支 | 用途 | 保护 |
|------|------|------|
| `master` | 生产 / TestFlight 分发的代码 | 禁止直接推送，只能从 dev PR 合并 |
| `dev` | 日常开发集成分支 | 禁止直接推送，只能从 feature/fix PR 合并 |
| `feature/*` | 新功能开发 | 无保护，合并后删除 |
| `fix/*` | Bug 修复 | 无保护，合并后删除 |

## 工作流程

1. 从 `dev` 拉出功能分支：`git checkout dev && git pull && git checkout -b feat/catalog-sort`
2. 在功能分支上开发，原子化 commit
3. 功能完成后，**先合并 dev 最新代码**：`git pull origin dev`
4. 推送功能分支并开 PR → `dev`
5. CI 通过后 squash merge 到 `dev`
6. dev 积累足够改动（或到发布周期）时，开 PR → `master`
7. master 合并后打 tag 发布 TestFlight

## Commit Style

遵循 Conventional Commits：

```
feat(scope): short description
fix(scope): short description
refactor(scope): short description
docs(scope): short description
test(scope): short description
chore(scope): short description
```

Scope 参考：`app`, `catalog`, `course`, `review`, `wallet`, `scheduler`, `settings`, `data`, `design`, `platform`, `ci`

## PR Checklist

每次 PR 前对照 `.github/PULL_REQUEST_TEMPLATE.md` 自查。

## Branch Protection（GitHub 设置建议）

前往 Settings → Branches → Add rule:

### `master`
- ✅ Require pull request before merging
- ✅ Require approvals (1)
- ✅ Dismiss stale reviews
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Require conversation resolution first
- Status checks: `CI / lint`, `CI / spm-test`, `CI / build`

### `dev`
- ✅ Require pull request before merging
- ✅ Require status checks to pass (optional, recommended)
- Status checks: `CI / spm-test`, `CI / lint`

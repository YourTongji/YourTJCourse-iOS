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
7. master 合并后按下方「发布流程」打 tag 发布

## 发布流程 (Release)

版本历史以 GitHub Releases 的形式可视化：每个版本一个 `v<version>` tag，
Release 正文包含**分类概要**（便于发给测试做下游验证）和**完整 commit changelog**。

App 二进制由开发者在本地用 Xcode 上传到 App Store Connect；本流程只负责在
GitHub 上记录「每个版本号做了什么」。

发布步骤：

1. 本地修改 `App/Info.plist`：升级 `CFBundleShortVersionString`（如 `1.2.0`）和
   `CFBundleVersion`（构建号），通过 PR **合入 `master`**（发布只能从 `master` 切，
   其 CI 已由分支保护保证为绿）。
2. 本地用 Xcode Archive 并上传同一版本到 App Store Connect 分发。
3. 在 `master` 上确认发布，打 tag 并推送（tag 不受分支保护限制）：

   ```bash
   scripts/release.sh          # 用 Info.plist 中的版本号打 v<version> 并推送
   # 或显式校验：scripts/release.sh 1.2.0
   ```

   也可以在 GitHub 上手动触发：**Actions → Release → Run workflow**（自动读取
   `App/Info.plist` 的版本号）。

4. `Release` workflow 会校验 tag 与 `Info.plist` 版本一致，生成发布说明，并发布
   GitHub Release。可在 **Actions → Release** 的运行摘要中预览同样的正文。

发布说明由 `scripts/release-notes.sh` 生成（按 Conventional Commit 类型归类），
本地可预览：

```bash
scripts/release-notes.sh 1.2.0 v1.2.0
```

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
- Status checks: `CI / SwiftLint`, `CI / SPM Tests`, `CI / Build App`

### `dev`
- ✅ Require pull request before merging
- ✅ Require status checks to pass (optional, recommended)
- Status checks: `CI / spm-test`, `CI / lint`

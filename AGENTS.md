# AGENTS.md — YOURTJ 选课社区 · iOS 客户端

本文件编码本仓库的开发规则。所有 AI 代理在编辑此代码库时必须遵守这些约定。除非用户明确指示，不得覆盖。

## 项目定位

- **YOURTJ 选课社区原生 iOS 客户端**（Swift / SwiftUI，Liquid Glass 设计）
- **纯前端消费者**：直接调用 Cloudflare Workers 后端，不自带服务端
- 后端仓库同级：`../YourTJCourse-Serverless/`（API：`docs/api.md`，DB：`docs/database.md`，立项书：`docs/ios-app-proposal.md`）

## 技术栈

| 维度 | 选型 |
|---|---|
| 语言 | Swift 6（strict concurrency） |
| UI | SwiftUI，iOS 18+（iOS 26 Liquid Glass 用 `#available` 回退） |
| 状态 | `@Observable` + `@Environment`，MV 模式 |
| 异步 | Swift Concurrency（async/await、actor、`@MainActor`） |
| 网络 | URLSession + URLCache（**零网络第三方依赖**） |
| 加密 | CryptoKit（HMAC-SHA256） |
| 安全存储 | Keychain |
| Markdown | swift-markdown-ui |
| Captcha | WKWebView 桥接（Turnstile / TongjiCaptcha） |
| 包管理 | Swift Package Manager |
| 项目生成 | XcodeGen（`project.yml`） |
| 测试 | Swift Testing + XCTest |

## 架构

分层（自上而下单向依赖）：

```
App          @main, RootView, TabView, DI 装配
Features     Catalog / CourseDetail / Review / Wallet / Scheduler / Settings
             每个 Feature = View + Store(@Observable)
DomainKit    纯模型（Course/Review/Wallet/Semester…）。不依赖 UI 或网络
DataKit      APIClient, Repositories, Keychain, HMAC, Mnemonic
DesignSystem Liquid Glass 组件, 青色主题, 可复用 UI 组件
Platform     Markdown, Captcha 桥接, Logger, Constants
```

**规则**
- **MV 而非 MVVM**：`@Observable` Store 持状态与意图方法，View 直接订阅。不要 `ObservableObject`、`Published` 或协议样板。
- **Repository + 构造注入**：不用 Environment DI——直接 `init(repo: .init())` 给默认值，单测时传 mock。
- **禁止**：`!` 强解包、`try!`、`print()`。错误必须显式处理并有用户可见态。
- **并发**：UI 代码全 `@MainActor`；共享可变状态用 `actor`。
- **格式化**：提交前 `swiftlint --strict`。

## 代码规范

- **注释解释 why 而非 what**。代码本身已经说明它在做什么。doc comment 仅在 API 用途不直观时才需要。
- **禁止单字母变量名**（`a`、`b`、`c`、`s`、`v` 等），例外：`i`/`j` 作为循环索引。域内标准缩写允许（`img`、`btn`、`ctx`、`cfg`、`repo`）。
- **`XxxInfo`、`XxxData`、`XxxDetail`** 尽量避免——找到真正表达含义的名字。
- **同一概念跨文件命名必须一致**。`CourseRepository` 的 `getCourses`，`CatalogViewModel` 里不能写成 `fetchCourseList`。
- **不需要的注释头**：`// ── Foo ──` 分隔线在 200 行以下文件禁止。文件头 `//  Created by` 禁止。
- **无 TODO 注释**——用真实 issue tracking。

## Liquid Glass 使用

- 玻璃仅用于**导航/控件层**：TabBar、Toolbar、搜索条、浮动按钮、Sheet 把手。
- 内容卡片用实色背景 + 柔光阴影——**禁止满屏玻璃**。
- **无障碍**：检查 `accessibilityReduceTransparency`，提供不透明回退。
- 品牌强调色：青色系（cyan），与 Web 端一致。

## 安全与合规（MUST）

1. **密钥只进 Keychain**：`userSecret`、助记词只存 Keychain（可加生物识别）。严禁 UserDefaults、plist、日志、明文文件。
2. **评论原生渲染**：Markdown → `AttributedString` / swift-markdown-ui。禁止 WKWebView/HTML 渲染用户内容（根除 XSS）。WebView 仅用于 captcha。
3. **编辑鉴权算法须与后端一致**：`edit_token = HMAC-SHA256(userSecret, "jcourse:edit-review:" + reviewId)`（CryptoKit，小写 hex）。私钥不出设备。
4. **HTTPS only**：Release 不放宽 ATS。Debug 仅放宽 `127.0.0.1`。
5. **UGC 合规**：每条评价必须有举报按钮、EULA 与社区规范入口、屏蔽/隐藏功能（App Store Guideline 1.2）。
6. **点赞 clientId**：本地随机 UUID，持久化到 UserDefaults（非敏感）。不做设备指纹采集。

## API 对接

- 公开接口无需鉴权。原生 HTTP 不受 CORS 限制。
- 缓存：后端返回 `Cache-Control`（含 `stale-while-revalidate`），`URLCache` 配置 `.useProtocolCachePolicy` 即可秒开。
- 端点全集见 `../YourTJCourse-Serverless/docs/api.md`。
- 涉及后端改动（新端点、新字段）时：在同级仓库实现代码**但不要 commit/push**，标记给用户确认。

## 分支策略

```
master  稳定分发（TestFlight / App Store）。仅从 dev PR 合并
  ↑
dev     日常开发集成。所有 feature/fix PR 合入这里
  ↑
feature/* | fix/*  从 dev 拉出，合入 dev 后删除
```

- **`master`**：禁止直接推送。需要 PR + CI 全绿 + 1 review。
- **`dev`**：禁止直接推送。需要 PR + CI（spm-test + lint）。
- **`feature/*` / `fix/*`**：无保护。从 `dev` 拉出。
- **不要丢弃未提交的更改**：需要切换分支时用 `git stash`，不要 `git reset --hard`、`git checkout -f` 或 `git stash drop`。
- **不要直接推 `master`**，即使有权限。

## 提交规范

- **Conventional Commits**：`feat(scope): …` / `fix(scope): …` / `chore(scope): …` / `docs(scope): …`
- scope：`app`、`catalog`、`course`、`review`、`wallet`、`scheduler`、`settings`、`data`、`design`、`platform`、`ci`
- 英文、祈使语气。一次只做一件事。message 末尾不加 AI 身份声明或其他标记。
- 原子化 commit：逻辑独立的改动分开 commit。不要把不相关的 refactor 和功能 squash 在一起。

## Do / Don't

**Do**
- 新功能先纯逻辑 + 单测，再 Repository，再 View。
- 每个可复用组件配 `#Preview`。

**Don't**
- ❌ WebView 套壳 App。
- ❌ WebView/HTML 渲染评论。
- ❌ 密钥进 UserDefaults / 日志 / 代码。
- ❌ 引入重型框架或不必要的第三方依赖（Firebase、RxSwift、Alamofire 等）。
- ❌ 擅自改最低 iOS 版本、增后端端点等跨端决定——先确认。

## AI Maintainer (RCM)

本仓库配置了 AI maintainer bot。工作流定义和 pipeline 模板位于 `.github/maintainer/`。

| 事件 | 触发条件 | 行为 |
|------|----------|------|
| Issue opened | 自动 | 分类、打标签、搜重复、发分析评论 |
| PR opened / synchronize | 自动 | 审查代码、核对目标是否达成、发 review 评论 |
| Issue/PR 评论含 `@maintainer` | 自动 | 智能分类意图（回答/改label/修代码），执行对应动作 |
| workflow_dispatch | 手动 | 健康度报告 issues/PRs 分析 |

- 要修改 pipeline 行为，直接编辑 `.github/maintainer/templates/*.rcm.tpl`
- 要调整事件路由，编辑 `.github/maintainer/dispatch.toml`

## 参考

- 立项书：`../YourTJCourse-Serverless/docs/ios-app-proposal.md`
- API：`../YourTJCourse-Serverless/docs/api.md`
- DB：`../YourTJCourse-Serverless/docs/database.md`
- 后端源码：`../YourTJCourse-Serverless/backend/src/`
- CI：`.github/workflows/ci.yml`
- 贡献指南：`CONTRIBUTING.md`

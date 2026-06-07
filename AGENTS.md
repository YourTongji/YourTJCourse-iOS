# AGENTS.md — YOURTJ 选课社区 · iOS 客户端

本文件是给在本仓库工作的 AI 编码代理（及人类协作者）的操作指南。开工前请通读。

---

## 1. 这是什么

YOURTJ 选课社区的**原生 iOS 客户端**（Swift / SwiftUI，Liquid Glass 设计）。
它是一个**纯前端消费者**：直接调用既有的 Cloudflare Workers 后端，不自带服务端。

- 后端与 API 文档在同级仓库：`../YourTJCourse-Serverless/`
  - API 参考：`../YourTJCourse-Serverless/docs/api.md`
  - 数据库 Schema：`../YourTJCourse-Serverless/docs/database.md`
  - 设计立项书（本 App 的依据）：`../YourTJCourse-Serverless/docs/ios-app-proposal.md`
- 目标与功能范围以 **proposal** 为准；本文件只讲"怎么写、怎么跑、规矩是什么"。

**当前状态：Greenfield（脚手架阶段）**——尚无 Xcode 工程。第一个实质任务是按 §4 建立工程骨架。

---

## 2. 技术栈（已定）

| 维度 | 选型 |
|---|---|
| 语言 | Swift 6（开启 strict concurrency） |
| UI | SwiftUI（iOS 26 SDK / Xcode 26），Liquid Glass |
| 状态 | Observation（`@Observable` / `@State` / `@Environment`），MV 模式 |
| 异步 | Swift Concurrency（async/await、actor、`@MainActor`） |
| 网络 | URLSession（自封装 `APIClient`，**不引入网络第三方库**） |
| 加密 | CryptoKit（HMAC-SHA256 计算 `edit_token`） |
| 安全存储 | Keychain（钱包密钥/助记词） |
| Markdown | swift-markdown-ui（或自研 `AttributedString` 渲染） |
| 人机验证 | WKWebView 桥接（Turnstile / TongjiCaptcha 无原生 SDK） |
| 依赖管理 | Swift Package Manager |
| 测试 | Swift Testing（单元）+ XCTest（UI） |

> **最低部署版本确定**（兼容 iOS 18）。代码新增"仅 iOS 26"的 API 时，需兼容 18，用 `if #available` 包裹并提供回退。

---

## 3. 架构与约定

分层（自上而下单向依赖）：

```
App        @main、RootView、底部 TabView、启动闸门、依赖装配(DI)
Features   按页面/领域分模块：Catalog / CourseDetail / Review / Wallet / Scheduler / Settings
           每个 Feature = View(SwiftUI) + Store(@Observable) + 局部 Model
DomainKit  纯 Swift 领域模型与用例（Course/Review/Wallet/Semester…）。不依赖 SwiftUI/网络/Foundation 网络
DataKit    APIClient、各 Repository（端点封装+解码+缓存）、Keychain、CreditClient、edit_token(HMAC)
Platform   DesignSystem(Liquid Glass 组件)、Markdown、Captcha 桥接、Logger、工具
```

**规则**
- **MV 而非重型 MVVM**：用 `@Observable` 的 `Store` 持状态与意图方法，View 直接订阅。不要为了架构而架构，避免样板。
- **Repository 走协议 + 依赖注入**（通过 `Environment`）。便于 mock 单测。Domain 层尽量纯函数（如跨学期聚合、学期排序），直接覆盖测试。
- **并发**：UI 相关 `@MainActor`；共享可变状态用 `actor`；不要在视图里堆同步阻塞调用。
- **命名/风格**：遵循 Swift API Design Guidelines。视图小而可组合，避免巨型 View；每个可复用组件配 `#Preview`。
- **禁止**：`!` 强解包、`try!`、生产代码 `print`（用 `os.Logger`）。错误要显式处理并有用户可见态。
- **格式化**：提交前跑 `swift-format`（或 SwiftLint）。配置进仓库根。

### 计划目录结构

```
YourTJCourse-iOS/
├─ App/                  # 薄 app target：@main、RootView、启动闸门、DI 装配
├─ Packages/            # 本地 SPM 包
│  ├─ DesignSystem/     # Liquid Glass 组件、配色(青色系)、字体
│  ├─ DomainKit/        # 纯模型 + 用例
│  ├─ DataKit/          # APIClient / Repositories / Keychain / CreditClient / edit_token
│  ├─ Platform/         # Markdown、Captcha(WKWebView) 桥接、Logger
│  └─ Features/         # Catalog / CourseDetail / Review / Wallet / Scheduler / Settings
├─ Config/              # *.xcconfig（按 scheme 配 API_BASE）
├─ Tests/               # 或各包内置 Tests
├─ AGENTS.md
├─ README.md
└─ .gitignore
```

---

## 4. 构建 / 运行 / 测试

> 工程尚未创建。建立骨架时：用 Xcode 26 新建 App（SwiftUI 生命周期），把领域/数据/设计系统拆成 `Packages/` 下的本地 SPM 包，App target 仅做装配。

工程就绪后的常用命令（占位，按实际 scheme/路径调整）：

```bash
# 构建（模拟器）
xcodebuild -scheme YourTJCourse -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# 跑 UI/集成测试
xcodebuild -scheme YourTJCourse -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# 本地 SPM 包单测（在包目录内）
swift test
```

**API base（按环境切换，走 `Config/*.xcconfig`）**
- Debug → 本地后端 `http://127.0.0.1:8787`（在 `../YourTJCourse-Serverless/backend` 跑 `npm run dev`，需先 `db:init:local` + `db:seed:local`）
- Release → 生产 `https://jcourse.yourtj.de`
- Credit 服务 base：`https://core.credit.yourtj.de`

> ⚠️ xcconfig 里 `//` 是注释，URL 要写成 `API_BASE = http:/$()/127.0.0.1:8787` 以转义双斜杠。
> ⚠️ Debug 连本地 `http://` 需在 Debug 配置放宽 ATS（仅 Debug，**Release 禁止放宽**）。

---

## 5. 后端对接要点

- 公开接口**无需鉴权**；原生 HTTP 不受浏览器 CORS 限制，可直接调。
- 尊重后端返回的 `Cache-Control`（含 `stale-while-revalidate`）：配置 `URLCache`，策略用 `.useProtocolCachePolicy`，即可获得二次进入秒开。
- 端点全集见 `../YourTJCourse-Serverless/docs/api.md`。本 App 关注：
  - 启动/设置：`POST /api/startup/verify`、`GET /api/settings/runtime-state`、`GET /api/departments`
  - 课程：`GET /api/courses`、`GET /api/course/:id`、`/related`、`/by-code/:code`
  - 评价：`POST /api/review`、`PATCH /api/review/:id/edit-token`、`PUT /api/review/:id`、`POST|DELETE /api/review/:id/like`
  - 排课：`/api/getAll*`、`/api/find*`（P1）

---

## 6. 安全与合规（MUST）

1. **密钥只进 Keychain**：钱包 `userSecret`、助记词只存 Keychain（可加生物识别保护），**严禁** UserDefaults / plist / 日志 / 明文文件。（这是修复 Web 端 issue #15 的初衷，别在 iOS 重蹈覆辙。）
2. **评论原生渲染**：用 Markdown→`AttributedString`/swift-markdown-ui 渲染，**严禁**用 WKWebView/HTML 渲染用户内容（从根上免 XSS）。WebView 仅用于承载 captcha 验证页。
3. **编辑鉴权算法须与后端一致**：
   `edit_token = HMAC-SHA256(userSecret, "jcourse:edit-review:" + reviewId)`（CryptoKit，输出小写 hex）。私钥不出设备。
4. **HTTPS only**：Release 不放宽 ATS；不硬编码任何密钥/Token 进仓库。
5. **UGC 合规（App Store Guideline 1.2）**：评价展示必须保留**举报**、**屏蔽作者/隐藏单条**、EULA 与社区规范入口。后端可能需新增 `POST /api/review/:id/report`（与后端协商）。
6. 点赞 `clientId` 用本地随机 UUID（持久化到 Keychain/UserDefaults 均可，非敏感）；不做设备指纹采集。

---

## 7. Liquid Glass 使用规范

- 玻璃只用于**导航/控件层**：TabBar、Toolbar、搜索条、浮动按钮、Sheet 把手；内容卡片用实色 + 柔光，避免"满屏玻璃"。
- 常用 API：`.glassEffect(_:in:)`、`GlassEffectContainer(spacing:)`（成组融合/形变）、`@Namespace` + `.glassEffectID(_:in:)`（morph）、`.buttonStyle(.glass)/.glassProminent`。Toolbar/Sheet 在 iOS 26 自动玻璃。
- **无障碍**：尊重"减弱透明度/增强对比度/减弱动态"。自定义玻璃组件要用 `accessibilityReduceTransparency` 等环境值提供不透明回退，保证对比度。
- 品牌强调色沿用网页青色系（cyan）。

---

## 8. 分支策略 / Git 规范

### 分支模型

```
master  ←  稳定分发（TestFlight / App Store）。仅从 dev PR 合并
  ↑
dev     ←  日常开发集成。所有 feature/fix 分支合入这里
  ↑
feature/* | fix/*  ←  新功能 / 修复。从 dev 拉出，合入 dev 后删除
```

- **`master`**：禁止直接推送，需要 PR + CI 全绿 + review
- **`dev`**：禁止直接推送，需要 PR + CI (spm-test + lint)
- **`feature/*`**、**`fix/*`**：从 `dev` 拉出，无保护

### 提交规范

- **Conventional Commits**：`feat(scope): …` / `fix(scope): …` / `chore(scope): …` / `docs(scope): …`
- scope 建议：`app`、`catalog`、`course`、`review`、`wallet`、`scheduler`、`settings`、`data`、`design`、`platform`、`ci`
- 英文、祈使语气，一次只做一件事
- 提交 message 末尾**不要**附加 AI 身份声明或其他额外标记
- 遵循原子化 commit 准则（逻辑独立的改动分多次 commit）

---

## 9. Do / Don't 速查

**Do**
- 先读 proposal 与 `docs/api.md` 再动手。
- 新功能：Domain 纯逻辑 + 单测先行，再接 Repository，再做 View。
- 用 `#Preview` 驱动 UI；模拟器跑通再说完成。

**Don't**
- ❌ 把 App 做成 WebView 套壳。
- ❌ 用 WebView/HTML 渲染评论。
- ❌ 把密钥写进 UserDefaults/代码/日志。
- ❌ 引入重型架构框架或不必要的第三方依赖。
- ❌ 擅自改"最低 iOS 版本""新增后端端点"等跨端决定——先确认。

---

## 10. 参考

- 立项书：`../YourTJCourse-Serverless/docs/ios-app-proposal.md`
- API：`../YourTJCourse-Serverless/docs/api.md`
- DB：`../YourTJCourse-Serverless/docs/database.md`
- 后端源码：`../YourTJCourse-Serverless/backend/src/`（评价/编辑鉴权见 `routes/public.ts`）

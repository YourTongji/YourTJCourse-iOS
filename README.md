<p align="center">
  <img src="icon.png" width="128" alt="YourTJ Course">
</p>

<h1 align="center">YourTJ Course</h1>
<p align="center">
  同济大学选课社区 · 原生 iOS 客户端<br>
  SwiftUI + Liquid Glass · iOS 18+
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#safety--compliance">Safety</a>
</p>

---

**YourTJ Course** 是同济大学选课社区的官方 iOS 客户端。它以 SwiftUI 原生实现，采用 Liquid Glass 设计语言，直接调用 Cloudflare Workers 后端 API，提供课程浏览、评价分享、积分钱包等功能。

> 后端仓库：[YourTJCourse-Serverless](https://github.com/YourTongji/YourTJCourse-Serverless)

## Features

| 模块 | 功能 | 状态 |
|------|------|------|
| **课程浏览** | 课程列表、关键词搜索、学期/院系筛选、Session 随机抽课 | ✅ MVP |
| **课程详情** | 课程信息、AI 总结、评价列表、关联课程 | ✅ MVP |
| **评价系统** | 写/编辑评价、Markdown 渲染、点赞/取消点赞、隐藏、举报 | ✅ MVP |
| **积分钱包** | BIP39 助记词生成、Keychain 安全存储、恢复钱包 | ✅ MVP |
| **启动闸门** | 启动验证、Captcha 人机验证（TongjiCaptcha/Turnstile）、维护态检测 | ✅ MVP |
| **公告通知** | 运行时公告拉取、未读弹窗、「我已知晓」标记已读 | ✅ MVP |
| **用户协议** | EULA、社区规范、App Store 合规（Guideline 1.2） | ✅ MVP |
| **排课模拟器** | 移动端设计占位（计划中，P1） | 📐 Design |
| **HK 排课** | 一系统 PK 数据对接 | ⏳ Planned |

## Architecture

Pure **MV** (Model-View) architecture with `@Observable`, no heavy MVVM framework.

```
┌─────────────────────────────────────────┐
│  App  (@main, RootView, TabView, DI)    │
├─────────────────────────────────────────┤
│  Features                               │
│  ┌────────┬────────┬────────┬────────┐  │
│  │Catalog │Course  │ Review │ Wallet │  │
│  │        │Detail  │        │        │  │
│  ├────────┼────────┼────────┼────────┤  │
│  │Scheduler│Settings│Startup │        │  │
│  │ (stub) │        │ Gate   │        │  │
│  └────────┴────────┴────────┴────────┘  │
├─────────────────────────────────────────┤
│  DataKit  (APIClient, Repositories,     │
│           Keychain, HMAC, Mnemonic)     │
├─────────────────────────────────────────┤
│  DomainKit (pure models, no UI deps)    │
├─────────────────────────────────────────┤
│  DesignSystem + Platform                │
│  (Liquid Glass, Markdown, Captcha, Log) │
└─────────────────────────────────────────┘
```

**Key design decisions:**

- **MV not MVVM** — `@Observable` Store holds state and intent methods; View subscribes directly. No boilerplate protocols.
- **No network dependencies** — `URLSession` with `URLCache` handling `Cache-Control` + `stale-while-revalidate` for instant second-load.
- **Repository protocol + DI** — via `Environment` for testable mocks. Domain logic stays pure where possible.
- **Strict Concurrency** — Swift 6 with complete concurrency checking. `@MainActor` for UI, `actor` for shared mutable state.

## Getting Started

### Prerequisites

- Xcode 16+
- iOS 18+ deployment target
- (Optional) Local backend for development

### Setup

```bash
# Generate Xcode project via XcodeGen
cd YourTJCourse-iOS
xcodegen generate --spec project.yml --project .

# Open project
open YourTJCourse.xcodeproj
```

Select **iPhone 16 Pro** simulator and hit Run. SPM will automatically resolve dependencies (swift-markdown-ui).

### API Configuration

API base URLs are managed via `Config/*.xcconfig`:

| Environment | API Base | Credit Base |
|-------------|----------|-------------|
| **Debug** | `http://127.0.0.1:8787` | `https://core.credit.yourtj.de` |
| **Release** | `https://jcourse.yourtj.de` | `https://core.credit.yourtj.de` |

> ⚠️ `xcconfig` uses `//` for comments. URL double slashes must be escaped: `API_BASE = http:/$()/127.0.0.1:8787`
> ⚠️ Debug ATS is relaxed for local `http://` only; Release uses HTTPS exclusively.

### Build

```bash
# Build for simulator
xcodebuild -scheme YourTJCourse -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run tests
xcodebuild -scheme YourTJCourse -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Package unit tests
swift test --package-path Packages/DomainKit
swift test --package-path Packages/DataKit
```

## Project Structure

```
YourTJCourse-iOS/
├── App/                              # Thin app target
│   ├── YourTJCourseApp.swift         # @main, RootView, MainTabView, announcements
│   ├── Info.plist                    # API_BASE, ATS config
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/       # Cyan "YTJ" cat icon
│       └── AccentColor.colorset/
│
├── Packages/
│   ├── DomainKit/                    # Pure domain models (11 files)
│   │   ├── Course.swift              # Course, CourseDetail, RelatedCourses
│   │   ├── Review.swift              # Review
│   │   ├── AiSummary.swift           # AiSummaryData, AiSummaryResponse
│   │   ├── Wallet.swift              # WalletBalance, WalletSummary, CreditWallet
│   │   ├── RuntimeState.swift        # MaintenanceState, Announcement, etc.
│   │   ├── PaginatedResponse.swift   # Generic paginated response
│   │   ├── Semester.swift            # Semester utilities
│   │   └── ReportReason.swift        # Report enum (App Store compliance)
│   │
│   ├── DataKit/                      # Networking & data layer (16 files)
│   │   ├── APIClient.swift           # URLSession-based HTTP client
│   │   ├── APIConfig.swift            # Build-time config (API_BASE, clientId)
│   │   ├── APIError.swift            # Typed errors
│   │   ├── Repositories/             # CourseRepository, ReviewRepository, etc.
│   │   ├── Keychain/                 # KeychainManager with biometric support
│   │   ├── HMAC/                     # HMACHelper (edit_token computation)
│   │   ├── Credit/                   # CreditAPIClient (separate base URL)
│   │   └── Utilities/                # BIP39Wordlist, MnemonicHelper
│   │
│   ├── DesignSystem/                 # Liquid Glass & components (10 files)
│   │   ├── Theme.swift               # Cyan brand colors, typography tokens
│   │   ├── LiquidGlass.swift         # GlassEffect modifier, card styles
│   │   └── Components/               # CourseCard, RatingView, EmptyState, etc.
│   │
│   ├── Platform/                     # Cross-cutting utilities (8 files)
│   │   ├── Markdown/                 # swift-markdown-ui renderer
│   │   ├── Captcha/                  # WKWebView bridge, TongjiCaptcha, Turnstile
│   │   ├── Logger/                   # os.Logger wrapper
│   │   └── Utilities/                # AppVersion, Constants
│   │
│   └── Features/                     # All feature modules (16 files)
│       ├── Catalog/                  # Course list, search, filter sheet
│       ├── CourseDetail/             # Detail view, AI summary, review cards
│       ├── Review/                   # Write/edit review form, captcha flow
│       ├── Wallet/                   # Create/restore wallet, mnemonic backup
│       ├── Settings/                 # Announcements, EULA, about, feedback
│       ├── Startup/                  # Startup gate, captcha verification
│       └── SchedulerStub.swift       # Scheduler placeholder with design spec
│
├── Config/                           # xcconfig files (Debug/Release)
├── AGENTS.md                         # AI agent development guidelines
└── project.yml                       # XcodeGen project specification
```

## Tech Stack

| Layer | Choice |
|-------|--------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI, iOS 18+ (Liquid Glass on iOS 26) |
| State | `@Observable` / `@Environment` (MV) |
| Async | Swift Concurrency (`async/await`, `actor`, `@MainActor`) |
| Networking | URLSession (zero third-party libs) |
| Cryptography | CryptoKit (HMAC-SHA256) |
| Secure Storage | Keychain (with biometric protection) |
| Markdown | swift-markdown-ui |
| Captcha | WKWebView bridge (Turnstile / TongjiCaptcha) |
| Package Manager | Swift Package Manager |
| Project Generation | XcodeGen |

## Safety & Compliance

- **🔑 Keychain only** — Wallet userSecret and mnemonics are stored exclusively in Keychain with optional biometric protection. Never in UserDefaults, logs, or plaintext files.
- **🛡️ No XSS vector** — Reviews rendered natively via `AttributedString`/`swift-markdown-ui`. WebView is reserved solely for captcha.
- **🔐 HMAC edit token** — `edit_token = HMAC-SHA256(userSecret, "jcourse:edit-review:" + reviewId)`, computed client-side via CryptoKit. Private key never leaves the device.
- **🔒 HTTPS only** — Release builds enforce HTTPS. ATS is relaxed only for `127.0.0.1` in Debug.
- **📋 UGC compliance (App Store Guideline 1.2)** — Report button on every review, hide individual reviews, EULA and Community Guidelines presented in-app.
- **📍 No fingerprinting** — Like `clientId` is a random UUID persisted locally. No device fingerprint collection.

## License

© 2026 YourTJ. All rights reserved.

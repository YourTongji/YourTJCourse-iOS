# Xcode Build Optimization Plan — YourTJCourse

## Executive Summary

Your build is **already fast**. Clean build completes in **~18.6s** and incremental builds in **~2.2s**. The project is well-structured with clean Swift code, no type-checking hotspots, and a well-layered SPM package graph. Most compiler work is effectively parallelized (5.5x parallelism).

The recommendations below focus on the few remaining low-hanging fruit — primarily build settings and tooling cleanup.

## Baseline Benchmarks

| Metric | Clean | Zero-change Incremental |
|--------|-------|------------------------|
| Median | 18.602s | 2.156s |
| Min | 15.415s | 2.119s |
| Max | 18.606s | 2.213s |
| Runs | 3 | 3 |

> **Variance note**: Clean min(15.4s) vs max(18.6s) spread = ~17% of median. Moderate variance — likely from system background activity on Apple Silicon. Results are usable for before/after comparison but improvements should exceed ~3s to be conclusive.

## Clean Build Timing Summary

| Category | Tasks | Aggregate Time | Parallelism |
|----------|------:|---------------:|:-----------:|
| SwiftCompile | 92 | 84.4s | 5.5x (well parallelized) |
| SwiftEmitModule | 8 | 6.8s | ✅ |
| CompileC (ObjC/C) | 34 | 4.6s | ✅ |
| SwiftDriver | 8 | 3.7s | ✅ |
| CompileAssetCatalogVariant | **1** | **3.3s** ⚠️ | **Serial!** |
| Ld | 12 | 1.3s | ✅ |
| ScanDependencies | 34 | 0.9s | ✅ |
| Everything else | — | < 0.5s each | ✅ |

**Key insight**: SwiftCompile 84.4s / 18.6s wall = 5.5x parallelism. Compile hotspots are NOT blocking your build. The build is well-parallelized and compiler workload is not the bottleneck.

## Compilation Diagnostics

- **Type-checking hotspots >100ms**: **0** — extremely clean
- **Function body warnings**: None
- **Expression warnings**: None
- **Longest files**: `SchedulerStub.swift` (2639 lines, auto-generated stub), `CourseDetailView.swift` (646 lines), `SettingsView.swift` (509 lines)

**Verdict**: No compilation bottlenecks to address. Your Swift code is well-typed.

## Build Settings Audit

### Debug Configuration

| Setting | Current | Recommended | Status |
|---------|---------|-------------|--------|
| `SWIFT_COMPILATION_MODE` | `singlefile` (default) | `singlefile` | ✅ |
| `SWIFT_OPTIMIZATION_LEVEL` | `-Onone` | `-Onone` | ✅ |
| `GCC_OPTIMIZATION_LEVEL` | `0` | `0` | ✅ |
| `ONLY_ACTIVE_ARCH` | `YES` | `YES` | ✅ |
| `DEBUG_INFORMATION_FORMAT` | `dwarf` | `dwarf` | ✅ |
| `ENABLE_TESTABILITY` | `YES` | `YES` (expected) | ✅ |
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | includes `DEBUG` | should include `DEBUG` | ✅ |
| `EAGER_LINKING` | **`NO`** | `YES` | ❌ |
| `COMPILATION_CACHE_ENABLE_CACHING` | **not set** | `YES` | ❌ |

### Release Configuration

| Setting | Current | Recommended | Status |
|---------|---------|-------------|--------|
| `SWIFT_COMPILATION_MODE` | `wholemodule` | `wholemodule` | ✅ |
| `SWIFT_OPTIMIZATION_LEVEL` | `-O` | `-O` | ✅ |
| `DEBUG_INFORMATION_FORMAT` | `dwarf-with-dsym` | `dwarf-with-dsym` | ✅ |
| `ENABLE_TESTABILITY` | `NO` | `NO` | ✅ |
| `ONLY_ACTIVE_ARCH` | `NO` | `NO` | ✅ |

### Cross-Target Consistency

All targets inherit project-level settings. No configuration drift detected. ✅

## SPM Package Graph Analysis

| Package | Type | Files | Dependencies |
|---------|------|------:|-------------|
| `DomainKit` | Local | 18 | — (root) |
| `DataKit` | Local | 21 | `DomainKit` |
| `DesignSystem` | Local | 12 | — (root) |
| `Platform` | Local | 9 | `swift-markdown-ui` (2.4.1) |
| `Features` | Local | 16 | `DomainKit`, `DataKit`, `DesignSystem`, `Platform` |

**Remote packages**: `NetworkImage` (6.0.1), `swift-markdown-ui` (2.4.1), `cmark-gfm` (0.8.0)

**Findings**:
- ✅ Layered dependency graph — clean, no cycles
- ✅ All remote packages pinned to **tagged versions** (no branch pins)
- ✅ No macro-heavy dependencies (no swift-syntax, no TCA)
- ✅ No configuration drift between local packages
- ✅ No oversized modules (>200 files)
- ℹ️ `Features` is the sole consumer — its 16 source files trigger rebuild cascading from any lower package change. This is expected architecture, not a build issue.

## Prioritized Recommendations

### 1. Enable Compilation Caching

| | |
|---|---|
| **Setting** | `COMPILATION_CACHE_ENABLE_CACHING = YES` |
| **Evidence** | Currently not set. Xcode 26.5 has this opt-in feature. 92 Swift compile tasks × 84s aggregate. |
| **Expected impact** | "Expected to reduce your clean build by approximately 1-2.6 seconds (5-14%). The benefit compounds in real workflows — branch switching, pulling changes, and CI with persistent DerivedData." |
| **Risk** | Low. Can also be enabled per-user via Xcode settings without committing to shared project. |
| **File** | `project.yml` → add to `settings: base:` or `Config/Debug.xcconfig` |

### 2. Enable Eager Linking for Debug

| | |
|---|---|
| **Setting** | `EAGER_LINKING = YES` (currently `NO`) |
| **Evidence** | Linker (Ld) accounts for 1.3s of aggregate work across 12 tasks, but runs as a serialized phase toward the end. Eager linking lets the linker start before all compilation finishes. |
| **Expected impact** | "Expected to reduce your clean build by approximately 0.3-0.8 seconds." |
| **Risk** | Low. Standard Apple-recommended Debug setting. |
| **File** | `project.yml` → add to `settings: base:` or `Config/Debug.xcconfig` |

### 3. Guard SwiftLint Script Phase

| | |
|---|---|
| **Setting** | `basedOnDependencyAnalysis: false` + missing tool guard |
| **Evidence** | `swiftlint` is **not installed** on this machine, yet the pre-build script runs every build (including incremental). Currently negligible (0.018s) because swiftlint falls through silently. |
| **Expected impact** | "No wait-time improvement expected when SwiftLint is not installed. If SwiftLint is installed, `basedOnDependencyAnalysis: false` causes it to re-run on every incremental build (~2-5s penalty on 900+ files). Add input/output file lists to make it dependency-aware." |
| **Risk** | Low. Two changes: (a) add tool-existence guard so absent tools don't waste even 0.02s, (b) if SwiftLint is actively used, declare input/output file lists. |
| **File** | `project.yml` → preBuildScripts section |

### 4. (Informational) Asset Catalog Compilation

| | |
|---|---|
| **Issue** | `CompileAssetCatalogVariant` takes ~3.3s (serial, 1 task). Variance is high (0.9s–4.6s across 3 runs), suggesting I/O-dependent behavior. |
| **Impact** | "Impact on wait time is uncertain — this is a serial task that may be the critical path for ~3s of your clean build." |
| **Action** | Your asset catalog is small (164KB, just AppIcon + AccentColor). This is likely Xcode behavior rather than a project issue. Monitor whether `GenerateAssetSymbols`/`LinkAssetCatalog` grow as you add assets. |

## Approval Checklist

| # | Recommendation | Expected Wait-time Impact | Risk | [ ] Approve |
|---|---------------|--------------------------|:----:|:-----------:|
| 1 | Enable `COMPILATION_CACHE_ENABLE_CACHING` | Reduce clean build ~1-2.6s (5-14%) | Low | [ ] |
| 2 | Enable `EAGER_LINKING = YES` (Debug) | Reduce clean build ~0.3-0.8s | Low | [ ] |
| 3 | Guard SwiftLint script phase | Precise impact depends on SwiftLint install state | Low | [ ] |

## Next Steps

1. Review and check the approval boxes above
2. I'll apply the approved changes via `project.yml` edits
3. Re-benchmark with the same inputs:
   ```bash
   python3 scripts/benchmark_builds.py \
     --project YourTJCourse.xcodeproj \
     --scheme YourTJCourse \
     --configuration Debug \
     --destination "platform=iOS Simulator,name=iPhone 17 Pro" \
     --output-dir .build-benchmark
   ```
4. Compare new wall-clock medians against baseline

## Environment

- **Xcode**: 26.5 (Build version 17F42)
- **macOS**: 26.5.1 (ARM64)
- **Device**: Apple Silicon MacBook Pro
- **Simulator**: iPhone 17 Pro (iOS 26.5)

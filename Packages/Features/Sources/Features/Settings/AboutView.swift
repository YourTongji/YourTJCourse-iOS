import SwiftUI
import Platform

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.cyan)

                Text("YourTJ Course")
                    .font(.title)
                    .bold()

                Text("版本 \(AppVersion.displayString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("同济大学选课社区 iOS 客户端")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    if let serverlessURL = URL(string: "https://github.com/YourTongji/YourTJCourse-Serverless") {
                        Link("后端: YourTJCourse-Serverless", destination: serverlessURL)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                    if let iosURL = URL(string: "https://github.com/YourTongji/YourTJCourse-iOS") {
                        Link("客户端: YourTJCourse-iOS", destination: iosURL)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("Built with SwiftUI + Liquid Glass")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("© 2026 YourTJ. All rights reserved.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
                    .frame(height: 32)
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview("About") {
    AboutView()
}

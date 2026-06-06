import SwiftUI

public struct TongjiCaptchaView: View {
    private let client: TongjiCaptchaClient
    private let onToken: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var challenge: TongjiCaptchaChallenge?
    @State private var selectedIndices: Set<Int> = []
    @State private var isLoading = false
    @State private var isVerifying = false
    @State private var error: CaptchaError?

    public init(
        client: TongjiCaptchaClient = .init(),
        onToken: @escaping (String) -> Void
    ) {
        self.client = client
        self.onToken = onToken
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("正在加载验证码...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let challenge {
                                challengeBody(challenge)
                            } else if let error {
                                errorBody(error)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("人机验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                if challenge == nil, !isLoading {
                    await loadChallenge()
                }
            }
        }
    }

    private func challengeBody(_ challenge: TongjiCaptchaChallenge) -> some View {
        VStack(spacing: 14) {
            Text(challenge.prompt)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(challenge.images.indices, id: \.self) { index in
                    captchaImageButton(challenge: challenge, index: index)
                }
            }

            if let error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await verify(challenge) }
            } label: {
                HStack {
                    Spacer()
                    if isVerifying {
                        ProgressView()
                    } else {
                        Text("验证")
                            .bold()
                    }
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedIndices.isEmpty || isVerifying)
            .padding(.top, 2)
        }
    }

    private func captchaImageButton(challenge: TongjiCaptchaChallenge, index: Int) -> some View {
        Button {
            toggle(index)
        } label: {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: challenge.imageURL(at: index, baseURL: client.baseURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            selectedIndices.contains(index) ? Color.cyan : Color.secondary.opacity(0.25),
                            lineWidth: selectedIndices.contains(index) ? 3 : 1
                        )
                }

                if selectedIndices.contains(index) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .cyan)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("验证码图片 \(index + 1)")
        .accessibilityAddTraits(selectedIndices.contains(index) ? .isSelected : [])
    }

    private func errorBody(_ error: CaptchaError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await loadChallenge() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private func toggle(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
        error = nil
    }

    private func loadChallenge() async {
        isLoading = true
        error = nil
        selectedIndices = []
        defer { isLoading = false }

        do {
            challenge = try await client.fetchChallenge()
        } catch let captchaError as CaptchaError {
            challenge = nil
            error = captchaError
        } catch {
            challenge = nil
            self.error = .loadFailed(description: error.localizedDescription)
        }
    }

    private func verify(_ challenge: TongjiCaptchaChallenge) async {
        isVerifying = true
        error = nil
        defer { isVerifying = false }

        do {
            let token = try await client.verify(
                puzzleToken: challenge.puzzleToken,
                selectedIndices: selectedIndices
            )
            onToken(token)
        } catch let captchaError as CaptchaError {
            let verificationError = captchaError
            await loadChallenge()
            error = verificationError
        } catch {
            let verificationError = CaptchaError.providerError(error.localizedDescription)
            await loadChallenge()
            self.error = verificationError
        }
    }
}

public struct TongjiCaptchaClient: Sendable {
    public let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(
        baseURL: URL = AppConstants.tongjiCaptchaBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchChallenge() async throws -> TongjiCaptchaChallenge {
        let url = baseURL.appendingPathComponent("api/captcha")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try decoder.decode(TongjiCaptchaChallenge.self, from: data)
    }

    public func verify(
        puzzleToken: String,
        selectedIndices: Set<Int>
    ) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/verify"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            TongjiCaptchaVerifyRequest(
                puzzleToken: puzzleToken,
                selectedIndices: selectedIndices.sorted()
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let result = try decoder.decode(TongjiCaptchaVerifyResponse.self, from: data)
        guard result.success else {
            throw CaptchaError.providerError(result.message ?? "验证失败")
        }
        guard let token = result.token, !token.isEmpty else {
            throw CaptchaError.invalidToken
        }
        return token
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaptchaError.loadFailed(description: "响应格式异常")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let message = try? decoder.decode(TongjiCaptchaVerifyResponse.self, from: data).message {
                throw CaptchaError.providerError(message)
            }
            throw CaptchaError.loadFailed(description: "服务返回 \(httpResponse.statusCode)")
        }
    }
}

public struct TongjiCaptchaChallenge: Decodable, Sendable, Equatable {
    public let puzzleToken: String
    public let questionType: String?
    public let prompt: String
    public let images: [String]

    private enum CodingKeys: String, CodingKey {
        case puzzleToken = "puzzle_token"
        case questionType
        case prompt
        case images
    }

    public func imageURL(at index: Int, baseURL: URL) -> URL? {
        guard images.indices.contains(index) else { return nil }

        let image = images[index]
        if let url = URL(string: image), url.scheme != nil {
            return url
        }
        return URL(string: image, relativeTo: baseURL)?.absoluteURL
    }
}

private struct TongjiCaptchaVerifyRequest: Encodable {
    let puzzleToken: String
    let selectedIndices: [Int]

    private enum CodingKeys: String, CodingKey {
        case puzzleToken = "puzzle_token"
        case selectedIndices = "selected_indices"
    }
}

private struct TongjiCaptchaVerifyResponse: Decodable {
    let success: Bool
    let token: String?
    let message: String?
}

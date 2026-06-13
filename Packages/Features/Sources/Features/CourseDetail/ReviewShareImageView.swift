import SwiftUI
import DomainKit

/// A 640pt-wide share card rendered off-screen by `ImageRenderer`.
public struct ReviewShareImageView: View {
    private static let width: CGFloat = 640
    private static let padding: CGFloat = 28
    fileprivate static let contentWidth: CGFloat = width - padding * 2

    private let courseDetail: CourseDetail
    private let review: Review
    private let markdownBlocks: [ShareMarkdownBlock]

    public init(courseDetail: CourseDetail, review: Review) {
        self.courseDetail = courseDetail
        self.review = review
        self.markdownBlocks = ShareMarkdownParser.parse(review.comment)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            reviewerSection
            infoPillsRow
            commentSection
            footerSection
        }
        .frame(width: Self.width, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    fileprivate enum Palette {
        static let darkText = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
        static let slateText = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
        static let mutedText = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
        static let border = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
        static let rating = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
        static let reviewRating = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
        static let reviewRatingBackground = Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255)
        static let cyanPillText = Color(red: 14 / 255, green: 116 / 255, blue: 144 / 255)
        static let cyanPillBackground = Color(red: 236 / 255, green: 254 / 255, blue: 255 / 255)
        static let indigoPillText = Color(red: 67 / 255, green: 56 / 255, blue: 202 / 255)
        static let indigoPillBackground = Color(red: 238 / 255, green: 242 / 255, blue: 255 / 255)
        static let greenPillText = Color(red: 4 / 255, green: 120 / 255, blue: 87 / 255)
        static let greenPillBackground = Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255)
        static let commentBorder = Color(red: 186 / 255, green: 230 / 255, blue: 253 / 255)
        static let quoteBackground = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("YOURTJ 选课社区")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(Palette.mutedText)

                Text(courseDetail.name)
                    .font(.system(size: 27, weight: .black))
                    .lineSpacing(4)
                    .foregroundStyle(Palette.darkText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                sharePill(
                    text: courseDetail.code,
                    foreground: .white,
                    background: Palette.darkText
                )
            }
            .frame(maxWidth: 380, alignment: .leading)

            Spacer(minLength: 0)
            ratingBox
        }
        .padding(.top, Self.padding)
        .padding(.horizontal, Self.padding)
    }

    private var ratingBox: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("课程评分")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.mutedText)

            Text(courseRatingText)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Palette.rating)

            Text("\(courseDetail.reviewCount) 条评价")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Palette.slateText)
        }
        .frame(width: 110, alignment: .trailing)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private var reviewerSection: some View {
        HStack(spacing: 14) {
            reviewAvatar

            VStack(alignment: .leading, spacing: 5) {
                Text(reviewerName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Palette.darkText)
                    .lineLimit(1)

                Text("\(review.semester) · \(formattedDate)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.mutedText)
            }
            .frame(maxWidth: 330, alignment: .leading)

            Spacer(minLength: 0)

            sharePill(
                text: String(format: "%.1f / 5", Double(review.rating)),
                foreground: Palette.reviewRating,
                background: Palette.reviewRatingBackground
            )
        }
        .padding(.horizontal, Self.padding)
        .padding(.top, 26)
    }

    private var reviewAvatar: some View {
        BeamAvatar(seed: avatarSeed)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var infoPillsRow: some View {
        FlowLayout(spacing: 10, rowSpacing: 10) {
            sharePill(
                text: "教师：\(teacherName)",
                foreground: Palette.cyanPillText,
                background: Palette.cyanPillBackground
            )
            sharePill(
                text: "学期：\(review.semester)",
                foreground: Palette.indigoPillText,
                background: Palette.indigoPillBackground
            )
            sharePill(
                text: "编号：\(review.sqid)",
                foreground: Palette.greenPillText,
                background: Palette.greenPillBackground
            )
        }
        .frame(width: Self.contentWidth, alignment: .leading)
        .padding(.horizontal, Self.padding)
        .padding(.top, 18)
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(markdownBlocks.enumerated()), id: \.offset) { _, block in
                ShareMarkdownBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Palette.commentBorder, lineWidth: 1)
        )
        .padding(.horizontal, Self.padding)
        .padding(.top, 22)
    }

    private var footerSection: some View {
        HStack {
            Text("内容来自 YOURTJ 选课社区")
            Spacer()
            Text("xk.yourtj.de")
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Palette.mutedText)
        .padding(.horizontal, Self.padding)
        .padding(.top, 22)
        .padding(.bottom, Self.padding)
    }

    private func sharePill(text: String, foreground: Color, background: Color) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 13, weight: .black))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 13)
            .frame(height: 31)
            .background(background)
            .clipShape(Capsule())
    }

    private var courseRatingText: String {
        courseDetail.rating > 0 ? String(format: "%.1f / 5.0", courseDetail.rating) : "- / 5.0"
    }

    private var reviewerName: String {
        review.reviewerName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "匿名用户"
    }

    private var teacherName: String {
        courseDetail.teacherName.isEmpty ? "未知教师" : courseDetail.teacherName
    }

    private var avatarSeed: String {
        reviewerName == "匿名用户" ? "评论长图-\(review.id)" : reviewerName
    }

    private var formattedDate: String {
        if let date = Self.isoDate(from: review.createdAt) {
            return Self.shareDateString(from: date)
        }
        if let seconds = TimeInterval(review.createdAt) {
            let timeInterval = seconds > 10_000_000_000 ? seconds / 1_000 : seconds
            return Self.shareDateString(from: Date(timeIntervalSince1970: timeInterval))
        }
        return review.createdAt.isEmpty ? "刚刚" : review.createdAt
    }

    private static func isoDate(from rawValue: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: rawValue) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }

    private static func shareDateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return ""
        }
        return "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }
}

private struct ShareMarkdownBlockView: View {
    let block: ShareMarkdownBlock

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(.system(size: 19, weight: .black))
                .lineSpacing(6)
                .foregroundStyle(ReviewShareImageView.Palette.darkText)
                .padding(.bottom, 10)

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255))
                    .frame(width: 6, height: 6)
                Text(block.text)
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(8)
                    .foregroundStyle(ReviewShareImageView.Palette.slateText)
            }
            .padding(.bottom, 4)

        case .quote:
            Text(block.text)
                .font(.system(size: 15, weight: .semibold))
                .lineSpacing(7)
                .foregroundStyle(Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255))
                .padding(.leading, 16)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReviewShareImageView.Palette.quoteBackground)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 203 / 255, green: 213 / 255, blue: 225 / 255))
                        .frame(width: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 10)

        case .code:
            Text(block.text)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .lineSpacing(6)
                .foregroundStyle(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReviewShareImageView.Palette.darkText)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 16)

        case .divider:
            Rectangle()
                .fill(ReviewShareImageView.Palette.border)
                .frame(height: 1)
                .padding(.vertical, 8)

        case .image:
            imagePlaceholder
                .padding(.bottom, 8)

        case .table:
            Text(block.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReviewShareImageView.Palette.slateText)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255))

        case .paragraph:
            Text(block.text)
                .font(.system(size: 16, weight: .medium))
                .lineSpacing(9)
                .foregroundStyle(ReviewShareImageView.Palette.slateText)
                .padding(.bottom, 10)
        }
    }

    private var imagePlaceholder: some View {
        Text(block.text.isEmpty ? "[图片]" : "[图片] \(block.text)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ReviewShareImageView.Palette.mutedText)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(ReviewShareImageView.Palette.border)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ShareMarkdownBlock: Sendable {
    let kind: Kind
    let text: String

    enum Kind: Sendable {
        case paragraph
        case heading
        case bullet
        case quote
        case code
        case divider
        case image
        case table
    }
}

private enum ShareMarkdownParser {
    static func parse(_ markdown: String) -> [ShareMarkdownBlock] {
        let normalized = normalize(markdown).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return [ShareMarkdownBlock(kind: .paragraph, text: " ")]
        }

        var blocks: [ShareMarkdownBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var inCodeFence = false

        for rawLine in normalized.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                if inCodeFence {
                    blocks.append(.init(kind: .code, text: codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                } else {
                    flushParagraph(&paragraphLines, into: &blocks)
                }
                inCodeFence.toggle()
                continue
            }

            if inCodeFence {
                codeLines.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph(&paragraphLines, into: &blocks)
                continue
            }

            if isDivider(line) {
                flushParagraph(&paragraphLines, into: &blocks)
                blocks.append(.init(kind: .divider, text: ""))
            } else if let image = imageBlock(from: line) {
                flushParagraph(&paragraphLines, into: &blocks)
                blocks.append(image)
            } else if let heading = headingText(from: line) {
                flushParagraph(&paragraphLines, into: &blocks)
                blocks.append(.init(kind: .heading, text: inlineText(heading)))
            } else if let bullet = bulletText(from: line) {
                flushParagraph(&paragraphLines, into: &blocks)
                blocks.append(.init(kind: .bullet, text: inlineText(bullet)))
            } else if line.hasPrefix(">") {
                flushParagraph(&paragraphLines, into: &blocks)
                blocks.append(.init(kind: .quote, text: inlineText(String(line.dropFirst()).trimmed)))
            } else if line.hasPrefix("|") {
                flushParagraph(&paragraphLines, into: &blocks)
                blocks.append(.init(kind: .table, text: inlineText(tableText(from: line))))
            } else {
                paragraphLines.append(inlineText(line))
            }
        }

        if inCodeFence {
            blocks.append(.init(kind: .code, text: codeLines.joined(separator: "\n")))
        }
        flushParagraph(&paragraphLines, into: &blocks)

        return blocks.isEmpty ? [.init(kind: .paragraph, text: " ")] : blocks
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{200C}", with: "")
            .replacingOccurrences(of: "\u{200D}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{2060}", with: "")
    }

    private static func flushParagraph(
        _ lines: inout [String],
        into blocks: inout [ShareMarkdownBlock]
    ) {
        guard !lines.isEmpty else { return }
        blocks.append(.init(kind: .paragraph, text: lines.joined(separator: "\n")))
        lines.removeAll()
    }

    private static func isDivider(_ line: String) -> Bool {
        let marker = line.replacingOccurrences(of: " ", with: "")
        return marker.count >= 3 && Set(marker).isSubset(of: ["-", "*", "_"])
    }

    private static func headingText(from line: String) -> String? {
        guard let markerEnd = line.firstIndex(where: { $0 != "#" }) else {
            return nil
        }
        let marker = line[..<markerEnd]
        guard !marker.isEmpty, marker.count <= 6 else { return nil }
        return String(line[markerEnd...]).trimmed
    }

    private static func bulletText(from line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return String(line.dropFirst(2))
        }
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let prefix = line[..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return nil }
        let afterDot = line[line.index(after: dotIndex)...]
        guard afterDot.first == " " else { return nil }
        return String(afterDot.dropFirst())
    }

    private static func imageBlock(from line: String) -> ShareMarkdownBlock? {
        if line.hasPrefix("!["),
           let closeAlt = line.firstIndex(of: "]"),
           line[line.index(after: closeAlt)...].hasPrefix("("),
           let closeURL = line.lastIndex(of: ")") {
            let altStart = line.index(line.startIndex, offsetBy: 2)
            let alt = String(line[altStart..<closeAlt])
            let urlStart = line.index(closeAlt, offsetBy: 2)
            guard urlStart < closeURL else { return .init(kind: .image, text: inlineText(alt)) }
            return .init(kind: .image, text: inlineText(alt))
        }
        if line.localizedCaseInsensitiveContains("<img") {
            return .init(kind: .image, text: htmlAttribute("alt", in: line) ?? "")
        }
        return nil
    }

    private static func htmlAttribute(_ name: String, in source: String) -> String? {
        guard let nameRange = source.range(of: "\(name)=", options: [.caseInsensitive]) else {
            return nil
        }
        let valueStart = nameRange.upperBound
        guard valueStart < source.endIndex else { return nil }
        let quote = source[valueStart]
        guard quote == "\"" || quote == "'" else { return nil }
        let contentStart = source.index(after: valueStart)
        guard let end = source[contentStart...].firstIndex(of: quote) else { return nil }
        return String(source[contentStart..<end])
    }

    private static func tableText(from line: String) -> String {
        line
            .trimmingCharacters(in: CharacterSet(charactersIn: "| "))
            .components(separatedBy: "|")
            .map { $0.trimmed }
            .joined(separator: " │ ")
    }

    private static func inlineText(_ source: String) -> String {
        var text = source
        text = replaceInlineImages(in: text)
        text = replaceMarkdownLinks(in: text)
        for token in ["**", "__", "~~", "*", "_"] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        return text.trimmed
    }

    private static func replaceInlineImages(in source: String) -> String {
        var text = source
        while let start = text.range(of: "!["),
              let closeAlt = text[start.upperBound...].firstIndex(of: "]"),
              closeAlt < text.endIndex,
              text[text.index(after: closeAlt)...].hasPrefix("("),
              let closeURL = text[text.index(after: closeAlt)...].firstIndex(of: ")") {
            let alt = String(text[start.upperBound..<closeAlt])
            text.replaceSubrange(start.lowerBound...closeURL, with: alt)
        }
        return text
    }

    private static func replaceMarkdownLinks(in source: String) -> String {
        var text = source
        while let start = text.range(of: "["),
              let closeText = text[start.upperBound...].firstIndex(of: "]"),
              closeText < text.endIndex,
              text[text.index(after: closeText)...].hasPrefix("("),
              let closeURL = text[text.index(after: closeText)...].firstIndex(of: ")") {
            let label = String(text[start.upperBound..<closeText])
            text.replaceSubrange(start.lowerBound...closeURL, with: label)
        }
        return text
    }
}

private struct BeamAvatar: View {
    let seed: String

    var body: some View {
        let data = BeamAvatarData(seed: seed)
        ZStack {
            data.backgroundColor

            RoundedRectangle(cornerRadius: data.isCircle ? 18 : 6)
                .fill(data.wrapperColor)
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(data.wrapperRotate))
                .scaleEffect(data.wrapperScale)
                .offset(x: data.wrapperTranslateX, y: data.wrapperTranslateY)

            face(data)
                .foregroundStyle(data.faceColor)
                .rotationEffect(.degrees(data.faceRotate))
                .offset(x: data.faceTranslateX, y: data.faceTranslateY)
        }
    }

    private func face(_ data: BeamAvatarData) -> some View {
        VStack(spacing: 4 + data.mouthSpread / 2) {
            HStack(spacing: 4 + data.eyeSpread) {
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 2, height: 3)
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 2, height: 3)
            }

            if data.isMouthOpen {
                Capsule()
                    .stroke(lineWidth: 1)
                    .frame(width: 10, height: 3)
            } else {
                Capsule()
                    .frame(width: 10, height: 2)
            }
        }
        .frame(width: 36, height: 36)
    }
}

private struct BeamAvatarData {
    private static let canvasSize: Double = 36
    private static let colors: [Color] = [
        Color(red: 255 / 255, green: 173 / 255, blue: 173 / 255),
        Color(red: 255 / 255, green: 214 / 255, blue: 165 / 255),
        Color(red: 253 / 255, green: 255 / 255, blue: 182 / 255),
        Color(red: 202 / 255, green: 255 / 255, blue: 191 / 255),
        Color(red: 155 / 255, green: 246 / 255, blue: 255 / 255),
        Color(red: 160 / 255, green: 196 / 255, blue: 255 / 255),
        Color(red: 189 / 255, green: 178 / 255, blue: 255 / 255),
        Color(red: 255 / 255, green: 198 / 255, blue: 255 / 255)
    ]

    let wrapperColor: Color
    let faceColor: Color
    let backgroundColor: Color
    let wrapperTranslateX: Double
    let wrapperTranslateY: Double
    let wrapperRotate: Double
    let wrapperScale: Double
    let isMouthOpen: Bool
    let isCircle: Bool
    let eyeSpread: Double
    let mouthSpread: Double
    let faceRotate: Double
    let faceTranslateX: Double
    let faceTranslateY: Double

    init(seed: String) {
        let hash = Self.hashCode(seed)
        let backgroundColor = Self.color(hash, index: 0)
        let wrapperColor = Self.color(hash / 10, index: 1)
        self.backgroundColor = backgroundColor
        self.wrapperColor = wrapperColor
        self.faceColor = Self.readableFaceColor(on: wrapperColor)
        self.wrapperTranslateX = Self.unit(hash, range: 10, index: 1)
        self.wrapperTranslateY = Self.unit(hash, range: 10, index: 2)
        self.wrapperRotate = Self.unit(hash, range: 360)
        self.wrapperScale = 1 + Double(hash % 6) / 10
        self.isMouthOpen = Self.digit(hash, position: 2).isMultiple(of: 2)
        self.isCircle = Self.digit(hash, position: 1).isMultiple(of: 2)
        self.eyeSpread = Self.unit(hash, range: 5)
        self.mouthSpread = Self.unit(hash, range: 3)
        self.faceRotate = Self.unit(hash, range: 10, index: 3)
        self.faceTranslateX = wrapperTranslateX > Self.canvasSize / 6
            ? wrapperTranslateX / 2
            : Self.unit(hash, range: 8, index: 1)
        self.faceTranslateY = wrapperTranslateY > Self.canvasSize / 6
            ? wrapperTranslateY / 2
            : Self.unit(hash, range: 7, index: 2)
    }

    private static func hashCode(_ name: String) -> Int {
        var hash = 0
        for scalar in name.unicodeScalars {
            hash = ((hash << 5) - hash + Int(scalar.value))
        }
        return abs(hash)
    }

    private static func digit(_ number: Int, position: Int) -> Int {
        Int(Double(number) / pow(10, Double(position))) % 10
    }

    private static func unit(_ number: Int, range: Int, index: Int? = nil) -> Double {
        let value = number % range
        if let index, digit(number, position: index).isMultiple(of: 2) {
            return Double(-value)
        }
        return Double(value)
    }

    private static func color(_ number: Int, index: Int) -> Color {
        colors[(number + index) % colors.count]
    }

    private static func readableFaceColor(on _: Color) -> Color {
        .black
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let maxWidth = proposal.width ?? 584
        let rows = rows(in: subviews, maxWidth: maxWidth)
        return CGSize(
            width: maxWidth,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var origin = bounds.origin
        for row in rows(in: subviews, maxWidth: bounds.width) {
            origin.x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: origin.x, y: origin.y),
                    proposal: ProposedViewSize(item.size)
                )
                origin.x += item.size.width + spacing
            }
            origin.y += row.height + rowSpacing
        }
    }

    private func rows(in subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var current = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = FlowRow()
            }
            current.append(index: index, size: size, spacing: spacing)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct FlowRow {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(index: Int, size: CGSize, spacing: CGFloat) {
            width += items.isEmpty ? size.width : size.width + spacing
            height = max(height, size.height)
            items.append((index, size))
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

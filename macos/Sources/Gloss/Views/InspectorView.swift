import SwiftUI
import GlossKit

/// Inspector sidebar showing table of contents and frontmatter metadata.
struct InspectorView: View {
    let headings: [HeadingInfo]
    let frontmatter: FrontmatterData?
    var hasDocument: Bool = false
    var onHeadingTap: ((String) -> Void)?

    private var hasContent: Bool {
        !headings.isEmpty || (frontmatter != nil && !frontmatter!.fields.isEmpty)
    }

    var body: some View {
        if hasContent {
            List {
                if !headings.isEmpty {
                    Section("Table of Contents") {
                        ForEach(Array(headings.enumerated()), id: \.offset) { _, heading in
                            Button {
                                onHeadingTap?(heading.id)
                            } label: {
                                Text(heading.text)
                                    .lineLimit(2)
                                    .font(fontForLevel(heading.level))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, CGFloat((heading.level - 1) * 12))
                        }
                    }
                }

                if let fm = frontmatter, !fm.fields.isEmpty {
                    Section("Frontmatter") {
                        ForEach(Array(fm.fields.enumerated()), id: \.offset) { _, field in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(field.value)
                                    .font(.caption)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        } else {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: hasDocument ? "list.bullet" : "doc.text")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(hasDocument ? "No Outline" : "No Document")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(hasDocument
                    ? "This document has no headings or frontmatter."
                    : "Open a markdown file to see its outline.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: .body.weight(.bold)
        case 2: .body.weight(.semibold)
        case 3: .body
        default: .caption
        }
    }
}

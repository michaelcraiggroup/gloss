import SwiftUI
import GlossKit

/// Inspector sidebar showing table of contents, frontmatter, tags, forward links, and backlinks.
struct InspectorView: View {
    let headings: [HeadingInfo]
    let frontmatter: FrontmatterData?
    let tags: [String]
    let forwardLinks: [ForwardLinkGroup]
    let backlinks: [BacklinkGroup]
    var unlinkedMentions: [UnlinkedMention] = []
    var hasDocument: Bool = false
    var onHeadingTap: ((String) -> Void)?
    var onTagTap: ((String) -> Void)?
    var onForwardLinkTap: ((IndexedLink) -> Void)?
    var onBacklinkTap: ((String) -> Void)?
    var onUnlinkedMentionTap: ((String) -> Void)?
    var onPropertyChange: ((String, String) -> Void)?
    var onPropertyRemove: ((String) -> Void)?

    @State private var editingKey: String?
    @State private var editingValue: String = ""
    @State private var newPropertyKey: String = ""
    @State private var newPropertyValue: String = ""

    private var hasContent: Bool {
        !headings.isEmpty
            || (frontmatter != nil && !frontmatter!.fields.isEmpty)
            || !tags.isEmpty
            || !forwardLinks.isEmpty
            || !backlinks.isEmpty
            || !unlinkedMentions.isEmpty
            || hasDocument
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

                if hasDocument {
                    Section("Properties") {
                        if let fm = frontmatter {
                            ForEach(Array(fm.fields.enumerated()), id: \.offset) { _, field in
                                propertyRow(key: field.key, value: field.value)
                            }
                        }
                        addPropertyRow
                    }
                }

                if !tags.isEmpty {
                    Section("Tags") {
                        TagFlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Button {
                                    onTagTap?(tag)
                                } label: {
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.teal.opacity(0.15))
                                        .foregroundStyle(.teal)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .spotlightTarget(.inspectorTags)
                }

                if !forwardLinks.isEmpty {
                    Section("Forward Links") {
                        ForEach(forwardLinks) { group in
                            HStack(spacing: 4) {
                                Image(systemName: group.linkType.icon)
                                    .font(.caption2)
                                Text("\(group.linkType.displayName) (\(group.links.count))")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)

                            ForEach(group.links, id: \.stableKey) { link in
                                Button {
                                    onForwardLinkTap?(link)
                                } label: {
                                    HStack(spacing: 6) {
                                        if !link.isResolved {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.red.opacity(0.7))
                                                .help("Unresolved — no matching file")
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(link.displayText ?? link.targetName)
                                                .font(.caption)
                                                .foregroundStyle(link.isResolved ? .primary : .secondary)
                                                .lineLimit(1)
                                            if let line = link.lineNumber {
                                                Text("Line \(line)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!link.isResolved)
                                .padding(.leading, 8)
                            }
                        }
                    }
                }

                if !backlinks.isEmpty {
                    Section("Backlinks") {
                        ForEach(backlinks) { group in
                            HStack(spacing: 4) {
                                Image(systemName: group.linkType.icon)
                                    .font(.caption2)
                                Text("\(group.linkType.displayName) (\(group.links.count))")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)

                            ForEach(group.links, id: \.stableKey) { link in
                                Button {
                                    onBacklinkTap?(link.sourcePath)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(link.sourceTitle)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if let line = link.lineNumber {
                                            Text("Line \(line)")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                        }
                    }
                }

                if !unlinkedMentions.isEmpty {
                    Section("Unlinked Mentions") {
                        ForEach(unlinkedMentions) { mention in
                            Button {
                                onUnlinkedMentionTap?(mention.path)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mention.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(mention.snippet)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
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

    @ViewBuilder
    private func propertyRow(key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if editingKey == key {
                    TextField("value", text: $editingValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            onPropertyChange?(key, editingValue)
                            editingKey = nil
                        }
                } else {
                    Text(value.isEmpty ? "—" : value)
                        .font(.caption)
                        .lineLimit(3)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingValue = value
                            editingKey = key
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                onPropertyRemove?(key)
            } label: {
                Image(systemName: "minus.circle").font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Remove property")
        }
    }

    private var addPropertyRow: some View {
        HStack(spacing: 6) {
            TextField("key", text: $newPropertyKey)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 90)
            TextField("value", text: $newPropertyValue)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            Button {
                let k = newPropertyKey.trimmingCharacters(in: .whitespaces)
                guard !k.isEmpty else { return }
                onPropertyChange?(k, newPropertyValue)
                newPropertyKey = ""
                newPropertyValue = ""
            } label: {
                Image(systemName: "plus.circle").font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(newPropertyKey.trimmingCharacters(in: .whitespaces).isEmpty)
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

/// A simple flow layout that wraps content horizontally.
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                // Wrap to next row
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

import SwiftUI

/// Vault-wide dashboard shown in the detail pane when a folder is open
/// but no document is selected. Surfaces file/link counts, hub documents,
/// orphans, a tag cloud, broken links, and recently-changed files.
struct VaultOverviewView: View {
    @Environment(VaultOverviewService.self) private var overview
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(LinkIndex.self) private var linkIndex

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                if !overview.hubs.isEmpty {
                    hubsSection
                }
                if !overview.topTags.isEmpty {
                    tagCloudSection
                }
                if !overview.recentlyChanged.isEmpty {
                    recentSection
                }
                if !overview.orphans.isEmpty {
                    orphansSection
                }
                if !overview.brokenLinks.isEmpty {
                    brokenSection
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fileTree.folderName)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Vault Overview")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            StatTile(
                title: "Files",
                value: "\(overview.fileCount)",
                systemImage: "doc.text",
                tint: .blue
            )
            StatTile(
                title: "Links",
                value: "\(overview.linkCount)",
                systemImage: "link",
                tint: .indigo
            )
            StatTile(
                title: "Tags",
                value: "\(overview.tagCount)",
                systemImage: "tag",
                tint: .teal
            )
            StatTile(
                title: "Broken Links",
                value: "\(overview.brokenCount)",
                systemImage: "exclamationmark.triangle",
                tint: overview.brokenCount > 0 ? .red : .secondary
            )
        }
    }

    // MARK: - Hubs

    private var hubsSection: some View {
        SectionCard(title: "Hub Documents", systemImage: "star.circle") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(overview.hubs) { hub in
                    Button {
                        openFile(path: hub.path)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(hub.title)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(hub.linkCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.secondary.opacity(0.15))
                                )
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tag cloud

    private var tagCloudSection: some View {
        SectionCard(title: "Tags", systemImage: "tag") {
            TagFlowLayout(spacing: 8) {
                ForEach(overview.topTags) { tag in
                    Button {
                        fileTree.filterByTag(tag.tag, files: linkIndex.files(forTag: tag.tag))
                    } label: {
                        Text("#\(tag.tag)")
                            .font(tagFont(for: tag.count))
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.teal.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("\(tag.count) file\(tag.count == 1 ? "" : "s")")
                }
            }
        }
    }

    private func tagFont(for count: Int) -> Font {
        let maxCount = overview.topTags.map(\.count).max() ?? 1
        let ratio = Double(count) / Double(max(maxCount, 1))
        // Scale 0.85x .. 1.35x body
        let scale = 0.85 + ratio * 0.5
        return .system(size: 13 * scale, weight: ratio > 0.7 ? .semibold : .regular)
    }

    // MARK: - Recent

    private var recentSection: some View {
        SectionCard(title: "Recently Changed", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(overview.recentlyChanged) { file in
                    Button {
                        openFile(path: file.path)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(file.title)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(file.modifiedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Orphans

    private var orphansSection: some View {
        SectionCard(title: "Orphans", systemImage: "leaf") {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(overview.orphans) { orphan in
                        Button {
                            openFile(path: orphan.path)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(orphan.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("\(overview.orphans.count) file\(overview.orphans.count == 1 ? "" : "s") with no links")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Broken links

    private var brokenSection: some View {
        SectionCard(title: "Broken Links", systemImage: "exclamationmark.triangle") {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(overview.brokenLinks, id: \.stableKey) { link in
                        Button {
                            openFile(path: link.sourcePath)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.sourceTitle)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("→ \(link.targetName)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let line = link.lineNumber {
                                    Text("Line \(line)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            } label: {
                brokenLinksLabel
            }
        }
    }

    @ViewBuilder
    private var brokenLinksLabel: some View {
        let count = overview.brokenLinks.count
        let text = Text("\(count) broken link\(count == 1 ? "" : "s")").font(.subheadline)
        if count == 0 {
            text.foregroundStyle(.secondary)
        } else {
            text.foregroundStyle(.red)
        }
    }

    // MARK: - Navigation

    private func openFile(path: String) {
        let url = URL(fileURLWithPath: path)
        settings.currentFileURL = url
        settings.lastOpenedFile = url.standardizedFileURL.path
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

// MARK: - Section Card

private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

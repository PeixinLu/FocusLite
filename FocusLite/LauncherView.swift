import AppKit
import SwiftUI

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                if let prefix = viewModel.searchState.activePrefix {
                    TagView(title: prefix.title, subtitle: prefix.subtitle)
                }

                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .focused($isSearchFocused)
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.updateInput(newValue)
                    }
                    .onSubmit {
                        viewModel.submitPrimaryAction()
                    }

                Button {
                    viewModel.openSnippetsManager()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            if showsPreviewPane {
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.results.isEmpty {
                                EmptyStateView()
                                    .padding(.top, 40)
                            } else {
                                ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                                    ResultRow(item: item, isSelected: viewModel.selectedIndex == index)
                                        .onTapGesture {
                                            viewModel.selectIndex(index)
                                        }
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(width: 340)

                    Divider()

                    PreviewPane(item: viewModel.highlightedItem)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.results.isEmpty {
                            EmptyStateView()
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                                ResultRow(item: item, isSelected: viewModel.selectedIndex == index)
                                    .onTapGesture {
                                        viewModel.selectIndex(index)
                                    }
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .frame(width: showsPreviewPane ? 820 : 640, height: showsPreviewPane ? 460 : 420)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: viewModel.focusToken) { _ in
            isSearchFocused = true
        }
        .onExitCommand {
            viewModel.handleEscapeKey()
        }
        .overlay(alignment: .topTrailing) {
            if let message = viewModel.toastMessage {
                ToastView(message: message)
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage != nil)
    }

    private var showsPreviewPane: Bool {
        guard case .prefixed(let providerID) = viewModel.searchState.scope else { return false }
        return providerID == ClipboardProvider.providerID || providerID == SnippetsProvider.providerID
    }
}

private struct ResultRow: View {
    let item: ResultItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if item.isPrefix {
                        Text("Prefix")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                }
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(item.isPrefix ? .accentColor : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundColor(.accentColor)
        case .bundle(let name):
            if let image = NSImage(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                placeholderIcon
            }
        case .filePath(let path):
            if let image = AppIconCache.shared.icon(for: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                placeholderIcon
            }
        case .none:
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .tertiaryLabelColor))
            .frame(width: 28, height: 28)
            .opacity(0.4)
    }
}

private struct PreviewPane: View {
    let item: ResultItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let item {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Divider()
                content(for: item)
            } else {
                Text("Select an item to preview")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func content(for item: ResultItem) -> some View {
        if item.providerID == ClipboardProvider.providerID || item.providerID == SnippetsProvider.providerID {
            switch item.preview {
            case .text(let text):
                ScrollView {
                    Text(text)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            case .image(let data):
                if let image = NSImage(data: data) {
                    ScrollView {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(8)
                    }
                } else {
                    Text("Cannot preview image")
                        .foregroundColor(.secondary)
                }
            case .files(let files):
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(files, id: \.self) { file in
                            HStack(spacing: 8) {
                                if let icon = AppIconCache.shared.icon(for: file.path) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "doc")
                                        .frame(width: 24, height: 24)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(file.path)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                    }
                }
            case .none:
                Text("No preview available")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        } else {
            Text("预览仅适用于剪贴板和 Snippets")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Start typing to search")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("Results will appear here")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(radius: 2)
            )
            .foregroundColor(.primary)
    }
}

private final class AppIconCache {
    static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()

    func icon(for path: String) -> NSImage? {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }

        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

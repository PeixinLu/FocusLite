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

                TextField("Search", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .focused($isSearchFocused)
                    .onChange(of: viewModel.query) { newValue in
                        viewModel.search(query: newValue)
                    }
            }
            .padding(16)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.results.isEmpty {
                        EmptyStateView()
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.results) { item in
                            ResultRow(item: item)
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .frame(width: 640, height: 420)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: viewModel.focusToken) { _ in
            isSearchFocused = true
        }
        .onExitCommand {
            viewModel.handleExit()
        }
    }
}

private struct ResultRow: View {
    let item: ResultItem

    var body: some View {
        HStack(spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
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

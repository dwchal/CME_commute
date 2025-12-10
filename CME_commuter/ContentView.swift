import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ArticleFeedViewModel()

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Infectious Disease Briefings")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .accessibilityLabel("Refresh articles")
                    }
                }
        }
        .task {
            await viewModel.refresh()
        }
    }

    private var content: some View {
        Group {
            if viewModel.articles.isEmpty && viewModel.isLoading {
                ProgressView("Loading latest articles…")
            } else if viewModel.articles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(viewModel.errorMessage ?? "No articles available yet.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    ForEach(ArticleSource.allCases, id: \._self) { source in
                        Section(source.displayName) {
                            ForEach(viewModel.articles.filter { $0.source == source }) { article in
                                ArticleRow(article: article) {
                                    viewModel.speakSummary(for: article)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

private struct ArticleRow: View {
    let article: Article
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
                .multilineTextAlignment(.leading)
            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 12) {
                Link("Open", destination: article.url)
                Button {
                    onPlay()
                } label: {
                    Label("Play", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ArticleFeedViewModel()
    @State private var showingTopicBrief = false
    @State private var topicQuery = ""

    var body: some View {
        NavigationView {
            content
                .navigationTitle("ID Briefings")
                .searchable(text: $viewModel.searchQuery, prompt: "Search articles")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 12) {
                            Button {
                                showingTopicBrief = true
                            } label: {
                                Image(systemName: "mic.circle.fill")
                            }
                            .accessibilityLabel("Topic brief")

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
                .safeAreaInset(edge: .bottom) {
                    if viewModel.isPlaying || viewModel.speechSynthesizer.isPaused {
                        NowPlayingBar(viewModel: viewModel)
                    }
                }
        }
        .task {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingTopicBrief) {
            TopicBriefSheet(viewModel: viewModel, topicQuery: $topicQuery)
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
                articleList
            }
        }
    }

    private var articleList: some View {
        let articles = viewModel.filteredArticles

        return List {
            if !viewModel.searchQuery.isEmpty && articles.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchQuery)
            } else {
                ForEach(ArticleSource.allCases, id: \.self) { source in
                    let sourceArticles = articles.filter { $0.source == source }
                    if !sourceArticles.isEmpty {
                        Section(source.displayName) {
                            ForEach(sourceArticles) { article in
                                ArticleRow(article: article, isPlaying: viewModel.currentlyPlayingTitle == article.title) {
                                    viewModel.speakSummary(for: article)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Article Row

private struct ArticleRow: View {
    let article: Article
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(article.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.blue)
                        .symbolEffect(.variableColor.iterative)
                }
            }
            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 12) {
                Link("Open", destination: article.url)
                Button {
                    onPlay()
                } label: {
                    Label(isPlaying ? "Playing" : "Play", systemImage: isPlaying ? "speaker.wave.2" : "speaker.wave.2")
                }
                .buttonStyle(.borderless)
                .disabled(isPlaying)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Now Playing Bar

private struct NowPlayingBar: View {
    @ObservedObject var viewModel: ArticleFeedViewModel

    var body: some View {
        HStack {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.blue)
                .symbolEffect(.variableColor.iterative)

            VStack(alignment: .leading, spacing: 2) {
                Text("Now Playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.currentlyPlayingTitle ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                if viewModel.speechSynthesizer.isPaused {
                    Button {
                        viewModel.resumePlayback()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                } else {
                    Button {
                        viewModel.pausePlayback()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                    }
                }

                Button {
                    viewModel.stopPlayback()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Topic Brief Sheet

private struct TopicBriefSheet: View {
    @ObservedObject var viewModel: ArticleFeedViewModel
    @Binding var topicQuery: String
    @Environment(\.dismiss) private var dismiss

    private let suggestedTopics = [
        "COVID", "Influenza", "Antibiotics", "Vaccination",
        "HIV", "Hepatitis", "Sepsis", "Pneumonia",
        "Fungal", "Bacterial", "Viral", "Resistance"
    ]

    var body: some View {
        NavigationView {
            List {
                Section("Enter a Topic") {
                    HStack {
                        TextField("e.g., COVID, Antibiotics", text: $topicQuery)
                            .textFieldStyle(.plain)
                            .submitLabel(.go)
                            .onSubmit {
                                requestBrief(for: topicQuery)
                            }

                        Button {
                            requestBrief(for: topicQuery)
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                        }
                        .disabled(topicQuery.isEmpty)
                    }
                }

                Section("Quick Topics") {
                    ForEach(suggestedTopics, id: \.self) { topic in
                        Button {
                            requestBrief(for: topic)
                        } label: {
                            HStack {
                                Text(topic)
                                    .foregroundStyle(.primary)
                                Spacer()
                                let count = viewModel.searchArticles(for: topic).count
                                Text("\(count) articles")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Topic Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func requestBrief(for topic: String) {
        viewModel.speakTopicBrief(for: topic)
        dismiss()
    }
}

#Preview {
    ContentView()
}

import AVFoundation
import Foundation

@MainActor
final class ArticleFeedViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let speechSynthesizer = SpeechSynthesizer()

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var latest: [Article] = []
            for source in ArticleSource.allCases {
                let sourceArticles = try await fetchArticles(from: source)
                latest.append(contentsOf: sourceArticles)
            }
            articles = latest.sorted { $0.title < $1.title }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load articles: \(error.localizedDescription)"
        }
    }

    func speakSummary(for article: Article) {
        speechSynthesizer.speak(article.summary)
    }

    private func fetchArticles(from source: ArticleSource) async throws -> [Article] {
        var request = URLRequest(url: source.url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return parseArticles(from: html, source: source)
    }

    private func parseArticles(from html: String, source: ArticleSource) -> [Article] {
        let pattern = "<h5[^>]*class=\\\"[^\\\"]*al-article-item-title[^\\\"]*\\\"[^>]*>\\s*<a[^>]*href=\\\"([^\\\"]+)\\\"[^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        let limitedMatches = matches.prefix(10)
        return limitedMatches.compactMap { match in
            guard match.numberOfRanges == 3,
                  let linkRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            let linkPath = String(html[linkRange])
            let title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: linkPath, relativeTo: source.url) else { return nil }
            let summary = summarize(title: title, html: html, around: match.range)

            return Article(title: title, summary: summary, url: url, source: source)
        }
    }

    private func summarize(title: String, html: String, around range: NSRange) -> String {
        // Attempt to pull a nearby paragraph for a lightweight summary.
        if let paragraph = nearbyParagraph(in: html, around: range) {
            return paragraph
        }

        return "Summary not available yet. Tap to open the article for full details on \(title)."
    }

    private func nearbyParagraph(in html: String, around range: NSRange) -> String? {
        let searchRadius = 1500
        let start = max(0, range.location - searchRadius)
        let end = min(html.count, range.location + range.length + searchRadius)
        let snippetRange = NSRange(location: start, length: end - start)
        guard let range = Range(snippetRange, in: html) else { return nil }
        let snippet = String(html[range])

        let paragraphPattern = "<p[^>]*>(.*?)</p>"
        guard let regex = try? NSRegularExpression(pattern: paragraphPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let matches = regex.matches(in: snippet, range: NSRange(snippet.startIndex..<snippet.endIndex, in: snippet))
        if let first = matches.first, let paragraphRange = Range(first.range(at: 1), in: snippet) {
            let raw = snippet[paragraphRange]
            return raw
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}

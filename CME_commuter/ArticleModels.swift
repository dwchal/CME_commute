import Foundation

struct Article: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let url: URL
    let source: ArticleSource
}

enum ArticleSource: CaseIterable {
    case ofid
    case cid

    var displayName: String {
        switch self {
        case .ofid:
            return "Open Forum Infectious Diseases"
        case .cid:
            return "Clinical Infectious Diseases"
        }
    }

    var url: URL {
        switch self {
        case .ofid:
            return URL(string: "https://academic.oup.com/ofid")!
        case .cid:
            return URL(string: "https://academic.oup.com/cid")!
        }
    }
}

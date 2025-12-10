import CarPlay
import Foundation

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let viewModel = ArticleFeedViewModel()

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Task {
            await viewModel.refresh()
            await MainActor.run { [weak self] in
                self?.renderArticles()
            }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    private func renderArticles() {
        let items = viewModel.articles.map { article in
            let item = CPListItem(text: article.title, detailText: article.source.displayName)
            item.handler = { [weak self] _, completion in
                self?.viewModel.speakSummary(for: article)
                completion()
            }
            return item
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Recent Articles", sections: [section])
        interfaceController?.setRootTemplate(template, animated: true)
    }
}

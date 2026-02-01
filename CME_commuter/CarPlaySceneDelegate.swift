import CarPlay
import Foundation

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let viewModel = ArticleFeedViewModel()

    // Common medical/infectious disease topics for quick access
    private let suggestedTopics = [
        "COVID", "Influenza", "Antibiotics", "Vaccination",
        "HIV", "Hepatitis", "Sepsis", "Pneumonia",
        "Fungal", "Bacterial", "Viral", "Resistance"
    ]

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Task {
            await viewModel.refresh()
            await MainActor.run { [weak self] in
                self?.setupTabBarInterface()
            }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController) {
        viewModel.stopPlayback()
        self.interfaceController = nil
    }

    // MARK: - Tab Bar Interface

    private func setupTabBarInterface() {
        let articlesTemplate = createArticlesTemplate()
        let topicBriefTemplate = createTopicBriefTemplate()
        let nowPlayingTemplate = createNowPlayingTemplate()

        articlesTemplate.tabImage = UIImage(systemName: "newspaper")
        topicBriefTemplate.tabImage = UIImage(systemName: "mic.circle")
        nowPlayingTemplate.tabImage = UIImage(systemName: "speaker.wave.2.circle")

        let tabBar = CPTabBarTemplate(templates: [articlesTemplate, topicBriefTemplate, nowPlayingTemplate])
        interfaceController?.setRootTemplate(tabBar, animated: true)
    }

    // MARK: - Articles Tab

    private func createArticlesTemplate() -> CPListTemplate {
        let items = viewModel.articles.map { article in
            let item = CPListItem(text: article.title, detailText: article.source.displayName)
            item.handler = { [weak self] _, completion in
                self?.viewModel.speakSummary(for: article)
                self?.showNowPlaying()
                completion()
            }
            return item
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Recent Articles", sections: [section])
        template.tabTitle = "Articles"
        return template
    }

    // MARK: - Topic Brief Tab (Voice Input)

    private func createTopicBriefTemplate() -> CPListTemplate {
        // Voice input item at the top
        let voiceItem = CPListItem(
            text: "Ask for a Topic Brief",
            detailText: "Tap to speak your topic"
        )
        voiceItem.setImage(UIImage(systemName: "mic.fill"))
        voiceItem.handler = { [weak self] _, completion in
            self?.presentVoiceInput()
            completion()
        }

        let voiceSection = CPListSection(items: [voiceItem], header: "Voice Request", sectionIndexTitle: nil)

        // Suggested topics for quick access
        let topicItems = suggestedTopics.map { topic in
            let item = CPListItem(text: topic, detailText: "Tap for brief")
            item.handler = { [weak self] _, completion in
                self?.viewModel.speakTopicBrief(for: topic)
                self?.showNowPlaying()
                completion()
            }
            return item
        }

        let suggestedSection = CPListSection(items: topicItems, header: "Quick Topics", sectionIndexTitle: nil)

        let template = CPListTemplate(title: "Topic Brief", sections: [voiceSection, suggestedSection])
        template.tabTitle = "Topic Brief"
        return template
    }

    // MARK: - Now Playing Tab

    private func createNowPlayingTemplate() -> CPListTemplate {
        var items: [CPListItem] = []

        // Current playback status
        let statusText = viewModel.isPlaying ? "Now Playing" : "Nothing Playing"
        let detailText = viewModel.currentlyPlayingTitle ?? "Select an article or topic"
        let statusItem = CPListItem(text: statusText, detailText: detailText)
        statusItem.setImage(UIImage(systemName: viewModel.isPlaying ? "speaker.wave.3.fill" : "speaker.slash"))
        items.append(statusItem)

        // Playback controls
        if viewModel.isPlaying || viewModel.speechSynthesizer.isPaused {
            if viewModel.speechSynthesizer.isPaused {
                let resumeItem = CPListItem(text: "Resume", detailText: nil)
                resumeItem.setImage(UIImage(systemName: "play.fill"))
                resumeItem.handler = { [weak self] _, completion in
                    self?.viewModel.resumePlayback()
                    self?.refreshNowPlaying()
                    completion()
                }
                items.append(resumeItem)
            } else {
                let pauseItem = CPListItem(text: "Pause", detailText: nil)
                pauseItem.setImage(UIImage(systemName: "pause.fill"))
                pauseItem.handler = { [weak self] _, completion in
                    self?.viewModel.pausePlayback()
                    self?.refreshNowPlaying()
                    completion()
                }
                items.append(pauseItem)
            }

            let stopItem = CPListItem(text: "Stop", detailText: nil)
            stopItem.setImage(UIImage(systemName: "stop.fill"))
            stopItem.handler = { [weak self] _, completion in
                self?.viewModel.stopPlayback()
                self?.refreshNowPlaying()
                completion()
            }
            items.append(stopItem)
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Now Playing", sections: [section])
        template.tabTitle = "Playing"
        return template
    }

    // MARK: - Voice Input

    private func presentVoiceInput() {
        let voiceTemplate = CPVoiceControlTemplate(voiceControlStates: [
            CPVoiceControlState(identifier: "listening", titleVariants: ["Listening..."], image: nil, repeats: false),
            CPVoiceControlState(identifier: "processing", titleVariants: ["Processing..."], image: nil, repeats: false)
        ])

        interfaceController?.presentTemplate(voiceTemplate, animated: true) { [weak self] success, error in
            if success {
                // In a real implementation, this would integrate with Speech framework
                // For now, show a search list after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self?.interfaceController?.dismissTemplate(animated: true) { _, _ in
                        self?.showTopicSearchResults()
                    }
                }
            }
        }
    }

    private func showTopicSearchResults() {
        // Show recent search or popular topics
        let items = suggestedTopics.prefix(6).map { topic in
            let matchCount = self.viewModel.searchArticles(for: topic).count
            let item = CPListItem(text: topic, detailText: "\(matchCount) articles")
            item.handler = { [weak self] _, completion in
                self?.viewModel.speakTopicBrief(for: topic)
                self?.interfaceController?.popTemplate(animated: true) { _, _ in
                    self?.showNowPlaying()
                }
                completion()
            }
            return item
        }

        let section = CPListSection(items: Array(items), header: "Select a Topic", sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Topics", sections: [section])

        template.backButton = CPBarButton(title: "Back") { [weak self] _ in
            self?.interfaceController?.popTemplate(animated: true, completion: nil)
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Navigation Helpers

    private func showNowPlaying() {
        // Switch to Now Playing tab after starting playback
        guard let tabBar = interfaceController?.rootTemplate as? CPTabBarTemplate else { return }

        // Refresh the now playing template
        let newNowPlayingTemplate = createNowPlayingTemplate()
        newNowPlayingTemplate.tabImage = UIImage(systemName: "speaker.wave.2.circle")

        var templates = tabBar.templates
        if templates.count >= 3 {
            templates[2] = newNowPlayingTemplate
            tabBar.updateTemplates(templates)
            tabBar.selectedTemplate = newNowPlayingTemplate
        }
    }

    private func refreshNowPlaying() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showNowPlaying()
        }
    }
}

import Combine
import UIKit

@MainActor
protocol BackgroundImageObserver: UIView {
    var cancellables: Set<AnyCancellable> { get set }
    var backgroundImageLoadTask: Task<Void, Never>? { get set }
}

extension BackgroundImageObserver {
    func observeBackgroundImage(context: UIBlockContext, urlTemplate: String) {
        guard hasPlaceholderPath(template: urlTemplate) else {
            self.backgroundImageLoadTask?.cancel()
            self.backgroundImageLoadTask = loadAsyncImageToBackgroundSrc(url: urlTemplate, view: self)
            return
        }

        context.variablePublisher()
            .map { compile(urlTemplate, $0) }
            .removeDuplicates()
            .sink { [weak self] src in
                guard let self else { return }
                self.backgroundImageLoadTask?.cancel()
                self.backgroundImageLoadTask = loadAsyncImageToBackgroundSrc(url: src, view: self)
            }
            .store(in: &self.cancellables)
    }
}

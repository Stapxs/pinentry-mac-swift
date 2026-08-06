import Foundation

@MainActor
final class WindowPresentationCoordinator: ObservableObject, PinentryPresenter {
    @Published private(set) var activeViewModel: DialogViewModel?

    private let iconResolver: any IconResolving
    private let qualityEstimator: any PassphraseQualityEstimating
    private let timeoutController: any TimeoutControlling
    private var continuation: CheckedContinuation<DialogResponse, Never>?

    init(
        previewDialog: DialogModel? = nil,
        iconResolver: any IconResolving = IconResolver(),
        qualityEstimator: any PassphraseQualityEstimating = HeuristicQualityEstimator(),
        timeoutController: any TimeoutControlling = TimeoutController()
    ) {
        self.iconResolver = iconResolver
        self.qualityEstimator = qualityEstimator
        self.timeoutController = timeoutController

        if let previewDialog {
            activeViewModel = makeViewModel(for: previewDialog)
        }
    }

    func present(dialog: DialogModel) async -> DialogResponse {
        activeViewModel = makeViewModel(for: dialog)

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func makeViewModel(for dialog: DialogModel) -> DialogViewModel {
        DialogViewModel(
            dialog: dialog,
            iconResolver: iconResolver,
            qualityEstimator: qualityEstimator,
            timeoutController: timeoutController
        ) { [weak self] response in
            self?.finish(response)
        }
    }

    private func finish(_ response: DialogResponse) {
        continuation?.resume(returning: response)
        continuation = nil
        activeViewModel = nil
    }
}

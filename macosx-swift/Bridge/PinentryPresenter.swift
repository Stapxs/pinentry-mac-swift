import Foundation

@MainActor
protocol PinentryPresenter {
    func present(dialog: DialogModel) async -> DialogResponse
}

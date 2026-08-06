import Foundation

protocol TimeoutControlling {
    @discardableResult
    func start(
        timeoutSeconds: Int,
        onTick: @escaping @MainActor (Int) -> Void,
        onExpire: @escaping @MainActor () -> Void
    ) -> Task<Void, Never>
}

struct TimeoutController: TimeoutControlling {
    @discardableResult
    func start(
        timeoutSeconds: Int,
        onTick: @escaping @MainActor (Int) -> Void,
        onExpire: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task {
            for second in stride(from: timeoutSeconds, through: 0, by: -1) {
                guard !Task.isCancelled else {
                    return
                }

                await onTick(second)

                if second == 0 {
                    break
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard !Task.isCancelled else {
                return
            }

            await onExpire()
        }
    }
}

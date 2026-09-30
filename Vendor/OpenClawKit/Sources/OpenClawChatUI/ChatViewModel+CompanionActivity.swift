import Foundation

extension OpenClawChatViewModel {
    /// Reuses the upstream ownership projection; callers must also gate by
    /// current connection availability. A count falling to zero is not success.
    public var companionHasActiveResponse: Bool {
        !self.isTransportDetached && self.hasActiveRunForComposerSettings
    }
}

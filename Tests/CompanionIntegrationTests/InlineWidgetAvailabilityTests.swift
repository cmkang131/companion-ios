import Foundation
import OpenClawKit
import Testing
@testable import Companion
@testable import OpenClawChatUI

@MainActor
struct InlineWidgetAvailabilityTests {
    @Test func implementedResolverWaitsForConnectionThenRetriesAfterRecovery() async throws {
        let transport: any OpenClawChatTransport = IOSGatewayChatTransport(gateway: GatewayNodeSession())
        let model = OpenClawChatViewModel(sessionKey: "widget-policy-only", transport: transport)
        #expect(transport.supportsInlineWidgetLoading)
        #expect(model.inlineWidgetAvailability == .waitingForConnection)
        #expect(model.inlineWidgetAvailability.statusMessage != nil)
        let probe = ResolverProbe()
        let path = "/__openclaw__/canvas/documents/test/index.html"
        let resource = OpenClawChatWidgetResource(url: try #require(URL(string: "https://example.invalid/widget")))

        func resolve() async -> OpenClawChatWidgetResource? {
            await model.inlineWidgetAvailability.resolve(path: path, replacing: resource) { receivedPath, previous in
                probe.paths.append(receivedPath)
                probe.previousResources.append(previous)
                return resource
            }
        }

        #expect(await resolve() == nil)
        #expect(probe.paths.isEmpty)
        // Only simulate the UI connection flag; this tests the production gate,
        // not server access, WebKit rendering, or the remote capability resolver.
        model.healthOK = true
        #expect(model.inlineWidgetAvailability.statusMessage == nil)
        #expect(await resolve() == resource)
        model.healthOK = false
        #expect(await resolve() == nil)
        model.healthOK = true
        #expect(await resolve() == resource)
        #expect(probe.paths == [path, path])
        #expect(probe.previousResources == [resource, resource])
    }

    @Test func defaultResolverReportsUnsupportedWithoutRequestingConnection() async {
        let transport: any OpenClawChatTransport = PreviewTransport()
        let model = OpenClawChatViewModel(sessionKey: "widget-policy-only", transport: transport)
        #expect(!transport.supportsInlineWidgetLoading)
        model.healthOK = true
        #expect(model.inlineWidgetAvailability == .unsupported)
        #expect(model.inlineWidgetAvailability.statusMessage != nil)
        let probe = ResolverProbe()
        _ = await model.inlineWidgetAvailability.resolve(path: "unused", replacing: nil) { path, _ in
            probe.paths.append(path)
            return nil
        }
        #expect(probe.paths.isEmpty)
    }

    @MainActor
    private final class ResolverProbe {
        var paths: [String] = []
        var previousResources: [OpenClawChatWidgetResource?] = []
    }
}

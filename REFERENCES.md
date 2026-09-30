# Design decisions and evidence

Updated 2026-09-30 UTC. Native SwiftUI, iOS 26+, light appearance only.

## Evidence boundaries

The parent task supplied two public research reports, summarized in
[Research/MUSE-DOT-EVIDENCE.md](Research/MUSE-DOT-EVIDENCE.md). Promotional
screens demonstrate a depicted layout; published feature descriptions are
official claims. Neither is a test of a signed-in product or this client.
No private Muse/dot API or OpenClaw compatibility is inferred.

The current user-provided Library PNG was downloaded to a private directory
outside this repository and directly inspected on September 30. It depicts a
smooth blue four-lobed character, two dark oval eyes, a small lower-right blue
bump, and a translucent `dot` name pill. The earlier textured reference and
black pebble are superseded. The source screenshot contains private chat and
must never enter the source tree, build resources, or public QA captures.
The character and icon are drawn from SwiftUI paths, not copied image pixels.

## Native decisions

- Keep the MIT OpenClaw chat renderer, transport, message ownership and lifecycle
  machinery. Source-level reuse investigation is in Research/REUSE-REVIEW.md;
  its initial “paused / no code incorporated” statement is historical.
- Use system text styles for iOS body/headings and the native UITextView's
  preferred body font. Preserve upstream code typography and Dynamic Type.
- Use the existing clean composer and gray assistant-bubble environment flag;
  pale blue user bubbles and an almost-white background are app-owned styling.
- The hero name pill uses native `.glassEffect(.regular, in: .capsule)` and an
  opaque capsule when Reduce Transparency is enabled. No simulated glass shader.
- Motion reuses the MIT mascot animator. Character gaze, blink, restrained tilt
  and stretch are rendered, without upstream hats/particles/claws.
- Reduce Motion and presented sheets use a static pose. Background scenes pause
  redraw. Upstream message disclosure/slash-panel transitions now honor Reduce
  Motion, and the disclosure touch target is at least 44 points.
- Working pose requires a connected transport and upstream active-response
  ownership. A brief happy acknowledgement is limited to a correlated final
  assistant message with visible output. It means “response arrived,” never
  purchase, task, delivery, or external-action success. Abort, error, disconnect,
  empty output and an unrelated/duplicate final event do not trigger it.
- Native sheets/settings remain functional. Unsupported voice, remote file download,
  browser takeover, global activity and permissions features are not added as
  ornamental controls. The reused backend-driven components require live tests.

## Sources consulted

- [Apple motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion)
- [SwiftUI glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Apple Liquid Glass sample](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)
- [Apple notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)
- [Apple background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- [Official OpenClaw MIT source](https://github.com/openclaw/openclaw/tree/ebe57ef28af64c073de8264c7052ce519f1fda23/apps/shared/OpenClawKit)

The Apple web text extractor returned JavaScript-only pages on this follow-up;
the native API is verified against the installed SDK and compilation, not a
claim of newly extracted detailed HIG prose. Motion and accessible fallbacks
also follow the public research handed off by the parent. Render/interaction
evidence and remaining uncertainty are recorded in Validation/RECOVERY.md.

## Follow-up: compact mobile conversation

The reviewed Simulator output showed an oversized two-row composer and repetitive
metadata/actions. The mobile shell now opts into the already-vendored
`compactEditor`: it retains the real text editor, attachment menu and send/cancel
controls in one row. Model/effort/branch settings reuse upstream controls in the
connection settings sheet. No unsupported microphone action is added.

Message timestamps remain available in the native long-press menu, formatted with
the Korean shell locale; repetitive bubble footers and inline ellipsis controls
are hidden in this opt-in presentation. Existing context-menu actions are retained.
The welcome explanation is shorter for every text size, without shrinking body text.

[Apple text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)
and [Apple context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus)
were consulted; the text extractor again returned JavaScript-only pages. The concrete
implementation reuses the pinned MIT editor/menu patterns and installed native SDK.
Actual render and interaction limits must be recorded separately after compilation.

## Follow-up: recoverable input and honest outputs

Submitted sends retain the original draft and ready attachment bytes in memory until
acceptance is known. This is scoped to the same endpoint; it is not encrypted disk
persistence and does not survive process termination. Uncertain delivery requires
a fresh history check plus an explicit restore decision, never automatic resending.
The original idempotency key is retained only for an unchanged restored draft.

The existing MIT attachment picker/staging/encoding path is enabled after connection.
Ready files survive model replacement; in-flight imports are explicitly reported as
interrupted rather than inventing missing bytes. Payload tests cannot establish that
every server/model accepts each file type. No fake microphone control is supplied.

The current gateway adapter has no remote-media byte loader. Output media therefore
shows metadata and an explicit unsupported explanation; it does not offer a download
button that silently returns nothing. Inline widgets use the adapter's existing
resolver only while connected and expose an honest disconnected state. Live gateway
acceptance, file interpretation and remote artifact availability remain unverified.

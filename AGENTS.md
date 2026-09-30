# Native companion implementation rules

## User-approved design requirements
- Build a native iOS application in SwiftUI. Prioritize the polish, restraint, and interaction quality of Apple's own applications.
- Do not use emoji in the application's UI, navigation, status messages, sample content, or decorative assets. Use appropriate native SF Symbols for functional icons.
- Avoid generic AI-generated aesthetics: gratuitous gradients, decorative dashboard cards, excessive badges, neon glows, ornamental hero text, and arbitrary visual effects.
- Follow Apple's Human Interface Guidelines and official platform APIs. Use native navigation, sheets, menus, typography, spacing, controls, and accessibility behaviors wherever possible.
- Use Apple's native Liquid Glass APIs where available and appropriate. Provide an accessible native fallback; do not approximate glass with excessive blur or decoration.
- Muse is a visual and interaction reference. Reimplement observed behavior with original code and assets; do not claim fidelity to screens or animations that have not been observed.
- The assistant character should take inspiration from dot's restrained appearance. Do not introduce unrelated mascots or AI-generated decoration.

## Mandatory handling of uncertainty
When a design decision is ambiguous, do not invent a solution without research. First consult relevant Apple HIG/documentation/sample code, then inspect credible design-focused open-source repositories for working implementations. Select the approach compatible with Apple's guidance and the target iOS version. Record the source, what was observed, the rationale, and any remaining uncertainty in REFERENCES.md. Verify the license before copying or adding code; preserve required notices. A repository is a reference, not permission to disregard Apple's guidance.

## Quality gates
- Build and validate LIGHT MODE ONLY. The user explicitly removed dark mode from scope. Respect Dynamic Type, VoiceOver labels, Reduce Motion, Reduce Transparency, safe areas, keyboard avoidance, interactive dismissal, and touch target sizes.
- Test interrupted and repeated flows, including sheet dismissal, navigation changes, loading, empty, disconnected, and error states.
- Never present an unconnected prototype as a working backend integration.
- Syntax parsing and portable unit tests are not an iOS build, a rendered UI review, or device validation. Report these stages separately.
- Before declaring a screen polished, inspect its actual rendered output and compare against the chosen reference. Record untested states rather than assuming they pass.
- Do not install paid services, create signing credentials, publish, or deploy without the required user authorization.

## Reuse-first implementation strategy
- Prefer existing compatible, reviewed implementations for nearly all functionality. The user's target is less than roughly 10% newly written glue/styling code, as an architectural direction, not a verified code-percentage claim.
- Do not build custom transport, chat behavior, animation engines, or infrastructure if suitable reusable implementations already exist.
- Evaluate integration compatibility, licensing, dependencies and actual quality before adopting a library. Avoid incompatible library accumulation that increases integration work.
- Extend and compose the smallest coherent existing foundation rather than assembling unrelated full applications.

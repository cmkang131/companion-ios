# Muse and dot public research handoff

Research date: 2026-09-30. This document records the parent task's two research
reports and their application to this independent companion. It is not a
logged-in product audit. The follow-up did not repeat the original research.

## Evidence classes

1. Observed promotional UI: the parent directly inspected official screenshots
   and timestamped promotional frames; pixels establish depiction, not behavior.
2. Official claim: published product/design/security documentation.
3. Reported observation: attributed third-party account, not reproduced here.
4. Proposal: our app's design/engineering choice.
5. Unknown: unverified; not equivalent to unavailable.

## Muse findings

[Official design rationale](https://introducing.muse.ai/) describes a persistent
main conversation and side chats, overlapping requests, avatar/status, editable
memory, goals, ideas, artifacts and explicit approval controls. An avatar's
status opens activity and permissions. These are official claims.

[App Store listing](https://apps.apple.com/us/app/muse-from-meta/id6760173601):
the parent inspected six promotional screenshots. They depict menu/avatar/name,
gray assistant and pale-blue user bubbles, a separate plus/microphone composer,
PDF/browser/artifact previews and a connector search surface. A five-icon pill
navigation appears; only the Ideas selection is clearly labelled. Do not guess
all other destinations or copy screenshots into app assets.

The official status image depicts a dated activity feed with step/result and
time, an active tinted row and stop control. Goals distinguish ongoing tracking
and finite goals. Checkout depicts merchant review, masked payment, total and
deny/allow controls. Artifact previews have title/type/date. Their interaction,
expiration, acknowledgement and accessibility semantics remain untested.

[Security architecture](https://research.meta.ai/blog/security-and-safety-for-ai-agents-our-approach-with-muse)
describes scoped permission authority, client-native approvals, browser takeover
and protected credential entry. These are Meta's claims, not guarantees this
client can inherit. A WebView alone does not implement safe remote control.

[Launch](https://about.fb.com/news/2026/09/introducing-muse-personal-ai-agent/)
describes background work and user-controlled connections.
[Connect update](https://about.fb.com/news/2026/09/the-biggest-news-from-connect-2026/)
and its [detailed regional version](https://about.fb.com/de/news/2026/09/meta-connect-2026/)
mix existing features and previews. [Business expansion](https://about.fb.com/news/2026/09/introducing-muse-small-business/)
shows that connector membership changes. Availability, region and subscription
details must be checked again before making onboarding promises.

The parent sampled the [official 82.56-second promotional film](https://about.fb.com/ltam/wp-content/uploads/sites/14/2026/09/Muse-Sizzle-16x9-1.mp4):
22s working avatar, 26–29s approval/wait state, 30s completion graphic, 38s typing
bubble, 42–45s browser preview/takeover, 58s flight update. It is a staged motion
graphic, not a continuous iPhone recording. The full YouTube tour was blocked by
a CAPTCHA and is not evidence; it was not bypassed.

## dot findings

[Introducing dots](https://openai.com/index/introducing-dots/) describes overlapping
responsibilities, reviewable results, connected apps and a cloud computer.
[Meet dots](https://learn.chatgpt.com/docs/dots) labels its conversation artwork
as an illustration, with centered character/name, menu/call, message bubbles and
composer. [Product illustrations](https://chatgpt.com/features/dots/) depict tasks
and presentation outputs; they are not exact native iOS specifications.

[Getting started](https://learn.chatgpt.com/docs/dots/getting-started) describes
optional connections and appearance customization. [Tasks and memory](https://learn.chatgpt.com/docs/dots/tasks-and-memory)
distinguishes overlapping tasks and reviewable outcomes: a run completing alone
does not establish that the requested external result was achieved or delivered.

[Controls](https://learn.chatgpt.com/docs/dots/controls) distinguishes task review,
ongoing rules, permission and pause/stop scope. Drafting is not sending; stop is
not rollback. [Computers and apps](https://learn.chatgpt.com/docs/dots/computers-and-apps)
distinguishes viewing, takeover, return control and secure sign-in.
[Messaging](https://learn.chatgpt.com/docs/dots/channels) describes typing during
calls and work continuing separately from the call. These descriptions do not
establish an API this OpenClaw client can invoke.

[Help Center](https://help.openai.com/en/articles/20001530-getting-started-with-your-dot)
describes files/photos, memory and scheduled updates. It differs from detailed
docs in Reset/Delete wording, texting rollout and mobile computer ownership.
Treat those as open questions, not universal UI requirements.
[Safety article](https://openai.com/index/how-we-build-safety-security-and-privacy-into-dots/)
describes permissions and paused work; no corresponding enforcement is claimed
in this client without a tested backend contract.

## Applied priorities and honest gaps

The current patch prioritizes real draft continuity, trustworthy connection and
response state, private diagnostics, native accessible layout, and the latest
user character. Durable tasks, typed approvals, browser takeover, artifact
delivery, notifications, editable memory and live voice need authoritative
backend support and their own end-to-end tests. Their presence in reference
products is not grounds to display fake working controls in a disconnected app.

Highest-value later tests: overlapping sends; approval arriving while reading;
denial/stale approval; network loss without duplicate dispatch; takeover without
concurrent agent actions; acknowledged stop; denied photo/mic access; durable
artifact identity; memory correction; VoiceOver and large-text decision flows.

No official dot protocol, third-party dot API, complete native animation curve
specification, exact mobile notification guarantees or complete artifact support
matrix was established. Do not use unrelated App Store apps named Dot as evidence.

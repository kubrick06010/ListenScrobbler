# Security Policy

## Supported Versions

OpenScrobbler is in early public development. Security fixes are handled on the latest released version and the `main` branch.

## Reporting A Vulnerability

Please do not publish sensitive vulnerability details in a public issue.

Preferred reporting path:

1. Use GitHub private vulnerability reporting for this repository if it is enabled.
2. If private reporting is not available, contact the maintainer through GitHub and ask for a private coordination channel.

Useful details to include:

- Affected version or commit.
- macOS version and app build.
- Steps to reproduce.
- Whether local tokens, listening history, exports, or network requests are affected.
- Any logs or screenshots with secrets removed.

## Sensitive Data

OpenScrobbler can handle ListenBrainz user tokens and local listening archives. Reports and sample files should remove:

- ListenBrainz tokens.
- Local usernames if privacy matters.
- Private listening history, vault exports, or filesystem paths.
- Proxy credentials or network configuration secrets.

Maintainers will prioritize issues that could expose tokens, submit listens as the wrong user, corrupt local archives, or leak private listening data.

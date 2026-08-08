# Recognition-to-scrobble mock contract

This document defines the functional contract behind the proposed “recognize and scrobble” experiment. It intentionally does not choose a visual direction: the full Listening Halo, the Match Desk, and the compact menu-bar Quick Catch can all drive the same state machine.

## Product boundary

The first version is an explicit, user-initiated mock. It must never imply that ListenScrobbler has identified real ambient audio unless a recognizer adapter has returned a result. Mock data is visibly labelled in development builds, and submission always requires confirmation.

The experience is free to the user. The architecture therefore treats recognition as a replaceable adapter rather than coupling the product to a paid provider.

## State machine

1. **Idle** — ready to begin; microphone privacy text is visible before capture.
2. **Capturing** — show elapsed time, input level, and a cancel action. The mock defaults to a short deterministic capture.
3. **Recognizing** — the captured sample is immutable and the recognizer adapter is working.
4. **Matching** — normalize the result against open metadata and prefer stable MusicBrainz identifiers.
5. **Needs confirmation** — show title, artist, release, artwork provenance, confidence, and identifier availability. The user may edit, retry, cancel, or confirm.
6. **Submitting** — create a normal `Track` and hand it to the existing ListenBrainz submission/queue path.
7. **Submitted or queued** — distinguish an acknowledged submission from an offline queued item.
8. **Failed** — preserve the last safe action: retry recognition, edit metadata, or retry submission.

Cancellation is valid from every non-terminal state and must release any microphone resource immediately.

## Neutral data contract

The recognizer output should contain:

- display title, artist, and optional release;
- optional recording MBID and release MBID;
- optional artwork URL and its source;
- confidence from `0...1`, plus a human-readable confidence band;
- recognition source (`mock`, `onDevice`, or named remote adapter);
- capture timestamp and duration;
- whether the result has been normalized against MusicBrainz;
- alternative candidates when a result is ambiguous.

The confirmation step converts this output to the existing `Track` domain model. Recognition-specific fields remain diagnostic metadata and must not alter normal queue deduplication rules.

## Adapter seams

The UI talks to a coordinator with three replaceable collaborators:

- `AudioCaptureProviding` supplies a time-bounded sample and levels.
- `TrackRecognizing` turns a sample into ranked candidates.
- `RecognitionMatchResolving` enriches a candidate with open identifiers and metadata.

The deterministic mock implements all three locally, permits forced success/ambiguous/no-match/network-error scenarios, and performs no paid API call. A future ShazamKit or other recognizer can be added behind `TrackRecognizing` without changing the UI or submission logic.

## Required mock scenarios

- high-confidence match with recording MBID;
- ambiguous match with two candidates;
- recognized metadata without a MusicBrainz identity;
- no match;
- microphone permission denied;
- recognition adapter unavailable;
- successful ListenBrainz submission;
- offline submission queued for retry;
- permanent submission failure with an editable result.

## Privacy and localization acceptance

- No passive background listening.
- No audio leaves the device in mock mode.
- Capture state and provider are always disclosed.
- All visible copy, accessibility labels, errors, dates, numbers, and durations follow the app language and the user's regional conventions.
- English and Spanish layouts must survive long error text and compact menu-bar width without truncating the primary action.

## Definition of done for the selected visual mock

- All state transitions above are interactive, not a static screen.
- A confirmed result enters the same submission or retry queue used by other listens.
- The mock can switch scenarios without rebuilding the app.
- Analytics are local debug events only until a privacy policy is defined.
- Unit tests cover transition legality and result-to-`Track` conversion; UI tests cover success, ambiguity, cancellation, and permission denial.

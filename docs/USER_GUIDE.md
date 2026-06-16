# ListenScrobbler User Guide

ListenScrobbler submits listens to ListenBrainz and enriches them with
MusicBrainz-aware context. It uses a ListenBrainz user token; it never needs your
MusicBrainz password.

## Connect ListenBrainz

1. Create or sign in to a MusicBrainz account.
2. Open your ListenBrainz profile at <https://listenbrainz.org/profile/>.
3. Copy your user token.
4. In ListenScrobbler, open Settings > ListenBrainz.
5. Paste the token into User token.
6. Keep Enable ListenBrainz turned on.
7. Choose Save & Validate.

When validation succeeds, Settings shows the connected ListenBrainz username.

## Choose Submission Behavior

In Settings > ListenBrainz:

- Send now playing announces the current track to ListenBrainz.
- Submit completed listens scrobbles completed plays.

You can turn either option off while keeping the account connected.

## Verify Setup

After connecting:

1. Submit one manual listen, or play a track with the desktop app running.
2. Refresh ListenBrainz in the app.
3. Check your ListenBrainz profile for the submitted listen.

On iOS, the first Music library scan creates a baseline and does not submit old
history. Later scans submit new plays detected from local play-count changes.

## Delete ListenBrainz Listens

ListenScrobbler can delete ListenBrainz listens that include both a listen time
and a ListenBrainz `recording_msid`.

- On macOS, use the delete action from recent listens or recent activity rows.
- On iOS, swipe a recent listen and choose Delete.

ListenBrainz schedules listen deletions for cleanup, so the row disappears from
ListenScrobbler after the request succeeds, but ListenBrainz counts and history
may take time to update server-side.

## Import Older Listening History

Use ListenBrainz's Add Data page for supported web imports and historical data:

<https://listenbrainz.org/add-data/>

ListenScrobbler does not require the old music-services settings page to submit
manual, now-playing, completed, or local Music library listens.

## Troubleshooting

- If token validation fails, copy the token again from the ListenBrainz profile
  page and make sure there are no spaces before or after it.
- If listens do not appear, confirm Submit completed listens is enabled.
- If now-playing updates do not appear, confirm Send now playing is enabled.
- If a delete action is unavailable, refresh recent listens. The listen must
  include a timestamp and `recording_msid` before ListenBrainz can delete it.
- If iOS Music library scans do not submit anything on the first run, that is
  expected: the first scan is a baseline.

Report bugs at <https://github.com/kubrick06010/ListenScrobbler/issues>.

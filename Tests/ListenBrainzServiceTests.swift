import XCTest
@testable import OpenScrobbler

final class ListenBrainzServiceTests: XCTestCase {
    override func tearDown() {
        ListenBrainzURLProtocol.handler = nil
        ListenBrainzURLProtocol.requests = []
        super.tearDown()
    }

    func testValidateStoresResolvedUsername() async throws {
        let defaults = makeDefaults()
        let tokenStore = TestListenBrainzTokenStore(token: "secret-token")
        let service = makeService(defaults: defaults, tokenStore: tokenStore) { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token secret-token")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"valid":true,"user_name":"open-user","message":"ok"}"#.utf8)
            return (response, data)
        }

        let result = try await service.validate()

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.username, "open-user")
        XCTAssertEqual(service.settings.username, "open-user")
    }

    func testValidateWithoutTokenThrowsMissingToken() async {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: nil)) { _ in
            XCTFail("Network should not be called without a token")
            throw URLError(.badURL)
        }

        await XCTAssertThrowsErrorAsync(try await service.validate()) { error in
            XCTAssertEqual(error as? ListenBrainzError, .missingToken)
        }
    }

    func testFileTokenStorePersistsWithoutKeychain() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenScrobblerTokenStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = ListenBrainzTokenStore(fileManager: .default, appSupportRoot: tempRoot)
        try store.saveToken("file-token")

        XCTAssertEqual(try store.readToken(), "file-token")
        let tokenURL = tempRoot
            .appendingPathComponent("OpenScrobbler", isDirectory: true)
            .appendingPathComponent("Secrets", isDirectory: true)
            .appendingPathComponent("listenbrainz-token")
        let attributes = try FileManager.default.attributesOfItem(atPath: tokenURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, NSNumber(value: Int16(0o600)))

        try store.deleteToken()
        XCTAssertNil(try store.readToken())
    }

    func testSubmitListenUsesOpenScrobblerClientMetadata() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/submit-listens")
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["listen_type"] as? String, "single")
            let payload = try XCTUnwrap((json["payload"] as? [[String: Any]])?.first)
            XCTAssertNotNil(payload["listened_at"] as? Int)
            let metadata = try XCTUnwrap(payload["track_metadata"] as? [String: Any])
            let additional = try XCTUnwrap(metadata["additional_info"] as? [String: Any])
            XCTAssertEqual(metadata["artist_name"] as? String, "Artist")
            XCTAssertEqual(metadata["track_name"] as? String, "Track")
            XCTAssertEqual(metadata["release_name"] as? String, "Album")
            XCTAssertEqual(additional["media_player"] as? String, "Test Player")
            XCTAssertEqual(additional["submission_client"] as? String, "OpenScrobbler")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await service.submitListen(
            Track(
                title: "Track",
                artist: "Artist",
                album: "Album",
                duration: 180,
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                sourceApp: "Test Player"
            )
        )

        XCTAssertEqual(ListenBrainzURLProtocol.requests.count, 1)
    }

    func testNowPlayingRequestsRecordingMSIDForFeedback() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/1/submit-listens")
            XCTAssertTrue(request.url?.query?.contains("return_msid=true") == true)
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["listen_type"] as? String, "playing_now")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","recording_msid":"msid-1"}"#.utf8))
        }

        let recordingMSID = try await service.nowPlaying(
            Track(
                title: "Track",
                artist: "Artist",
                album: "Album",
                duration: 180,
                startedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )

        XCTAssertEqual(recordingMSID, "msid-1")
    }

    func testLoveAndUnloveRecordingSubmitFeedbackScores() async throws {
        var scores: [Int] = []
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/1/feedback/recording-feedback")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token token")
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["recording_msid"] as? String, "msid-1")
            scores.append(try XCTUnwrap(json["score"] as? Int))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok"}"#.utf8))
        }

        try await service.loveRecording(recordingMsid: "msid-1")
        try await service.unloveRecording(recordingMsid: "msid-1")

        XCTAssertEqual(scores, [1, 0])
    }

    func testFetchStatsSnapshotDecodesSparseMetadata() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let path = request.url!.path
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch path {
            case "/1/user/tester/listen-count":
                return (response, Data(#"{"payload":{"count":321}}"#.utf8))
            case "/1/user/tester/listens":
                return (response, Data(#"{"payload":{"listens":[{"listened_at":1700000100,"track_metadata":{"artist_name":"Artist","track_name":"Track","release_name":"Album","additional_info":{"recording_mbid":"rec-1","artist_mbids":["art-1"],"release_mbid":"rel-1"}}}]}}"#.utf8))
            case "/1/stats/user/tester/listening-activity":
                return (response, Data(#"{"payload":{"listening_activity":[{"from_ts":1700000000,"listen_count":11,"time_range":"Monday","to_ts":1700086399}]}}"#.utf8))
            case "/1/stats/user/tester/artists":
                return (response, Data(#"{"payload":{"artists":[{"artist_name":"Artist","artist_mbid":"","listen_count":12}]}}"#.utf8))
            case "/1/stats/user/tester/releases":
                return (response, Data(#"{"payload":{"releases":[{"artist_name":"Artist","release_name":"Album","release_mbid":"","listen_count":9}]}}"#.utf8))
            case "/1/stats/user/tester/recordings":
                return (response, Data(#"{"payload":{"recordings":[{"artist_name":"Artist","track_name":"Track","release_name":"","recording_mbid":"","listen_count":7}]}}"#.utf8))
            default:
                XCTFail("Unexpected path \(path)")
                return (response, Data())
            }
        }

        let snapshot = try await service.fetchStatsSnapshot(username: "tester", range: .month, count: 5)

        XCTAssertEqual(snapshot.username, "tester")
        XCTAssertEqual(snapshot.range, .month)
        XCTAssertEqual(snapshot.totalListenCount, 321)
        XCTAssertEqual(snapshot.topArtists.first?.name, "Artist")
        XCTAssertNil(snapshot.topArtists.first?.mbid)
        XCTAssertEqual(snapshot.topReleases.first?.name, "Album")
        XCTAssertNil(snapshot.topReleases.first?.mbid)
        XCTAssertEqual(snapshot.topRecordings.first?.trackName, "Track")
        XCTAssertNil(snapshot.topRecordings.first?.releaseName)
        XCTAssertEqual(snapshot.recentListens.first?.artistName, "Artist")
        XCTAssertEqual(snapshot.recentListens.first?.recordingMBID, "rec-1")
        XCTAssertEqual(snapshot.recentListens.first?.artistMBID, "art-1")
        XCTAssertEqual(snapshot.recentListens.first?.releaseMBID, "rel-1")
        XCTAssertEqual(snapshot.listeningActivity.first?.listenCount, 11)
    }

    func testFetchSocialListenActivityLoadsNeighborsRecentListens() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/1/user/alice/listens":
                return (response, Data(#"{"payload":{"listens":[{"listened_at":1700000100,"track_metadata":{"artist_name":"Alice Artist","track_name":"Alice Track"}}]}}"#.utf8))
            case "/1/user/bob/listens":
                return (response, Data(#"{"payload":{"listens":[{"listened_at":1700000200,"track_metadata":{"artist_name":"Bob Artist","track_name":"Bob Track","release_name":"Bob Album"}}]}}"#.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let activity = try await service.fetchSocialListenActivity(usernames: ["alice", "bob", "alice"], countPerUser: 1)

        XCTAssertEqual(activity.map(\.userName), ["bob", "alice"])
        XCTAssertEqual(activity.first?.listen.trackName, "Bob Track")
    }

    func testFetchSocialListsLoadsFollowersAndFollowing() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/1/user/tester/followers":
                return (response, Data(#"{"followers":["alice"," bob "],"user":"tester"}"#.utf8))
            case "/1/user/tester/following":
                return (response, Data(#"{"following":["carol","dave"],"user":"tester"}"#.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let followers = try await service.fetchFollowers(username: "tester")
        let following = try await service.fetchFollowing(username: "tester")

        XCTAssertEqual(followers, ["alice", "bob"])
        XCTAssertEqual(following, ["carol", "dave"])
    }

    func testFetchArtistMapDecodesCountryCounts() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.url?.path, "/1/stats/user/tester/artist-map")
            XCTAssertTrue(request.url?.query?.contains("range=year") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, try self.fixtureData(named: "artist-map-openapi"))
        }

        let map = try await service.fetchArtistMap(username: "tester", range: .year)

        XCTAssertEqual(map.map(\.countryCode), ["USA", "GBR"])
        XCTAssertEqual(map.first?.artistCount, 20)
    }

    func testFetchSimilarArtistsAggregatesRadioPayload() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.url?.path, "/1/lb-radio/artist/seed-mbid")
            XCTAssertTrue(request.url?.query?.contains("mode=easy") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"seed-mbid":[{"recording_mbid":"rec-1","similar_artist_mbid":"seed-mbid","similar_artist_name":"Seed Artist","total_listen_count":44}],"artist-2":[{"recording_mbid":"rec-2","similar_artist_mbid":"artist-2","similar_artist_name":"Boards of Canada","total_listen_count":1200},{"recording_mbid":"rec-3","similar_artist_mbid":"artist-2","similar_artist_name":"Boards of Canada","total_listen_count":800}],"artist-3":[{"recording_mbid":"rec-4","similar_artist_mbid":"artist-3","similar_artist_name":"Moby","total_listen_count":300}]}"#
            return (response, Data(payload.utf8))
        }

        let artists = try await service.fetchSimilarArtists(seedArtistMBID: "seed-mbid", maxSimilarArtists: 4)

        XCTAssertEqual(artists.count, 3)
        XCTAssertEqual(artists.first?.artistMbid, "artist-2")
        XCTAssertEqual(artists.first?.totalListenCount, 1200)
        XCTAssertEqual(artists.last?.isSeedArtist, true)
    }

    func testFetchRecommendedRecordingsEnrichesMetadata() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod ?? "GET", request.url!.path) {
            case ("GET", "/1/cf/recommendation/user/tester/recording"):
                return (response, Data(#"{"payload":{"mbids":[{"recording_mbid":"mbid-1","score":9.3},{"recording_mbid":"mbid-2","score":7.1}]}}"#.utf8))
            case ("POST", "/1/metadata/recording"):
                let body = try XCTUnwrap(request.httpBodyData)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(json["inc"] as? String, "artist release")
                let mbids = try XCTUnwrap(json["recording_mbids"] as? [String])
                XCTAssertEqual(Set(mbids), Set(["mbid-1", "mbid-2"]))
                return (response, Data(#"{"mbid-1":{"recording_name":"Track One","artist_credit_name":"Artist One","release_name":"Album One"},"mbid-2":{"recording":{"name":"Track Two"},"artist":{"name":"Artist Two","artists":[{"name":"Ignored Artist"}]},"release":{"name":"Album Two"}}}"#.utf8))
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "GET") \(request.url!.path)")
                return (response, Data())
            }
        }

        let recommendations = try await service.fetchRecommendedRecordings(username: "tester", count: 2)

        XCTAssertEqual(recommendations.count, 2)
        XCTAssertEqual(recommendations.first?.recordingMbid, "mbid-1")
        XCTAssertEqual(recommendations.first?.title, "Track One")
        XCTAssertEqual(recommendations.first?.artistName, "Artist One")
        XCTAssertEqual(recommendations.first?.releaseName, "Album One")
        XCTAssertEqual(recommendations.last?.title, "Track Two")
        XCTAssertEqual(recommendations.last?.artistName, "Artist Two")
        XCTAssertEqual(recommendations.last?.releaseName, "Album Two")
    }

    func testFetchPopularityAndTopRecordingsForArtist() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod ?? "GET", request.url!.path) {
            case ("POST", "/1/popularity/recording"):
                return (response, Data(#"[{"recording_mbid":"rec-1","total_listen_count":42,"total_user_count":7}]"#.utf8))
            case ("POST", "/1/popularity/artist"):
                return (response, Data(#"[{"artist_mbid":"artist-1","total_listen_count":1200,"total_user_count":80}]"#.utf8))
            case ("POST", "/1/popularity/release"):
                return (response, Data(#"[{"release_mbid":"release-1","total_listen_count":90,"total_user_count":12}]"#.utf8))
            case ("GET", "/1/popularity/top-recordings-for-artist/artist-1"):
                XCTAssertEqual(request.url?.query, "count=2")
                return (response, Data(#"[{"artist_name":"Artist","caa_release_mbid":"cover-release","recording_mbid":"rec-1","recording_name":"Track","release_mbid":"release-1","release_name":"Album","total_listen_count":42,"total_user_count":7}]"#.utf8))
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "GET") \(request.url!.path)")
                return (response, Data())
            }
        }

        let recording = try await service.fetchRecordingPopularity(recordingMBIDs: ["rec-1"]).first
        let artist = try await service.fetchArtistPopularity(artistMBIDs: ["artist-1"]).first
        let release = try await service.fetchReleasePopularity(releaseMBIDs: ["release-1"]).first
        let top = try await service.fetchPopularRecordingsForArtist(artistMBID: "artist-1", count: 2)

        XCTAssertEqual(recording?.totalListenCount, 42)
        XCTAssertEqual(artist?.totalUserCount, 80)
        XCTAssertEqual(release?.totalListenCount, 90)
        XCTAssertEqual(top.first?.title, "Track")
        XCTAssertEqual(top.first?.imageURL, "https://coverartarchive.org/release/cover-release/front-250")
    }

    func testFetchArtistProfileDecodesListenBrainzMetadata() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.url?.path, "/1/metadata/artist")
            XCTAssertTrue(request.url?.query?.contains("artist_mbids=artist-1") == true)
            XCTAssertTrue(request.url?.query?.contains("inc=artist%20tag%20release") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = """
            [
              {
                "area": "United Kingdom",
                "artist_mbid": "artist-1",
                "begin_year": 1967,
                "mbid": "artist-1",
                "name": "Jethro Tull",
                "rels": {
                  "official homepage": "https://jethrotull.com/",
                  "youtube": "https://www.youtube.com/channel/example",
                  "wikidata": "https://www.wikidata.org/wiki/Q192353"
                },
                "tag": {
                  "artist": [
                    { "artist_mbid": "artist-1", "count": 15, "genre_mbid": "genre-1", "tag": "progressive rock" },
                    { "artist_mbid": "artist-1", "count": 5, "tag": "rock" }
                  ]
                },
                "type": "Group"
              }
            ]
            """
            return (response, Data(payload.utf8))
        }

        let profile = try await service.fetchArtistProfile(artistMBID: "artist-1")

        XCTAssertEqual(profile?.name, "Jethro Tull")
        XCTAssertEqual(profile?.area, "United Kingdom")
        XCTAssertEqual(profile?.beginYear, 1967)
        XCTAssertEqual(profile?.type, "Group")
        XCTAssertEqual(profile?.tags.map(\.name), ["progressive rock", "rock"])
        XCTAssertEqual(profile?.tags.first?.count, 15)
        XCTAssertTrue(profile?.links.contains { $0.title == "Official Homepage" } == true)
    }

    func testRecommendRecordingPostsRecipientsAndBlurb() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/user/tester/timeline-event/create/recommend-personal")
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
            XCTAssertEqual(metadata["recording_mbid"] as? String, "mbid-1")
            XCTAssertEqual(metadata["blurb_content"] as? String, "For your late-night queue")
            XCTAssertEqual(metadata["users"] as? [String], ["alice", "bob"])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await service.recommendRecording(
            recordingMbid: "mbid-1",
            to: ["alice", "bob"],
            blurb: "For your late-night queue",
            from: "tester"
        )
    }

    func testFetchCurrentPinDecodesTrackMetadata() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/tester/pins/current")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"pinned_recording":{"row_id":42,"recording_mbid":"mbid-42","blurb_content":"Still perfect","created":1700000200,"pinned_until":1700003800,"track_metadata":{"artist_name":"Artist","track_name":"Pinned Track"},"user_name":"tester"}}"#
            return (response, Data(payload.utf8))
        }

        let pin = try await service.fetchCurrentPin(username: "tester")

        XCTAssertEqual(pin?.id, 42)
        XCTAssertEqual(pin?.recordingMbid, "mbid-42")
        XCTAssertEqual(pin?.trackName, "Pinned Track")
        XCTAssertEqual(pin?.artistName, "Artist")
        XCTAssertEqual(pin?.blurb, "Still perfect")
    }

    func testPinningByMusicBrainzIDPostsRecordingMBIDToListenBrainz() async throws {
        // Given a track resolved to a stable MusicBrainz recording ID.
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/pin")
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["recording_mbid"] as? String, "mbid-9", "ListenBrainz expects recording_mbid when MusicBrainz resolution succeeded.")
            XCTAssertEqual(json["blurb_content"] as? String, "Pinned from OpenScrobbler", "The app should include the user's pin note/blurb.")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // When OpenScrobbler pins it.
        try await service.pinRecording(recordingMbid: "mbid-9", blurb: "Pinned from OpenScrobbler")
    }

    func testPinningByListenBrainzMSIDPostsRecordingMSIDWithoutMBID() async throws {
        // Given MusicBrainz could not resolve the track, but ListenBrainz has a recording MSID from recent listens.
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/pin")
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["recording_msid"] as? String, "msid-9", "ListenBrainz accepts recording_msid as the fallback pin identity.")
            XCTAssertNil(json["recording_mbid"], "The fallback request must not invent a MusicBrainz ID.")
            XCTAssertEqual(json["blurb_content"] as? String, "Pinned from OpenScrobbler", "The app should include the user's pin note/blurb.")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // When OpenScrobbler pins it.
        try await service.pinRecording(recordingMsid: "msid-9", blurb: "Pinned from OpenScrobbler")
    }

    func testReplacingCurrentPinPostsToListenBrainzUnpinEndpoint() async throws {
        // Given the app needs to clear the one active ListenBrainz pin before posting a replacement.
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/pin/unpin")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // When OpenScrobbler asks ListenBrainz to unpin the current recording.
        try await service.unpinCurrentRecording()
    }

    func testDeletingAPinHistoryEntryPostsItsRowIDToListenBrainz() async throws {
        // Given the user deletes a specific historical pin row from the app.
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/pin/delete/42", "ListenBrainz deletes historical pins by row ID, not by recording title.")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // When OpenScrobbler deletes that row.
        try await service.deletePin(rowID: 42)
    }

    func testFetchPlaylistsParsesSummariesAndRecommendationLists() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"playlists":[{"title":"Late Night","identifier":"https://listenbrainz.org/playlist/pl-1","annotation":"Soft descent","creator":"tester","track":[{"identifier":"https://musicbrainz.org/recording/a"}],"extension":{"https://musicbrainz.org/doc/jspf#playlist":{"public":true}}},{"playlist":{"title":"Algorithm Gems","identifier":"https://listenbrainz.org/playlist/pl-2","creator":"ListenBrainz","annotation":"Recommendations"},"extension":{"track_count":8}}]}"#
            return (response, Data(payload.utf8))
        }

        let playlists = try await service.fetchPlaylists(username: "tester", count: 2)
        let recommended = try await service.fetchRecommendationPlaylists(username: "tester", count: 2)

        XCTAssertEqual(playlists.count, 2)
        XCTAssertEqual(playlists.first?.id, "pl-1")
        XCTAssertEqual(playlists.first?.trackCount, 1)
        XCTAssertEqual(playlists.first?.isPublic, true)
        XCTAssertEqual(playlists.last?.title, "Algorithm Gems")
        XCTAssertEqual(recommended.last?.trackCount, 8)
    }

    func testFetchSimilarUsersLoadsOpenAPIFixture() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.url?.path, "/1/user/tester/similar-users")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, try self.fixtureData(named: "similar-users-openapi"))
        }

        let users = try await service.fetchSimilarUsers(username: "tester", count: 2)

        XCTAssertEqual(users.map(\.userName), ["alice", "bob"])
        XCTAssertEqual(users.first?.similarityScore, 0.82)
    }

    func testFetchCompatibilityBuildsSharedArtistsFromOpenAPIAndTopArtists() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/1/user/tester/similar-to/alice":
                return (response, try self.fixtureData(named: "similarity-openapi"))
            case "/1/stats/user/tester/artists":
                return (response, Data(#"{"payload":{"artists":[{"artist_name":"Broadcast","artist_mbid":"artist-a","listen_count":42},{"artist_name":"Biosphere","artist_mbid":"artist-b","listen_count":20}]}}"#.utf8))
            case "/1/stats/user/alice/artists":
                return (response, Data(#"{"payload":{"artists":[{"artist_name":"Broadcast","artist_mbid":"artist-a","listen_count":17},{"artist_name":"Coil","artist_mbid":"artist-c","listen_count":9}]}}"#.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let compatibility = try await service.fetchCompatibility(sourceUsername: "tester", targetUsername: "alice")

        XCTAssertEqual(compatibility.targetUserName, "alice")
        XCTAssertEqual(compatibility.similarityScore, 0.61)
        XCTAssertEqual(compatibility.sharedArtists.count, 1)
        XCTAssertEqual(compatibility.sharedArtists.first?.name, "Broadcast")
        XCTAssertEqual(compatibility.sharedArtists.first?.yourListenCount, 42)
        XCTAssertEqual(compatibility.sharedArtists.first?.otherListenCount, 17)
    }

    func testRateLimitRetriesAndEventuallySucceeds() async throws {
        var attempts = 0
        let service = makeService(
            tokenStore: TestListenBrainzTokenStore(token: "token"),
            sleep: { _ in }
        ) { request in
            attempts += 1
            if attempts == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "0"]
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, try self.fixtureData(named: "similar-users-openapi"))
        }

        let users = try await service.fetchSimilarUsers(username: "tester", count: 2)

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(users.count, 2)
    }

    func testCreatePlaylistPostsJSPFWithRecordingIdentifiers() async throws {
        let service = makeService(tokenStore: TestListenBrainzTokenStore(token: "token")) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.listenbrainz.org/1/playlist/create")
            let body = try XCTUnwrap(request.httpBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let playlist = try XCTUnwrap(json["playlist"] as? [String: Any])
            XCTAssertEqual(playlist["title"] as? String, "OpenScrobbler Picks")
            let tracks = try XCTUnwrap(playlist["track"] as? [[String: Any]])
            XCTAssertEqual(tracks.count, 2)
            XCTAssertEqual(tracks.first?["identifier"] as? String, "https://musicbrainz.org/recording/mbid-1")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await service.createPlaylist(title: "OpenScrobbler Picks", recordingMBIDs: ["mbid-1", "mbid-2"])
    }

    private func makeService(
        defaults: UserDefaults? = nil,
        tokenStore: TestListenBrainzTokenStore,
        sleep: @escaping @Sendable (UInt64) async -> Void = { _ in },
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> ListenBrainzService {
        ListenBrainzURLProtocol.handler = handler
        ListenBrainzURLProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ListenBrainzURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let settingsStore = ListenBrainzSettingsStore(
            defaults: defaults ?? makeDefaults(),
            tokenStore: tokenStore
        )
        settingsStore.save(
            ListenBrainzSettings(
                isEnabled: true,
                submitNowPlaying: true,
                submitListens: true,
                baseURL: URL(string: "https://api.listenbrainz.org")!,
                username: nil
            )
        )
        return ListenBrainzService(settingsStore: settingsStore, urlSession: session, sleep: sleep)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OpenScrobbler.ListenBrainzTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func fixtureData(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let directURL = bundle.url(forResource: name, withExtension: "json", subdirectory: "ListenBrainz")
            ?? bundle.url(forResource: name, withExtension: "json")
        let discoveredURL = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .first(where: { $0.lastPathComponent == "\(name).json" })
        guard let url = directURL ?? discoveredURL else {
            XCTFail("Missing fixture \(name).json")
            return Data()
        }
        return try Data(contentsOf: url)
    }
}

extension URLRequest {
    var httpBodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}

private final class TestListenBrainzTokenStore: ListenBrainzTokenStoring {
    private var storedToken: String?

    init(token: String? = nil) {
        storedToken = token
    }

    func readToken() throws -> String? {
        storedToken
    }

    func saveToken(_ token: String) throws {
        storedToken = token
    }

    func deleteToken() throws {
        storedToken = nil
    }
}

private final class ListenBrainzURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            Self.requests.append(request)
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verify: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown")
    } catch {
        verify(error)
    }
}

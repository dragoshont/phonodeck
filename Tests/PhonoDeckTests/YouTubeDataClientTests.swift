import XCTest
@testable import PhonoDeck

private final class YouTubeDataClientURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    do {
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

final class YouTubeDataClientTests: XCTestCase {
    func testChannelsResponseDecodesFirstChannelTitle() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "id": "channel-id",
                  "snippet": {
                    "title": "Dragos Music"
                  }
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubeChannelsResponse.self, from: json)

        XCTAssertEqual(response.items.first?.id, "channel-id")
        XCTAssertEqual(response.items.first?.snippet.title, "Dragos Music")
    }

    func testSearchResponseDecodesPlayableVideoResult() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "id": {
                    "kind": "youtube#video",
                    "videoId": "video-id"
                  },
                  "snippet": {
                    "title": "Song &amp; Video",
                    "channelTitle": "Artist &amp; Channel",
                    "thumbnails": {
                      "default": { "url": "https://i.ytimg.com/vi/video-id/default.jpg" },
                      "medium": { "url": "https://i.ytimg.com/vi/video-id/mqdefault.jpg" }
                    }
                  }
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubeSearchResponse.self, from: json)
        let result = try XCTUnwrap(response.items.compactMap(YouTubeVideoSearchResult.init(item:)).first)

        XCTAssertEqual(result.id, "video-id")
        XCTAssertEqual(result.title, "Song & Video")
        XCTAssertEqual(result.channelTitle, "Artist & Channel")
        XCTAssertEqual(result.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/video-id/mqdefault.jpg")
        XCTAssertEqual(result.embedURL.host, "www.youtube.com")
        XCTAssertTrue(result.embedURL.absoluteString.contains("origin=http://127.0.0.1"))
        XCTAssertTrue(result.embedURL.absoluteString.contains("/embed/video-id"))
    }

    func testPlaylistItemDecodesPlayableVideoResult() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "id": "playlist-item-id",
                  "snippet": {
                    "title": "Playlist Song",
                    "channelTitle": "Artist - Topic",
                    "publishedAt": "2026-06-01T12:00:00Z",
                    "thumbnails": {
                      "default": { "url": "https://i.ytimg.com/vi/playlist-video/default.jpg" }
                    }
                  },
                  "contentDetails": {
                    "videoId": "playlist-video"
                  }
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubePlaylistItemsResponse.self, from: json)
        let result = try XCTUnwrap(response.items.compactMap(YouTubeVideoSearchResult.init(playlistItem:)).first)

        XCTAssertEqual(result.id, "playlist-video")
        XCTAssertEqual(result.title, "Playlist Song")
        XCTAssertEqual(result.channelTitle, "Artist - Topic")
        XCTAssertEqual(result.playlistItemID, "playlist-item-id")
        XCTAssertEqual(result.playlistAddedAt, "2026-06-01T12:00:00Z")
    }

    func testPlaylistItemsSkipMalformedRowsAndKeepPlayableVideos() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "id": "deleted-item-id",
                  "snippet": {
                    "title": "Deleted video",
                    "publishedAt": "2026-06-01T12:00:00Z"
                  }
                },
                {
                  "id": "playlist-item-id",
                  "snippet": {
                    "title": "Playable Song",
                    "channelTitle": "Artist - Topic",
                    "publishedAt": "2026-06-01T12:00:00Z",
                    "thumbnails": {
                      "default": { "url": "https://i.ytimg.com/vi/playable-video/default.jpg" }
                    }
                  },
                  "contentDetails": {
                    "videoId": "playable-video"
                  }
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubePlaylistItemsResponse.self, from: json)
        let results = response.items.compactMap(YouTubeVideoSearchResult.init(playlistItem:))

        XCTAssertEqual(results.map(\.id), ["playable-video"])
        XCTAssertEqual(results.first?.title, "Playable Song")
    }

    func testPlaylistItemsKeepSparseRowsWithVideoID() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "id": "sparse-item-id",
                  "snippet": {
                    "resourceId": {
                      "kind": "youtube#video",
                      "videoId": "sparse-video"
                    }
                  }
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubePlaylistItemsResponse.self, from: json)
        let result = try XCTUnwrap(response.items.compactMap(YouTubeVideoSearchResult.init(playlistItem:)).first)

        XCTAssertEqual(result.id, "sparse-video")
        XCTAssertEqual(result.title, "Unavailable playlist item")
        XCTAssertEqual(result.channelTitle, "Unknown channel")
        XCTAssertNil(result.thumbnailURL)
    }

    func testPlaylistItemPageKeepsRowsWhenVideoEnrichmentFails() async throws {
        YouTubeDataClientURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/playlistItems") {
                let data = Data(
                    """
                    {
                      "items": [
                        {
                          "id": "playlist-item-id",
                          "snippet": {
                            "title": "Playable Song",
                            "channelTitle": "Artist - Topic",
                            "publishedAt": "2026-06-01T12:00:00Z",
                            "thumbnails": {
                              "default": { "url": "https://i.ytimg.com/vi/playable-video/default.jpg" }
                            }
                          },
                          "contentDetails": {
                            "videoId": "playable-video"
                          }
                        }
                      ]
                    }
                    """.utf8
                )
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            }
            let data = Data("not-json".utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { YouTubeDataClientURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [YouTubeDataClientURLProtocol.self]
        let client = YouTubeDataClient(urlSession: URLSession(configuration: configuration))

        let page = try await client.playlistItemPage(playlistID: "playlist-id", accessToken: "token")

        XCTAssertEqual(page.items.map(\.id), ["playable-video"])
        XCTAssertEqual(page.items.first?.durationText, nil)
        XCTAssertEqual(page.items.first?.popularityText, nil)
    }

    func testActivityDecodesPlayableVideoResult() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "snippet": {
                    "title": "Recent Song",
                    "channelTitle": "Recent Artist",
                    "thumbnails": {
                      "default": { "url": "https://i.ytimg.com/vi/recent-video/default.jpg" }
                    }
                  },
                  "contentDetails": {
                    "upload": {
                      "videoId": "recent-video"
                    }
                  }
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubeActivitiesResponse.self, from: json)
        let result = try XCTUnwrap(response.items.compactMap(YouTubeVideoSearchResult.init(activity:)).first)

        XCTAssertEqual(result.id, "recent-video")
        XCTAssertEqual(result.title, "Recent Song")
        XCTAssertEqual(result.channelTitle, "Recent Artist")
    }

      func testSongPlaybackPriorityPrefersOfficialAudioOverClipsAndCovers() {
        let results = [
          YouTubeVideoSearchResult(id: "music-video", title: "Song Title (Official Music Video)", channelTitle: "Artist", thumbnailURL: nil),
          YouTubeVideoSearchResult(id: "cover", title: "Song Title Guitar Cover", channelTitle: "Cover Channel", thumbnailURL: nil),
          YouTubeVideoSearchResult(id: "topic", title: "Song Title", channelTitle: "Artist - Topic", thumbnailURL: nil),
          YouTubeVideoSearchResult(id: "audio", title: "Song Title (Official Audio)", channelTitle: "Artist", thumbnailURL: nil)
        ]

        let sorted = results.sortedBySongPlaybackPriority()

        XCTAssertEqual(sorted.map(\.id), ["audio", "topic", "music-video", "cover"])
      }

      func testVideoFirstPreferencePrefersOfficialClip() {
        let results = [
          YouTubeVideoSearchResult(id: "clip", title: "Song Title (Official Music Video)", channelTitle: "Artist", thumbnailURL: nil),
          YouTubeVideoSearchResult(id: "audio", title: "Song Title (Official Audio)", channelTitle: "Artist", thumbnailURL: nil),
          YouTubeVideoSearchResult(id: "topic", title: "Song Title", channelTitle: "Artist - Topic", thumbnailURL: nil)
        ]

        XCTAssertEqual(results.sortedByPlaybackPriority(.videoFirst).first?.id, "clip")
      }

    func testSongClassifierSeparatesSongsFromClips() {
        let audio = YouTubeVideoSearchResult(id: "audio", title: "Song Title (Official Audio)", channelTitle: "Artist", thumbnailURL: nil)
        let topic = YouTubeVideoSearchResult(id: "topic", title: "Song Title", channelTitle: "Artist - Topic", thumbnailURL: nil)
        let lyrics = YouTubeVideoSearchResult(id: "lyrics", title: "Song Title Lyrics", channelTitle: "Artist", thumbnailURL: nil)
        let clip = YouTubeVideoSearchResult(id: "clip", title: "Song Title (Official Music Video)", channelTitle: "Artist", thumbnailURL: nil)

        XCTAssertTrue(audio.isSongLike)
        XCTAssertTrue(topic.isSongLike)
        XCTAssertTrue(lyrics.isSongLike)
        XCTAssertFalse(clip.isSongLike)
        XCTAssertEqual(clip.resultKind, .clip)
    }

    func testCreatedPlaylistDecodesWithoutContentDetails() throws {
        let json = Data(
            """
            {
              "id": "playlist-id",
              "snippet": {
                "title": "PhonoDeck Songs"
              },
              "status": {
                "privacyStatus": "private"
              }
            }
            """.utf8
        )

        let playlist = try JSONDecoder().decode(YouTubePlaylist.self, from: json)

        XCTAssertEqual(playlist.id, "playlist-id")
        XCTAssertEqual(playlist.snippet.title, "PhonoDeck Songs")
        XCTAssertNil(playlist.contentDetails)
        XCTAssertEqual(playlist.shareURL.absoluteString, "https://www.youtube.com/playlist?list=playlist-id")
    }

    func testVideoDetailsExposeMusicFacingFacts() throws {
        let json = Data(
            """
            {
              "items": [
                {
                  "id": "song-id",
                  "snippet": {
                    "title": "Song Title",
                    "channelTitle": "Artist",
                    "publishedAt": "2020-02-01T10:00:00Z"
                  },
                  "contentDetails": {
                    "duration": "PT3M21S",
                    "caption": "true",
                    "definition": "hd",
                    "licensedContent": true
                  },
                  "recordingDetails": {
                    "recordingDate": "1995-10-02"
                  },
                  "statistics": {
                    "viewCount": "1234",
                    "likeCount": "56"
                  }
                }
              ]
            }
            """.utf8
        )

        let details = try XCTUnwrap(JSONDecoder().decode(YouTubeVideosResponse.self, from: json).items.first)

        XCTAssertEqual(details.formattedDuration, "3:21")
        XCTAssertEqual(details.releaseYear, "1995")
        XCTAssertTrue(details.qualitySummary.contains("HD video"))
        XCTAssertTrue(details.qualitySummary.contains("not exposed"))
        XCTAssertTrue(details.labelSummary.contains("Licensed content"))
        XCTAssertTrue(details.labelSummary.contains("not exposed"))
    }

    func testOfficialOnlyMetadataProviderIsPolicyDisabled() async {
        let provider = OfficialOnlyYouTubeMusicMetadataProvider()

        do {
            _ = try await provider.search(query: "Wonderwall", preference: .songFirst, maxResults: 12)
            XCTFail("Undocumented metadata provider should be disabled.")
        } catch let error as YouTubeMusicProviderError {
            XCTAssertEqual(error, .undocumentedMetadataDisabled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequestFailedErrorIncludesStatusCode() {
        let error = YouTubeDataError.requestFailed(401, "Unauthorized")

        XCTAssertEqual(error.errorDescription, "YouTube request failed (HTTP 401): Unauthorized")
    }

      func testQuotaExceededErrorMessageIsSpecific() {
        XCTAssertEqual(YouTubeDataError.quotaExceeded.errorDescription, "YouTube API daily quota is exhausted. Try again later.")
      }
}
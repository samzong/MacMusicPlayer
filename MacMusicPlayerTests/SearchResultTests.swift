import XCTest
@testable import MacMusicPlayer

final class SearchResultTests: XCTestCase {
    func testDecodesSearchResponse() throws {
        let json = """
        {
            "items": [
                {
                    "videoId": "abc123",
                    "videoUrl": "https://example.com/watch?v=abc123",
                    "title": "Some Song",
                    "thumbnailUrl": "https://example.com/thumb.jpg",
                    "platform": "youtube"
                }
            ],
            "nextPageToken": "TOKEN",
            "totalResults": 42
        }
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(YTSearchManager.SearchResult.self, from: json)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].videoId, "abc123")
        XCTAssertEqual(result.items[0].platform, "youtube")
        XCTAssertEqual(result.nextPageToken, "TOKEN")
        XCTAssertEqual(result.totalResults, 42)
    }

    func testDecodesEmptyResponse() throws {
        let json = """
        {"items": [], "nextPageToken": null, "totalResults": 0}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(YTSearchManager.SearchResult.self, from: json)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNil(result.nextPageToken)
    }
}

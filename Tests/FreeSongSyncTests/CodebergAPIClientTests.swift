import XCTest
@testable import FreeSongSync

final class CodebergAPIClientTests: XCTestCase {

    private var mockHTTP: MockHTTPClient!
    private var client: CodebergAPIClient!

    override func setUp() async throws {
        mockHTTP = MockHTTPClient()
        let config = CodebergConfiguration(owner: "test", repo: "test-repo")
        client = CodebergAPIClient(configuration: config, httpClient: mockHTTP)

        // Store a test token
        try KeychainStorage.store(token: "test_token_abc123")
    }

    override func tearDown() {
        try? KeychainStorage.delete()
        mockHTTP = nil
        client = nil
    }

    // MARK: - listDirectory

    func testListDirectory_returnsFiles() async throws {
        let sha = "abc123"
        mockHTTP.when("/contents/songs", data: SyncFixtures.directoryListing(files: [("song.onsong", sha)]))

        let items = try await client.listDirectory(path: "songs")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "song.onsong")
        XCTAssertEqual(items.first?.sha, sha)
    }

    func testListDirectory_404returnsEmpty() async throws {
        mockHTTP.when("/contents/songs", data: Data(), statusCode: 404)

        let items = try await client.listDirectory(path: "songs")

        XCTAssertTrue(items.isEmpty)
    }

    func testListDirectory_401throws() async throws {
        mockHTTP.when("/contents/songs", data: SyncFixtures.errorResponse(message: "bad creds"), statusCode: 401)

        do {
            _ = try await client.listDirectory(path: "songs")
            XCTFail("Expected authenticationFailed error")
        } catch let error as SyncError {
            if case .authenticationFailed = error {
                // expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - getFileContent

    func testGetFileContent_returnsContent() async throws {
        let sha = "file_sha_456"
        let content = "Hello World"
        mockHTTP.when("/contents/songs/test.onsong", data: SyncFixtures.fileContent(sha: sha, content: content))

        let (data, returnedSHA) = try await client.getFileContent(path: "songs/test.onsong")

        XCTAssertEqual(returnedSHA, sha)
        XCTAssertEqual(String(data: data, encoding: .utf8), content)
    }

    func testGetFileContent_404throws() async throws {
        mockHTTP.when("/contents/songs/missing.onsong", data: Data(), statusCode: 404)

        do {
            _ = try await client.getFileContent(path: "songs/missing.onsong")
            XCTFail("Expected notFound error")
        } catch let error as SyncError {
            if case .notFound = error {
                // expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - createOrUpdateFile

    func testCreateOrUpdateFile_newFileSucceeds() async throws {
        let sha = "new_sha_789"
        mockHTTP.when("/contents/songs/new.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: sha),
                       statusCode: 201)

        let response = try await client.createOrUpdateFile(
            path: "songs/new.onsong",
            content: Data("test".utf8),
            sha: nil
        )

        XCTAssertEqual(response.content?.sha, sha)
        XCTAssertEqual(response.commit.sha, "commit123")
    }

    func testCreateOrUpdateFile_updateSucceeds() async throws {
        let sha = "updated_sha"
        mockHTTP.when("/contents/songs/existing.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: sha),
                       statusCode: 200)

        let response = try await client.createOrUpdateFile(
            path: "songs/existing.onsong",
            content: Data("updated".utf8),
            sha: "old_sha"
        )

        XCTAssertEqual(response.content?.sha, sha)
    }

    func testCreateOrUpdateFile_conflictThrows() async throws {
        mockHTTP.when("/contents/songs/stale.onsong",
                       data: SyncFixtures.errorResponse(message: "conflict"),
                       statusCode: 409)

        do {
            _ = try await client.createOrUpdateFile(
                path: "songs/stale.onsong",
                content: Data("data".utf8),
                sha: "stale_sha"
            )
            XCTFail("Expected conflict error")
        } catch let error as SyncError {
            if case .conflict = error {
                // expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - validateAccess

    func testValidateAccess_withValidToken_returnsTrue() async throws {
        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)

        let valid = try await client.validateAccess()

        XCTAssertTrue(valid)
    }

    func testValidateAccess_withInvalidToken_returnsFalse() async throws {
        mockHTTP.when("/user", data: SyncFixtures.errorResponse(message: "Unauthorized"), statusCode: 401)

        let valid = try await client.validateAccess()

        XCTAssertFalse(valid)
    }

    // MARK: - Auth header

    func testRequest_includesTokenHeader() async throws {
        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)

        _ = try await client.validateAccess()

        XCTAssertEqual(mockHTTP.requests.count, 1)
        let authHeader = mockHTTP.requests.first?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "token test_token_abc123")
    }

    func testRequest_withoutToken_throwsNotAuthenticated() async throws {
        try KeychainStorage.delete()
        mockHTTP.when("/user", data: Data(), statusCode: 200)

        do {
            _ = try await client.validateAccess()
            XCTFail("Expected notAuthenticated error")
        } catch let error as SyncError {
            if case .notAuthenticated = error {
                // expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

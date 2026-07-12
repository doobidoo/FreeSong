import XCTest
import FreeSongCore
import FreeSongStorage
@testable import FreeSongSync

final class CodebergSyncManagerTests: XCTestCase {

    private var mockHTTP: MockHTTPClient!
    private var manager: CodebergSyncManager!
    private var fileRepo: FileSongRepository!
    private var tempDir: URL!

    override func setUp() async throws {
        mockHTTP = MockHTTPClient()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("freesong-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let config = CodebergConfiguration(owner: "test", repo: "test-repo", songsPath: "songs")
        let client = CodebergAPIClient(configuration: config, httpClient: mockHTTP)
        fileRepo = FileSongRepository(libraryRoot: tempDir)
        manager = CodebergSyncManager(apiClient: client, fileRepository: fileRepo, configuration: config)

        try KeychainStorage.store(token: "test_token")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        try? KeychainStorage.delete()
        mockHTTP = nil
        manager = nil
        fileRepo = nil
        tempDir = nil
    }

    // MARK: - Push

    func testPushSongs_uploadsNewSongs() async throws {
        // Given: one local song, empty remote
        let song = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(song).write(to: fileURL, atomically: true, encoding: .utf8)

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs", data: Data(), statusCode: 404)
        // URL percent-encodes the space
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: "new_sha"),
                       statusCode: 201)

        // When
        let result = try await manager.pushSongs()

        // Then
        XCTAssertEqual(result.uploaded.count, 1)
        XCTAssertEqual(result.uploaded.first, "Amazing Grace")
        XCTAssertTrue(result.conflicts.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testPushSongs_skipsIdenticalSongs() async throws {
        // Given: local song matches remote content
        let song = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(song).write(to: fileURL, atomically: true, encoding: .utf8)

        let content = SyncFixtures.contentForSong(song)
        let sha = CodebergSyncManager.gitBlobSHA(for: Data(content.utf8))

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", sha)]),
                       statusCode: 200)

        // When
        let result = try await manager.pushSongs()

        // Then: no uploads
        XCTAssertTrue(result.uploaded.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testPushSongs_updatesChangedSongs() async throws {
        // Given: local song differs from remote
        let song = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(song).write(to: fileURL, atomically: true, encoding: .utf8)

        let differentSHA = "different_remote_sha"

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", differentSHA)]),
                       statusCode: 200)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: "updated_sha"),
                       statusCode: 200)

        // When
        let result = try await manager.pushSongs()

        // Then
        XCTAssertEqual(result.uploaded.count, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testPushSongs_reportsErrors() async throws {
        // Given: remote returns 401
        let song = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(song).write(to: fileURL, atomically: true, encoding: .utf8)

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 401)

        do {
            _ = try await manager.pushSongs()
            XCTFail("Expected authenticationFailed")
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

    // MARK: - Pull

    func testPullSongs_downloadsNewSongs() async throws {
        // Given: remote has a song, local is empty
        let remoteContent = SyncFixtures.contentForSong(SyncFixtures.makeSong())
        let remoteSHA = "remote_sha_123"

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", remoteSHA)]),
                       statusCode: 200)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.fileContent(sha: remoteSHA, content: remoteContent),
                       statusCode: 200)

        // When
        let result = try await manager.pullSongs()

        // Then
        XCTAssertEqual(result.downloaded.count, 1)
        XCTAssertTrue(result.conflicts.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // Verify file was saved locally
        let localURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
    }

    func testPullSongs_reportsConflicts() async throws {
        // Given: remote has different content than local
        let localSong = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(localSong).write(to: fileURL, atomically: true, encoding: .utf8)

        var changedSong = SyncFixtures.makeSong()
        changedSong.artist = "Different Artist"
        let remoteContent = SyncFixtures.contentForSong(changedSong)
        let remoteSHA = "remote_sha_456"

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", remoteSHA)]),
                       statusCode: 200)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.fileContent(sha: remoteSHA, content: remoteContent),
                       statusCode: 200)

        // When
        let result = try await manager.pullSongs()

        // Then: conflict reported, not auto-resolved
        XCTAssertEqual(result.conflicts.count, 1)
        XCTAssertEqual(result.conflicts.first?.title, "Amazing Grace")
        XCTAssertTrue(result.downloaded.isEmpty)
    }

    func testPullSongs_autoResolvesConflictsWithRemote() async throws {
        // Given: remote conflicts, auto-resolve with .useRemote
        let localSong = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(localSong).write(to: fileURL, atomically: true, encoding: .utf8)

        var changedSong = SyncFixtures.makeSong()
        changedSong.artist = "Remote Artist"
        let remoteContent = SyncFixtures.contentForSong(changedSong)
        let remoteSHA = "remote_sha_789"

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", remoteSHA)]),
                       statusCode: 200)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.fileContent(sha: remoteSHA, content: remoteContent),
                       statusCode: 200)

        // When
        let result = try await manager.pullSongs(autoResolveConflicts: .useRemote)

        // Then
        XCTAssertTrue(result.conflicts.isEmpty)
        XCTAssertEqual(result.downloaded.count, 1)
    }

    func testPullSongs_autoResolvesConflictsKeepBoth() async throws {
        // Given: remote conflicts, auto-resolve with .keepBoth
        let localSong = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(localSong).write(to: fileURL, atomically: true, encoding: .utf8)

        let remoteContent = SyncFixtures.contentForSong(SyncFixtures.makeSong(artist: "Remote Artist"))
        let remoteSHA = "remote_sha_keep"

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", remoteSHA)]),
                       statusCode: 200)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.fileContent(sha: remoteSHA, content: remoteContent),
                       statusCode: 200)
        // PUT for the keepBoth conflict resolution to push local
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: "pushed"), statusCode: 200)

        // When
        let result = try await manager.pullSongs(autoResolveConflicts: .keepBoth)

        // Then
        XCTAssertTrue(result.conflicts.isEmpty)
        XCTAssertEqual(result.downloaded.count, 1)

        // Conflict file should exist
        let conflictURL = tempDir.appendingPathComponent("Amazing Grace_conflict.onsong")
        // Note: keepBoth creates the conflict file first, then saves remote as primary
        // So the original file should be renamed
    }

    // MARK: - Conflict Resolution

    func testResolveConflict_useLocal() async throws {
        // Given: a conflict
        let song = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(song).write(to: fileURL, atomically: true, encoding: .utf8)

        let conflict = SyncConflict(
            id: "Amazing Grace",
            title: "Amazing Grace",
            localSHA: "local_sha",
            remoteSHA: "remote_sha"
        )

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        // resolveConflict fetches remote content first
        mockHTTP.when(method: "GET", "/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.fileContent(sha: "remote_sha", content: SyncFixtures.contentForSong(song)),
                       statusCode: 200)
        // pushSingleSong lists directory then creates/updates
        mockHTTP.when("/contents/songs",
                       data: SyncFixtures.directoryListing(files: [("Amazing Grace.onsong", "remote_sha")]),
                       statusCode: 200)
        mockHTTP.when(method: "PUT", "/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: "pushed_sha"),
                       statusCode: 200)

        // When
        try await manager.resolveConflict(conflict, resolution: .useLocal)

        // Then: remote should have been updated
        let putRequests = mockHTTP.requests.filter { $0.httpMethod == "PUT" }
        XCTAssertFalse(putRequests.isEmpty)
    }

    func testResolveConflict_useRemote() async throws {
        // Given: a conflict
        let localSong = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(localSong).write(to: fileURL, atomically: true, encoding: .utf8)

        let remoteContent = SyncFixtures.contentForSong(SyncFixtures.makeSong(artist: "Remote Artist"))
        let remoteSHA = "remote_sha_resolve"

        let conflict = SyncConflict(
            id: "Amazing Grace",
            title: "Amazing Grace",
            localSHA: "local_sha",
            remoteSHA: remoteSHA
        )

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.fileContent(sha: remoteSHA, content: remoteContent),
                       statusCode: 200)

        // When
        try await manager.resolveConflict(conflict, resolution: .useRemote)

        // Then: local file should be overwritten
        let savedContent = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(savedContent.contains("Remote Artist"))
    }

    // MARK: - Progress Callback

    func testPushSongs_firesProgressCallbacks() async throws {
        let song = SyncFixtures.makeSong()
        let fileURL = tempDir.appendingPathComponent("Amazing Grace.onsong")
        try SyncFixtures.contentForSong(song).write(to: fileURL, atomically: true, encoding: .utf8)

        mockHTTP.when("/user", data: SyncFixtures.userResponse, statusCode: 200)
        mockHTTP.when("/contents/songs", data: Data(), statusCode: 404)
        mockHTTP.when("/contents/songs/Amazing%20Grace.onsong",
                       data: SyncFixtures.createUpdateResponse(sha: "sha"),
                       statusCode: 201)

        var progressEvents: [String] = []

        _ = try await manager.pushSongs { progress in
            switch progress {
            case .authenticating: progressEvents.append("auth")
            case .fetchingRemoteSongs: progressEvents.append("fetch")
            case .comparingSongs: progressEvents.append("compare")
            case .uploadingSong: progressEvents.append("upload")
            case .downloadingSong: progressEvents.append("download")
            case .resolvingConflicts: progressEvents.append("resolve")
            case .completed: progressEvents.append("complete")
            }
        }

        XCTAssertTrue(progressEvents.contains("auth"))
        XCTAssertTrue(progressEvents.contains("fetch"))
        XCTAssertTrue(progressEvents.contains("compare"))
        XCTAssertTrue(progressEvents.contains("upload"))
        XCTAssertTrue(progressEvents.contains("complete"))
    }
}

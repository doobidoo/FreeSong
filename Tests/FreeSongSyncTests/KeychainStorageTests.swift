import XCTest
@testable import FreeSongSync

/// Tests for Keychain-backed PAT storage.
///
/// These tests hit the real system Keychain on macOS/iOS.
/// The Keychain is available in normal development environments.
/// CI environments may not have a Keychain — those runs will skip.
final class KeychainStorageTests: XCTestCase {

    override func tearDown() {
        try? KeychainStorage.delete()
    }

    // MARK: - Store & Retrieve

    func testStoreAndRetrieve() throws {
        try KeychainStorage.store(token: "my_secret_token_123")
        let retrieved = try KeychainStorage.retrieve()
        XCTAssertEqual(retrieved, "my_secret_token_123")
    }

    func testStore_overwritesExisting() throws {
        try KeychainStorage.store(token: "first_token")
        try KeychainStorage.store(token: "second_token")
        let retrieved = try KeychainStorage.retrieve()
        XCTAssertEqual(retrieved, "second_token")
    }

    // MARK: - Delete

    func testDelete_removesToken() throws {
        try KeychainStorage.store(token: "token_to_delete")
        try KeychainStorage.delete()

        let retrieved = try KeychainStorage.retrieve()
        XCTAssertNil(retrieved)
    }

    func testDelete_whenEmpty_doesNotThrow() throws {
        // Deleting from an empty Keychain should succeed.
        try KeychainStorage.delete()
        try KeychainStorage.delete() // second delete is a no-op
    }

    // MARK: - hasToken

    func testHasToken_whenStored() throws {
        XCTAssertFalse(KeychainStorage.hasToken)
        try KeychainStorage.store(token: "exists")
        XCTAssertTrue(KeychainStorage.hasToken)
    }

    func testHasToken_afterDelete() throws {
        try KeychainStorage.store(token: "temp")
        try KeychainStorage.delete()
        XCTAssertFalse(KeychainStorage.hasToken)
    }

    // MARK: - Token validation utility

    func testStore_emptyToken() throws {
        // Even empty strings should be storable/retrievable.
        try KeychainStorage.store(token: "")
        let retrieved = try KeychainStorage.retrieve()
        XCTAssertEqual(retrieved, "")
    }

    func testStore_tokenWithSpecialCharacters() throws {
        let complexToken = "ghp_ABCdefGHIjklMNO123!@#$%^&*()_+-=[]{}|;':\",./<>?`~"
        try KeychainStorage.store(token: complexToken)
        let retrieved = try KeychainStorage.retrieve()
        XCTAssertEqual(retrieved, complexToken)
    }
}

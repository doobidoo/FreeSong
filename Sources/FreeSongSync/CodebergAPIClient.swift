import Foundation

// MARK: - HTTP Client Protocol

/// Abstract HTTP client for testability.
public protocol HTTPClient: Sendable {
    /// Send a request and return the raw response data and status code.
    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int)
}

/// Production HTTP client using URLSession.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        return (data, httpResponse.statusCode)
    }
}

// MARK: - Codeberg API Client

/// Low-level REST client for the Codeberg (Gitea) Contents API.
///
/// Uses a Personal Access Token for authentication.
/// All file operations target a single branch in a single repository.
public actor CodebergAPIClient {

    private let configuration: CodebergConfiguration
    private let httpClient: HTTPClient

    // MARK: Initialization

    public init(
        configuration: CodebergConfiguration,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
    }

    // MARK: - Public API

    /// Fetch the SHA of the branch HEAD reference.
    public func getReference() async throws -> String {
        let url = url(for: "/repos/\(configuration.owner)/\(configuration.repo)/git/refs/heads/\(configuration.branch)")
        let request = try authenticatedRequest(url: url)
        let (data, statusCode) = try await httpClient.send(request)

        guard statusCode == 200 else {
            try throwMappedError(statusCode: statusCode, data: data)
            throw SyncError.networkError("Failed to get reference (HTTP \(statusCode))")
        }

        let ref = try JSONDecoder().decode(CodebergRef.self, from: data)
        return ref.object.sha
    }

    /// List all items at a given path in the repository.
    /// - Parameter path: Path relative to repo root (e.g. "songs").
    /// - Returns: Array of content items (files and directories).
    public func listDirectory(path: String) async throws -> [CodebergContentItem] {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = url(for: "/repos/\(configuration.owner)/\(configuration.repo)/contents/\(encodedPath)")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ref", value: configuration.branch)]
        guard let finalURL = components?.url else {
            throw SyncError.networkError("Invalid URL for path: \(path)")
        }

        let request = try authenticatedRequest(url: finalURL)
        let (data, statusCode) = try await httpClient.send(request)

        switch statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([CodebergContentItem].self, from: data)
        case 404:
            return [] // Path doesn't exist yet
        default:
            try throwMappedError(statusCode: statusCode, data: data)
            throw SyncError.networkError("Failed to list directory (HTTP \(statusCode))")
        }
    }

    /// Get a single file's content and metadata.
    /// - Parameter path: Path to the file.
    /// - Returns: Tuple of decoded content + SHA for conflict detection.
    public func getFileContent(path: String) async throws -> (data: Data, sha: String) {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = url(for: "/repos/\(configuration.owner)/\(configuration.repo)/contents/\(encodedPath)")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ref", value: configuration.branch)]
        guard let finalURL = components?.url else {
            throw SyncError.networkError("Invalid URL for path: \(path)")
        }

        let request = try authenticatedRequest(url: finalURL)
        let (data, statusCode) = try await httpClient.send(request)

        guard statusCode == 200 else {
            try throwMappedError(statusCode: statusCode, data: data)
            throw SyncError.networkError("Failed to get file content (HTTP \(statusCode))")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let item = try decoder.decode(CodebergContentItem.self, from: data)

        guard let base64Content = item.content,
              let decodedData = Data(base64Encoded: base64Content.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SyncError.networkError("Failed to decode file content from base64")
        }

        return (decodedData, item.sha)
    }

    /// Create or update a file at the given path.
    /// - Parameters:
    ///   - path: Path where the file should be stored.
    ///   - content: Raw data to write.
    ///   - sha: Existing file SHA (required for updates, nil for new files).
    /// - Returns: API response with commit SHA.
    /// - Throws: `SyncError.conflict` if the remote file has changed since last fetch.
    public func createOrUpdateFile(
        path: String,
        content: Data,
        sha: String?
    ) async throws -> CodebergCreateUpdateResponse {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = url(for: "/repos/\(configuration.owner)/\(configuration.repo)/contents/\(encodedPath)")

        let body = CodebergCreateUpdateRequest(
            message: "Update \(path)",
            content: content.base64EncodedString(),
            sha: sha,
            branch: configuration.branch
        )

        var request = try authenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, statusCode) = try await httpClient.send(request)

        switch statusCode {
        case 200, 201:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(CodebergCreateUpdateResponse.self, from: data)
        case 409:
            throw SyncError.conflict("Remote file has changed. Fetch latest before updating.")
        default:
            try throwMappedError(statusCode: statusCode, data: data)
            throw SyncError.networkError("Failed to write file (HTTP \(statusCode))")
        }
    }

    /// Delete a file from the repository.
    public func deleteFile(path: String, sha: String) async throws {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = url(for: "/repos/\(configuration.owner)/\(configuration.repo)/contents/\(encodedPath)")

        let body: [String: Any] = [
            "message": "Delete \(path)",
            "sha": sha,
            "branch": configuration.branch,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = try authenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (_, statusCode) = try await httpClient.send(request)

        guard statusCode == 200 else {
            throw SyncError.networkError("Failed to delete file (HTTP \(statusCode))")
        }
    }

    /// Validate that the configuration and token work by fetching the user's info.
    public func validateAccess() async throws -> Bool {
        let url = url(for: "/user")
        let request = try authenticatedRequest(url: url)
        let (_, statusCode) = try await httpClient.send(request)
        return statusCode == 200
    }

    // MARK: - Private Helpers

    private func url(for path: String) -> URL {
        guard let url = URL(string: configuration.baseURL + path) else {
            fatalError("Invalid URL: \(configuration.baseURL)\(path)")
        }
        return url
    }

    private func authenticatedRequest(url: URL) throws -> URLRequest {
        guard let token = try KeychainStorage.retrieve() else {
            throw SyncError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        return request
    }

    /// Parse error response body from Codeberg API into a SyncError.
    private func throwMappedError(statusCode: Int, data: Data) throws {
        switch statusCode {
        case 401:
            throw SyncError.authenticationFailed("Token is invalid or expired")
        case 403:
            throw SyncError.authenticationFailed("Insufficient permissions")
        case 404:
            throw SyncError.notFound("Repository or path not found")
        case 409:
            throw SyncError.conflict("File conflict detected")
        default:
            if let errorBody = try? JSONDecoder().decode(CodebergErrorMessage.self, from: data) {
                throw SyncError.networkError(errorBody.message)
            }
        }
    }
}

// MARK: - Internal API Types

/// Response from the Git references endpoint.
struct CodebergRef: Codable {
    let ref: String
    let object: CodebergRefObject
    let url: String
}

struct CodebergRefObject: Codable {
    let sha: String
    let type: String
    let url: String
}

/// Error response body from Codeberg API.
struct CodebergErrorMessage: Codable {
    let message: String
    let documentationURL: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationURL = "documentation_url"
    }
}

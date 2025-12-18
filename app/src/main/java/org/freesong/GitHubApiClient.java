package org.freesong;

import android.util.Base64;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

/**
 * GitHub REST API client for file operations.
 * Uses HttpURLConnection for Android 4.4 compatibility.
 */
public class GitHubApiClient {

    private static final String TAG = "GitHubApiClient";
    private static final String API_BASE = "https://api.github.com";
    private static final int TIMEOUT_MS = 30000;

    private String token;
    private String repo;
    private String lastError;  // Stores last error for debugging

    /**
     * Represents a file in a GitHub repository.
     */
    public static class GitHubFile {
        public String name;
        public String path;
        public String sha;
        public long size;
        public String type;  // "file" or "dir"
        public String downloadUrl;

        @Override
        public String toString() {
            return "GitHubFile{name='" + name + "', path='" + path + "', sha='" + sha + "'}";
        }
    }

    /**
     * API response wrapper.
     */
    public static class ApiResponse {
        public boolean success;
        public int statusCode;
        public String body;
        public String errorMessage;

        public ApiResponse(boolean success, int statusCode, String body, String errorMessage) {
            this.success = success;
            this.statusCode = statusCode;
            this.body = body;
            this.errorMessage = errorMessage;
        }
    }

    public GitHubApiClient(String token, String repo) {
        this.token = token;
        this.repo = repo;
        this.lastError = null;
    }

    /**
     * Get the last error message (for debugging).
     */
    public String getLastError() {
        return lastError;
    }

    /**
     * Test the connection and credentials.
     * @return true if connection successful, false otherwise
     */
    public ApiResponse testConnection() {
        try {
            ApiResponse response = doRequest("GET", "/repos/" + repo, null);
            if (response.success) {
                JSONObject json = new JSONObject(response.body);
                String repoName = json.getString("full_name");
                Log.d(TAG, "Connected to repository: " + repoName);
            }
            return response;
        } catch (Exception e) {
            Log.e(TAG, "Connection test failed", e);
            return new ApiResponse(false, -1, null, e.getMessage());
        }
    }

    /**
     * List files in a directory.
     * @param path Directory path (empty string for root)
     * @return List of files, or empty list on error
     */
    public List<GitHubFile> listFiles(String path) {
        List<GitHubFile> files = new ArrayList<GitHubFile>();

        try {
            String endpoint = "/repos/" + repo + "/contents/" + path;
            ApiResponse response = doRequest("GET", endpoint, null);

            if (!response.success) {
                Log.e(TAG, "Failed to list files: " + response.errorMessage);
                return files;
            }

            JSONArray array = new JSONArray(response.body);
            for (int i = 0; i < array.length(); i++) {
                JSONObject obj = array.getJSONObject(i);
                GitHubFile file = new GitHubFile();
                file.name = obj.getString("name");
                file.path = obj.getString("path");
                file.sha = obj.getString("sha");
                file.size = obj.optLong("size", 0);
                file.type = obj.getString("type");
                file.downloadUrl = obj.optString("download_url", null);
                files.add(file);
            }
        } catch (JSONException e) {
            Log.e(TAG, "JSON parse error listing files", e);
        }

        return files;
    }

    /**
     * Get a single file's metadata (including SHA).
     * @param path File path
     * @return GitHubFile or null if not found
     */
    public GitHubFile getFile(String path) {
        try {
            String endpoint = "/repos/" + repo + "/contents/" + path;
            ApiResponse response = doRequest("GET", endpoint, null);

            if (!response.success) {
                if (response.statusCode == 404) {
                    return null;  // File doesn't exist
                }
                Log.e(TAG, "Failed to get file: " + response.errorMessage);
                return null;
            }

            JSONObject obj = new JSONObject(response.body);
            GitHubFile file = new GitHubFile();
            file.name = obj.getString("name");
            file.path = obj.getString("path");
            file.sha = obj.getString("sha");
            file.size = obj.optLong("size", 0);
            file.type = obj.getString("type");
            file.downloadUrl = obj.optString("download_url", null);
            return file;
        } catch (JSONException e) {
            Log.e(TAG, "JSON parse error getting file", e);
            return null;
        }
    }

    /**
     * Get file content as string.
     * @param path File path
     * @return File content or null on error
     */
    public String getFileContent(String path) {
        try {
            String endpoint = "/repos/" + repo + "/contents/" + path;
            ApiResponse response = doRequest("GET", endpoint, null);

            if (!response.success) {
                Log.e(TAG, "Failed to get file content: " + response.errorMessage);
                return null;
            }

            JSONObject obj = new JSONObject(response.body);
            String encoding = obj.optString("encoding", "base64");
            String content = obj.getString("content");

            if ("base64".equals(encoding)) {
                // Remove newlines that GitHub adds to base64
                content = content.replace("\n", "");
                byte[] decoded = Base64.decode(content, Base64.DEFAULT);
                return new String(decoded, "UTF-8");
            } else {
                return content;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting file content", e);
            return null;
        }
    }

    /**
     * Create or update a file.
     * @param path File path
     * @param content File content
     * @param sha Existing SHA (null for new file)
     * @param message Commit message
     * @return ApiResponse
     */
    public ApiResponse createOrUpdateFile(String path, String content, String sha, String message) {
        try {
            String endpoint = "/repos/" + repo + "/contents/" + path;

            JSONObject body = new JSONObject();
            body.put("message", message);
            body.put("content", encodeBase64(content));
            if (sha != null && !sha.isEmpty()) {
                body.put("sha", sha);
            }

            return doRequest("PUT", endpoint, body.toString());
        } catch (JSONException e) {
            Log.e(TAG, "Error creating request body", e);
            return new ApiResponse(false, -1, null, e.getMessage());
        }
    }

    /**
     * Delete a file.
     * @param path File path
     * @param sha File SHA (required)
     * @param message Commit message
     * @return ApiResponse
     */
    public ApiResponse deleteFile(String path, String sha, String message) {
        try {
            String endpoint = "/repos/" + repo + "/contents/" + path;

            JSONObject body = new JSONObject();
            body.put("message", message);
            body.put("sha", sha);

            return doRequest("DELETE", endpoint, body.toString());
        } catch (JSONException e) {
            Log.e(TAG, "Error creating request body", e);
            return new ApiResponse(false, -1, null, e.getMessage());
        }
    }

    /**
     * Ensure a directory exists by creating a .gitkeep file if needed.
     * @param dirPath Directory path
     * @return true if directory exists or was created
     */
    public boolean ensureDirectory(String dirPath) {
        List<GitHubFile> files = listFiles(dirPath);
        if (!files.isEmpty()) {
            return true;  // Directory exists with files
        }

        // Try to create a .gitkeep file to create the directory
        String gitkeepPath = dirPath + "/.gitkeep";
        ApiResponse response = createOrUpdateFile(gitkeepPath, "", null, "Create directory");
        return response.success;
    }

    /**
     * Perform an HTTP request to the GitHub API.
     */
    private ApiResponse doRequest(String method, String endpoint, String body) {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(API_BASE + endpoint);
            conn = (HttpURLConnection) url.openConnection();

            // Android 4.4 HttpURLConnection doesn't support PATCH properly
            // Use POST with X-HTTP-Method-Override header as workaround
            if ("PATCH".equals(method)) {
                conn.setRequestMethod("POST");
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH");
                Log.d(TAG, "Using X-HTTP-Method-Override for PATCH request");
            } else {
                conn.setRequestMethod(method);
            }

            conn.setConnectTimeout(TIMEOUT_MS);
            conn.setReadTimeout(TIMEOUT_MS);

            // Headers
            conn.setRequestProperty("Authorization", "token " + token);
            conn.setRequestProperty("Accept", "application/vnd.github.v3+json");
            conn.setRequestProperty("User-Agent", "FreeSong-Android");

            // Body for PUT/POST/DELETE
            if (body != null && !body.isEmpty()) {
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setDoOutput(true);
                OutputStream os = conn.getOutputStream();
                os.write(body.getBytes("UTF-8"));
                os.close();
            }

            int statusCode = conn.getResponseCode();
            boolean success = statusCode >= 200 && statusCode < 300;

            // Read response
            BufferedReader reader;
            if (success) {
                reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), "UTF-8"));
            } else {
                reader = new BufferedReader(new InputStreamReader(conn.getErrorStream(), "UTF-8"));
            }

            StringBuilder responseBody = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                responseBody.append(line);
            }
            reader.close();

            String errorMessage = null;
            if (!success) {
                try {
                    JSONObject errorJson = new JSONObject(responseBody.toString());
                    errorMessage = errorJson.optString("message", "HTTP " + statusCode);
                } catch (JSONException e) {
                    errorMessage = "HTTP " + statusCode;
                }
            }

            return new ApiResponse(success, statusCode, responseBody.toString(), errorMessage);

        } catch (IOException e) {
            Log.e(TAG, "HTTP request failed: " + method + " " + endpoint, e);
            return new ApiResponse(false, -1, null, e.getMessage());
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    /**
     * Encode content to Base64.
     */
    private String encodeBase64(String content) {
        try {
            byte[] bytes = content.getBytes("UTF-8");
            return Base64.encodeToString(bytes, Base64.NO_WRAP);
        } catch (Exception e) {
            return "";
        }
    }

    // ==================== Git Trees API (Batch Operations) ====================

    /**
     * File entry for batch upload.
     */
    public static class TreeEntry {
        public String path;
        public String content;

        public TreeEntry(String path, String content) {
            this.path = path;
            this.content = content;
        }
    }

    /**
     * Get the SHA of the latest commit on a branch.
     * @param branch Branch name (e.g., "main" or "master")
     * @return SHA string or null on error
     */
    public String getLatestCommitSha(String branch) {
        try {
            String endpoint = "/repos/" + repo + "/git/refs/heads/" + branch;
            ApiResponse response = doRequest("GET", endpoint, null);

            if (!response.success) {
                lastError = "Get branch ref failed: HTTP " + response.statusCode + " - " + response.errorMessage;
                Log.e(TAG, lastError);
                return null;
            }

            JSONObject json = new JSONObject(response.body);
            return json.getJSONObject("object").getString("sha");
        } catch (Exception e) {
            lastError = "Get commit SHA exception: " + e.getMessage();
            Log.e(TAG, lastError, e);
            return null;
        }
    }

    /**
     * Get the tree SHA from a commit.
     * @param commitSha Commit SHA
     * @return Tree SHA or null on error
     */
    public String getTreeSha(String commitSha) {
        try {
            String endpoint = "/repos/" + repo + "/git/commits/" + commitSha;
            ApiResponse response = doRequest("GET", endpoint, null);

            if (!response.success) {
                lastError = "Get tree SHA failed: HTTP " + response.statusCode + " - " + response.errorMessage;
                Log.e(TAG, lastError);
                return null;
            }

            JSONObject json = new JSONObject(response.body);
            return json.getJSONObject("tree").getString("sha");
        } catch (Exception e) {
            lastError = "Get tree SHA exception: " + e.getMessage();
            Log.e(TAG, lastError, e);
            return null;
        }
    }

    /**
     * Create a blob for a file and return its SHA.
     * This is needed for larger files (>100KB) or to avoid request size limits.
     * @param content File content
     * @return Blob SHA or null on error
     */
    public String createBlob(String content) {
        try {
            JSONObject body = new JSONObject();
            body.put("content", encodeBase64(content));
            body.put("encoding", "base64");

            String endpoint = "/repos/" + repo + "/git/blobs";
            ApiResponse response = doRequest("POST", endpoint, body.toString());

            if (!response.success) {
                lastError = "Blob creation failed: HTTP " + response.statusCode + " - " + response.errorMessage;
                Log.e(TAG, lastError);
                return null;
            }

            JSONObject json = new JSONObject(response.body);
            return json.getString("sha");
        } catch (Exception e) {
            lastError = "Blob exception: " + e.getMessage();
            Log.e(TAG, lastError, e);
            return null;
        }
    }

    /**
     * Create a new tree with multiple files (batch upload).
     * Creates blobs first for each file, then references them by SHA.
     * @param baseTreeSha Base tree SHA (can be null for new repo)
     * @param entries List of files to add/update
     * @return New tree SHA or null on error
     */
    public String createTree(String baseTreeSha, List<TreeEntry> entries) {
        try {
            // First, create blobs for all files
            Log.d(TAG, "Creating blobs for " + entries.size() + " files...");
            List<String> blobShas = new ArrayList<String>();
            int blobCount = 0;
            for (TreeEntry entry : entries) {
                String blobSha = createBlob(entry.content);
                if (blobSha == null) {
                    Log.e(TAG, "Failed to create blob for: " + entry.path);
                    return null;
                }
                blobShas.add(blobSha);
                blobCount++;
                if (blobCount % 10 == 0) {
                    Log.d(TAG, "Created " + blobCount + "/" + entries.size() + " blobs...");
                }
            }
            Log.d(TAG, "All " + blobCount + " blobs created successfully");

            // Now create tree with blob references
            JSONObject body = new JSONObject();

            if (baseTreeSha != null && !baseTreeSha.isEmpty()) {
                body.put("base_tree", baseTreeSha);
            }

            JSONArray tree = new JSONArray();
            for (int i = 0; i < entries.size(); i++) {
                TreeEntry entry = entries.get(i);
                String blobSha = blobShas.get(i);

                JSONObject item = new JSONObject();
                item.put("path", entry.path);
                item.put("mode", "100644");  // Regular file
                item.put("type", "blob");
                item.put("sha", blobSha);  // Reference blob by SHA instead of inline content
                tree.put(item);
            }
            body.put("tree", tree);

            String endpoint = "/repos/" + repo + "/git/trees";
            ApiResponse response = doRequest("POST", endpoint, body.toString());

            if (!response.success) {
                lastError = "Create tree failed: HTTP " + response.statusCode + " - " + response.errorMessage;
                Log.e(TAG, lastError);
                return null;
            }

            JSONObject json = new JSONObject(response.body);
            return json.getString("sha");
        } catch (Exception e) {
            lastError = "Create tree exception: " + e.getMessage();
            Log.e(TAG, lastError, e);
            return null;
        }
    }

    /**
     * Create a new commit.
     * @param message Commit message
     * @param treeSha Tree SHA
     * @param parentSha Parent commit SHA
     * @return New commit SHA or null on error
     */
    public String createCommit(String message, String treeSha, String parentSha) {
        try {
            JSONObject body = new JSONObject();
            body.put("message", message);
            body.put("tree", treeSha);

            JSONArray parents = new JSONArray();
            if (parentSha != null && !parentSha.isEmpty()) {
                parents.put(parentSha);
            }
            body.put("parents", parents);

            String endpoint = "/repos/" + repo + "/git/commits";
            ApiResponse response = doRequest("POST", endpoint, body.toString());

            if (!response.success) {
                lastError = "Create commit failed: HTTP " + response.statusCode + " - " + response.errorMessage;
                Log.e(TAG, lastError);
                return null;
            }

            JSONObject json = new JSONObject(response.body);
            return json.getString("sha");
        } catch (Exception e) {
            lastError = "Create commit exception: " + e.getMessage();
            Log.e(TAG, lastError, e);
            return null;
        }
    }

    /**
     * Update a branch reference to point to a new commit.
     * @param branch Branch name
     * @param commitSha New commit SHA
     * @return true on success
     */
    public boolean updateRef(String branch, String commitSha) {
        try {
            JSONObject body = new JSONObject();
            body.put("sha", commitSha);
            body.put("force", false);

            String endpoint = "/repos/" + repo + "/git/refs/heads/" + branch;
            ApiResponse response = doRequest("PATCH", endpoint, body.toString());

            if (!response.success) {
                lastError = "Update ref failed: HTTP " + response.statusCode + " - " + response.errorMessage;
                Log.e(TAG, lastError);
                return false;
            }

            return true;
        } catch (Exception e) {
            lastError = "Update ref exception: " + e.getMessage();
            Log.e(TAG, lastError, e);
            return false;
        }
    }

    /**
     * Upload multiple files in a single commit (batch upload).
     * @param branch Branch name (e.g., "main")
     * @param entries Files to upload
     * @param message Commit message
     * @return true on success
     */
    public boolean batchUpload(String branch, List<TreeEntry> entries, String message) {
        lastError = null;  // Clear previous error

        if (entries == null || entries.isEmpty()) {
            return true;  // Nothing to upload
        }

        Log.d(TAG, "Batch uploading " + entries.size() + " files to branch '" + branch + "'...");

        // 1. Get latest commit SHA
        Log.d(TAG, "Step 1: Getting latest commit SHA...");
        String commitSha = getLatestCommitSha(branch);
        if (commitSha == null) {
            Log.e(TAG, "FAILED: Could not get latest commit for branch: " + branch);
            return false;
        }
        Log.d(TAG, "Got commit SHA: " + commitSha.substring(0, 7));

        // 2. Get base tree SHA
        Log.d(TAG, "Step 2: Getting base tree SHA...");
        String baseTreeSha = getTreeSha(commitSha);
        if (baseTreeSha == null) {
            Log.e(TAG, "FAILED: Could not get base tree");
            return false;
        }
        Log.d(TAG, "Got tree SHA: " + baseTreeSha.substring(0, 7));

        // 3. Create new tree with all files
        Log.d(TAG, "Step 3: Creating tree with " + entries.size() + " files...");
        String newTreeSha = createTree(baseTreeSha, entries);
        if (newTreeSha == null) {
            Log.e(TAG, "FAILED: Could not create tree (API limit exceeded?)");
            return false;
        }
        Log.d(TAG, "Created tree SHA: " + newTreeSha.substring(0, 7));

        // 4. Create commit
        Log.d(TAG, "Step 4: Creating commit...");
        String newCommitSha = createCommit(message, newTreeSha, commitSha);
        if (newCommitSha == null) {
            Log.e(TAG, "FAILED: Could not create commit");
            return false;
        }
        Log.d(TAG, "Created commit SHA: " + newCommitSha.substring(0, 7));

        // 5. Update branch reference
        Log.d(TAG, "Step 5: Updating branch reference...");
        boolean success = updateRef(branch, newCommitSha);
        if (success) {
            Log.d(TAG, "SUCCESS: Batch upload complete - " + entries.size() + " files in 1 commit");
        } else {
            Log.e(TAG, "FAILED: Could not update branch reference");
        }

        return success;
    }

    /**
     * Detect the default branch of the repository.
     * @return Branch name ("main" or "master") or null on error
     */
    public String getDefaultBranch() {
        try {
            ApiResponse response = doRequest("GET", "/repos/" + repo, null);
            if (!response.success) {
                return null;
            }

            JSONObject json = new JSONObject(response.body);
            return json.optString("default_branch", "main");
        } catch (Exception e) {
            Log.e(TAG, "Error getting default branch", e);
            return "main";
        }
    }
}

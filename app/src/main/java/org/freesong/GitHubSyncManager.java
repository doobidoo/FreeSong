package org.freesong;

import android.content.Context;
import android.os.Environment;
import android.util.Log;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Manager for GitHub synchronization.
 * Syncs songs and setlists between local storage and a GitHub repository.
 */
public class GitHubSyncManager {

    private static final String TAG = "GitHubSyncManager";
    private static final String SONGS_DIR = "songs";
    private static final String SETLISTS_FILE = "setlists.json";

    private Context context;
    private GitHubApiClient api;
    private SyncCallback callback;

    /**
     * Callback for sync progress updates.
     */
    public interface SyncCallback {
        void onProgress(String message);
        void onComplete(SyncResult result);
    }

    /**
     * Result of a sync operation.
     */
    public static class SyncResult {
        public int downloaded = 0;
        public int uploaded = 0;
        public int conflicts = 0;
        public int errors = 0;
        public List<String> messages = new ArrayList<String>();

        public boolean hasErrors() {
            return errors > 0;
        }

        public String getSummary() {
            StringBuilder sb = new StringBuilder();
            if (downloaded > 0) sb.append("Downloaded: ").append(downloaded).append("\n");
            if (uploaded > 0) sb.append("Uploaded: ").append(uploaded).append("\n");
            if (conflicts > 0) sb.append("Conflicts: ").append(conflicts).append("\n");
            if (errors > 0) sb.append("Errors: ").append(errors).append("\n");
            if (sb.length() == 0) sb.append("Everything up to date");

            // Add error details (show first 5 messages to avoid huge dialog)
            if (!messages.isEmpty()) {
                sb.append("\n--- Details ---\n");
                int maxShow = Math.min(messages.size(), 5);
                for (int i = 0; i < maxShow; i++) {
                    sb.append(messages.get(i)).append("\n");
                }
                if (messages.size() > maxShow) {
                    sb.append("... and ").append(messages.size() - maxShow).append(" more");
                }
            }
            return sb.toString().trim();
        }
    }

    public GitHubSyncManager(Context context) {
        this.context = context;
        String token = GitHubConfig.getToken(context);
        String repo = GitHubConfig.getRepo(context);
        this.api = new GitHubApiClient(token, repo);
    }

    public void setCallback(SyncCallback callback) {
        this.callback = callback;
    }

    /**
     * Perform full sync (songs + setlists).
     */
    public SyncResult syncAll() {
        SyncResult result = new SyncResult();

        progress("Checking connection...");
        GitHubApiClient.ApiResponse testResponse = api.testConnection();
        if (!testResponse.success) {
            result.errors++;
            result.messages.add("Connection failed: " + testResponse.errorMessage);
            return result;
        }

        // Sync songs
        progress("Syncing songs...");
        syncSongs(result);

        // Sync setlists
        progress("Syncing setlists...");
        syncSetlists(result);

        // Update last sync time
        if (!result.hasErrors()) {
            GitHubConfig.setLastSync(context, System.currentTimeMillis());
        }

        progress("Sync complete");
        return result;
    }

    /**
     * Sync songs between local FreeSong folder and GitHub.
     * Uses batch upload for efficiency (single commit for all new songs).
     */
    private void syncSongs(SyncResult result) {
        File freeSongDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!freeSongDir.exists()) {
            freeSongDir.mkdirs();
        }

        // Get local songs
        File[] localFiles = freeSongDir.listFiles(new FilenameFilter() {
            @Override
            public boolean accept(File dir, String name) {
                String lower = name.toLowerCase();
                return lower.endsWith(".onsong") ||
                       lower.endsWith(".chordpro") ||
                       lower.endsWith(".cho") ||
                       lower.endsWith(".crd") ||
                       lower.endsWith(".pro") ||
                       lower.endsWith(".txt");
            }
        });

        Map<String, File> localSongs = new HashMap<String, File>();
        if (localFiles != null) {
            for (File f : localFiles) {
                localSongs.put(f.getName(), f);
            }
        }

        // Get remote songs
        progress("Fetching remote file list...");
        List<GitHubApiClient.GitHubFile> remoteFiles = api.listFiles(SONGS_DIR);
        Map<String, GitHubApiClient.GitHubFile> remoteSongs = new HashMap<String, GitHubApiClient.GitHubFile>();
        for (GitHubApiClient.GitHubFile f : remoteFiles) {
            if ("file".equals(f.type)) {
                remoteSongs.put(f.name, f);
            }
        }

        // Find songs to download (exist remotely but not locally)
        Set<String> toDownload = new HashSet<String>(remoteSongs.keySet());
        toDownload.removeAll(localSongs.keySet());

        // Find songs to upload (exist locally but not remotely)
        Set<String> toUpload = new HashSet<String>(localSongs.keySet());
        toUpload.removeAll(remoteSongs.keySet());

        // Find songs that exist in both (potential conflicts)
        Set<String> bothExist = new HashSet<String>(localSongs.keySet());
        bothExist.retainAll(remoteSongs.keySet());

        // Download new songs
        int downloadCount = 0;
        for (String name : toDownload) {
            downloadCount++;
            progress("Downloading (" + downloadCount + "/" + toDownload.size() + "): " + name);
            String content = api.getFileContent(SONGS_DIR + "/" + name);
            if (content != null) {
                if (writeFile(new File(freeSongDir, name), content)) {
                    result.downloaded++;
                } else {
                    result.errors++;
                    result.messages.add("Failed to write: " + name);
                }
            } else {
                result.errors++;
                result.messages.add("Failed to download: " + name);
            }
        }

        // Batch upload new songs (in chunks to avoid API limits)
        if (!toUpload.isEmpty()) {
            progress("Preparing upload of " + toUpload.size() + " songs...");

            // Get default branch
            String branch = api.getDefaultBranch();
            if (branch == null) {
                branch = "main";
            }

            // Collect all files to upload
            List<GitHubApiClient.TreeEntry> allEntries = new ArrayList<GitHubApiClient.TreeEntry>();
            for (String name : toUpload) {
                File localFile = localSongs.get(name);
                String content = readFile(localFile);
                if (content != null) {
                    allEntries.add(new GitHubApiClient.TreeEntry(SONGS_DIR + "/" + name, content));
                }
            }

            // Batch upload in chunks (reduced to 25 since each file needs a blob API call)
            int BATCH_SIZE = 25;
            int totalBatches = (allEntries.size() + BATCH_SIZE - 1) / BATCH_SIZE;
            int uploadedCount = 0;

            for (int batch = 0; batch < totalBatches; batch++) {
                int start = batch * BATCH_SIZE;
                int end = Math.min(start + BATCH_SIZE, allEntries.size());
                List<GitHubApiClient.TreeEntry> batchEntries = allEntries.subList(start, end);

                int remaining = allEntries.size() - uploadedCount;
                progress("Uploading " + batchEntries.size() + " songs (batch " + (batch + 1) + "/" + totalBatches + ", " + remaining + " remaining)...");

                boolean success = api.batchUpload(branch, batchEntries,
                    "FreeSong sync: " + batchEntries.size() + " songs (batch " + (batch + 1) + "/" + totalBatches + ")");

                if (success) {
                    uploadedCount += batchEntries.size();
                    progress("Batch " + (batch + 1) + " complete (" + uploadedCount + "/" + allEntries.size() + " uploaded)");
                } else {
                    result.errors++;
                    String errorDetail = api.getLastError();
                    if (errorDetail != null) {
                        result.messages.add("Batch " + (batch + 1) + ": " + errorDetail);
                    } else {
                        result.messages.add("Batch " + (batch + 1) + " failed (unknown error)");
                    }
                    Log.e(TAG, "Batch " + (batch + 1) + " failed: " + errorDetail);
                    // Continue with next batch instead of stopping
                }
            }

            if (uploadedCount > 0) {
                result.uploaded = uploadedCount;
                result.messages.add("Uploaded " + uploadedCount + " songs in " + totalBatches + " commits");
            }
        }

        // Handle potential conflicts (files that exist in both places)
        // Only check a sample to avoid too many API calls
        int conflictCheckLimit = Math.min(bothExist.size(), 50);
        int checked = 0;
        for (String name : bothExist) {
            if (checked >= conflictCheckLimit) {
                if (bothExist.size() > conflictCheckLimit) {
                    result.messages.add("Skipped conflict check for " + (bothExist.size() - conflictCheckLimit) + " files");
                }
                break;
            }
            checked++;

            File localFile = localSongs.get(name);
            String localContent = readFile(localFile);
            String remoteContent = api.getFileContent(SONGS_DIR + "/" + name);

            if (localContent == null || remoteContent == null) {
                continue;  // Skip if we can't compare
            }

            // Compare content hashes
            String localHash = md5(localContent);
            String remoteHash = md5(remoteContent);

            if (!localHash.equals(remoteHash)) {
                // Conflict! Keep both versions
                progress("Conflict detected: " + name);

                // Save local version as conflict file
                String conflictName = getConflictName(name);
                File conflictFile = new File(freeSongDir, conflictName);
                if (writeFile(conflictFile, localContent)) {
                    result.messages.add("Local version saved as: " + conflictName);
                }

                // Download remote version
                if (writeFile(localFile, remoteContent)) {
                    result.downloaded++;
                }

                result.conflicts++;
            }
        }
    }

    /**
     * Sync setlists.
     */
    private void syncSetlists(SyncResult result) {
        File freeSongDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        File localSetlistFile = new File(freeSongDir, "setlists-backup.json");

        // Get remote setlists file
        GitHubApiClient.GitHubFile remoteFile = api.getFile(SETLISTS_FILE);
        String remoteContent = null;
        if (remoteFile != null) {
            remoteContent = api.getFileContent(SETLISTS_FILE);
        }

        // Get local setlists
        String localContent = null;
        if (localSetlistFile.exists()) {
            localContent = readFile(localSetlistFile);
        }

        // If only remote exists, download
        if (remoteContent != null && localContent == null) {
            progress("Downloading setlists...");
            if (writeFile(localSetlistFile, remoteContent)) {
                result.downloaded++;
                result.messages.add("Downloaded setlists from GitHub");
            }
            return;
        }

        // If only local exists, upload
        if (localContent != null && remoteContent == null) {
            progress("Uploading setlists...");
            GitHubApiClient.ApiResponse response = api.createOrUpdateFile(
                SETLISTS_FILE,
                localContent,
                null,
                "Add setlists"
            );
            if (response.success) {
                result.uploaded++;
                result.messages.add("Uploaded setlists to GitHub");
            } else {
                result.errors++;
                result.messages.add("Failed to upload setlists: " + response.errorMessage);
            }
            return;
        }

        // Both exist - check for changes
        if (localContent != null && remoteContent != null) {
            String localHash = md5(localContent);
            String remoteHash = md5(remoteContent);

            if (!localHash.equals(remoteHash)) {
                // Conflict - merge based on timestamp
                try {
                    JSONObject localJson = new JSONObject(localContent);
                    JSONObject remoteJson = new JSONObject(remoteContent);

                    long localTime = localJson.optLong("exportTime", 0);
                    long remoteTime = remoteJson.optLong("exportTime", 0);

                    if (localTime > remoteTime) {
                        // Local is newer - upload
                        progress("Uploading newer setlists...");
                        GitHubApiClient.ApiResponse response = api.createOrUpdateFile(
                            SETLISTS_FILE,
                            localContent,
                            remoteFile.sha,
                            "Update setlists"
                        );
                        if (response.success) {
                            result.uploaded++;
                            result.messages.add("Uploaded updated setlists");
                        } else {
                            result.errors++;
                            result.messages.add("Failed to upload setlists: " + response.errorMessage);
                        }
                    } else {
                        // Remote is newer - download (save local as backup)
                        progress("Downloading newer setlists...");
                        File conflictFile = new File(freeSongDir, "setlists-backup_conflict.json");
                        writeFile(conflictFile, localContent);

                        if (writeFile(localSetlistFile, remoteContent)) {
                            result.downloaded++;
                            result.conflicts++;
                            result.messages.add("Downloaded newer setlists (local backup saved)");
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error comparing setlists", e);
                    result.errors++;
                    result.messages.add("Failed to compare setlists: " + e.getMessage());
                }
            }
        }
    }

    /**
     * Generate a conflict filename.
     */
    private String getConflictName(String original) {
        int dotIndex = original.lastIndexOf('.');
        if (dotIndex > 0) {
            return original.substring(0, dotIndex) + "_conflict" + original.substring(dotIndex);
        }
        return original + "_conflict";
    }

    /**
     * Read file content as string.
     */
    private String readFile(File file) {
        try {
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(new FileInputStream(file), "UTF-8"));
            StringBuilder content = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            reader.close();
            return content.toString();
        } catch (Exception e) {
            Log.e(TAG, "Failed to read file: " + file.getName(), e);
            return null;
        }
    }

    /**
     * Write content to file.
     */
    private boolean writeFile(File file, String content) {
        try {
            BufferedWriter writer = new BufferedWriter(
                new OutputStreamWriter(new FileOutputStream(file), "UTF-8"));
            writer.write(content);
            writer.close();
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to write file: " + file.getName(), e);
            return false;
        }
    }

    /**
     * Calculate MD5 hash of string.
     */
    private String md5(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] digest = md.digest(input.getBytes("UTF-8"));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            return String.valueOf(input.hashCode());
        }
    }

    /**
     * Report progress to callback.
     */
    private void progress(String message) {
        Log.d(TAG, message);
        if (callback != null) {
            callback.onProgress(message);
        }
    }
}

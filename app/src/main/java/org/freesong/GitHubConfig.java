package org.freesong;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Configuration manager for GitHub sync settings.
 * Stores token, repository, and sync state in SharedPreferences.
 */
public class GitHubConfig {

    private static final String PREFS_NAME = "FreeSongPrefs";
    private static final String KEY_TOKEN = "github_token";
    private static final String KEY_REPO = "github_repo";
    private static final String KEY_LAST_SYNC = "github_last_sync";

    /**
     * Get the GitHub Personal Access Token.
     */
    public static String getToken(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_TOKEN, "");
    }

    /**
     * Set the GitHub Personal Access Token.
     */
    public static void setToken(Context ctx, String token) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putString(KEY_TOKEN, token).apply();
    }

    /**
     * Get the GitHub repository in "owner/repo" format.
     */
    public static String getRepo(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_REPO, "");
    }

    /**
     * Set the GitHub repository in "owner/repo" format.
     */
    public static void setRepo(Context ctx, String repo) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putString(KEY_REPO, repo).apply();
    }

    /**
     * Get the timestamp of the last successful sync.
     */
    public static long getLastSync(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getLong(KEY_LAST_SYNC, 0);
    }

    /**
     * Set the timestamp of the last successful sync.
     */
    public static void setLastSync(Context ctx, long timestamp) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putLong(KEY_LAST_SYNC, timestamp).apply();
    }

    /**
     * Check if GitHub sync is configured (has token and repo).
     */
    public static boolean isConfigured(Context ctx) {
        String token = getToken(ctx);
        String repo = getRepo(ctx);
        return token != null && !token.isEmpty() && repo != null && !repo.isEmpty();
    }

    /**
     * Clear all GitHub configuration.
     */
    public static void clearConfig(Context ctx) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit()
            .remove(KEY_TOKEN)
            .remove(KEY_REPO)
            .remove(KEY_LAST_SYNC)
            .apply();
    }
}

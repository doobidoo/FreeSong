package org.freesong;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.io.File;
import java.util.HashSet;
import java.util.Set;

/**
 * SQLite cache for song metadata (title, artist).
 * Speeds up app startup by avoiding re-parsing unchanged song files.
 */
public class SongMetadataCache extends SQLiteOpenHelper {

    private static final String DB_NAME = "song_metadata.db";
    private static final int DB_VERSION = 1;

    private static final String TABLE_NAME = "metadata";
    private static final String COL_PATH = "path";
    private static final String COL_TITLE = "title";
    private static final String COL_ARTIST = "artist";
    private static final String COL_LAST_MODIFIED = "last_modified";

    private static SongMetadataCache instance;

    public static synchronized SongMetadataCache getInstance(Context context) {
        if (instance == null) {
            instance = new SongMetadataCache(context.getApplicationContext());
        }
        return instance;
    }

    private SongMetadataCache(Context context) {
        super(context, DB_NAME, null, DB_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + TABLE_NAME + " (" +
            COL_PATH + " TEXT PRIMARY KEY, " +
            COL_TITLE + " TEXT, " +
            COL_ARTIST + " TEXT, " +
            COL_LAST_MODIFIED + " INTEGER)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL("DROP TABLE IF EXISTS " + TABLE_NAME);
        onCreate(db);
    }

    /**
     * Result of a cache lookup.
     */
    public static class CachedMetadata {
        public final String title;
        public final String artist;
        public final long lastModified;

        public CachedMetadata(String title, String artist, long lastModified) {
            this.title = title;
            this.artist = artist;
            this.lastModified = lastModified;
        }
    }

    /**
     * Get cached metadata for a file.
     * Returns null if not cached or if file has been modified since caching.
     */
    public CachedMetadata getCached(File file) {
        String path = file.getAbsolutePath();
        long fileModified = file.lastModified();

        SQLiteDatabase db = getReadableDatabase();
        Cursor cursor = db.query(TABLE_NAME,
            new String[]{COL_TITLE, COL_ARTIST, COL_LAST_MODIFIED},
            COL_PATH + " = ?",
            new String[]{path},
            null, null, null);

        try {
            if (cursor.moveToFirst()) {
                long cachedModified = cursor.getLong(2);
                // Only return cached data if file hasn't changed
                if (cachedModified == fileModified) {
                    return new CachedMetadata(
                        cursor.getString(0),
                        cursor.getString(1),
                        cachedModified
                    );
                }
            }
        } finally {
            cursor.close();
        }

        return null;
    }

    /**
     * Cache metadata for a file.
     */
    public void cache(File file, String title, String artist) {
        String path = file.getAbsolutePath();
        long lastModified = file.lastModified();

        ContentValues values = new ContentValues();
        values.put(COL_PATH, path);
        values.put(COL_TITLE, title);
        values.put(COL_ARTIST, artist);
        values.put(COL_LAST_MODIFIED, lastModified);

        SQLiteDatabase db = getWritableDatabase();
        db.insertWithOnConflict(TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    /**
     * Remove stale cache entries for files that no longer exist.
     */
    public void removeStaleEntries(Set<String> validPaths) {
        SQLiteDatabase db = getWritableDatabase();
        Cursor cursor = db.query(TABLE_NAME, new String[]{COL_PATH}, null, null, null, null, null);

        Set<String> toDelete = new HashSet<String>();
        try {
            while (cursor.moveToNext()) {
                String path = cursor.getString(0);
                if (!validPaths.contains(path)) {
                    toDelete.add(path);
                }
            }
        } finally {
            cursor.close();
        }

        for (String path : toDelete) {
            db.delete(TABLE_NAME, COL_PATH + " = ?", new String[]{path});
        }
    }

    /**
     * Get the number of cached entries.
     */
    public int getCacheSize() {
        SQLiteDatabase db = getReadableDatabase();
        Cursor cursor = db.rawQuery("SELECT COUNT(*) FROM " + TABLE_NAME, null);
        try {
            if (cursor.moveToFirst()) {
                return cursor.getInt(0);
            }
        } finally {
            cursor.close();
        }
        return 0;
    }
}

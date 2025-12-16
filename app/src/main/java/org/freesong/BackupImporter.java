package org.freesong;

import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Environment;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Imports songs from OnSong backup files (.backup, .zip).
 */
public class BackupImporter {

    private static final int BUFFER_SIZE = 4096;

    public static class ImportResult {
        public int totalFiles = 0;
        public int importedFiles = 0;
        public int skippedFiles = 0;
        public List<String> importedNames = new ArrayList<String>();
        public List<String> errors = new ArrayList<String>();
    }

    /**
     * Import songs from a backup file (ZIP format).
     * Supports both loose song files and OnSong SQLite database.
     */
    public static ImportResult importBackup(File backupFile) throws IOException {
        ImportResult result = new ImportResult();

        File destDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!destDir.exists()) {
            destDir.mkdirs();
        }

        // Temporary file for SQLite database extraction
        File tempDbFile = null;

        ZipInputStream zis = null;
        try {
            zis = new ZipInputStream(new BufferedInputStream(new FileInputStream(backupFile)));
            ZipEntry entry;

            while ((entry = zis.getNextEntry()) != null) {
                String name = entry.getName();

                // Skip directories
                if (entry.isDirectory()) {
                    continue;
                }

                // Check for OnSong SQLite database
                if (name.equals("OnSong.sqlite3") || name.endsWith("/OnSong.sqlite3")) {
                    tempDbFile = new File(destDir, ".onsong_temp.sqlite3");
                    extractBinaryFile(zis, tempDbFile);
                    zis.closeEntry();
                    continue;
                }

                // Check if it's a song file
                String lowerName = name.toLowerCase();
                if (!isSongFile(lowerName)) {
                    continue;
                }

                result.totalFiles++;

                // Extract just the filename (remove path)
                String fileName = name;
                int lastSlash = name.lastIndexOf('/');
                if (lastSlash >= 0) {
                    fileName = name.substring(lastSlash + 1);
                }

                // Skip hidden files
                if (fileName.startsWith(".")) {
                    result.skippedFiles++;
                    continue;
                }

                File destFile = new File(destDir, fileName);

                // Skip if file already exists
                if (destFile.exists()) {
                    result.skippedFiles++;
                    continue;
                }

                try {
                    extractFile(zis, destFile);
                    result.importedFiles++;
                    result.importedNames.add(getDisplayName(fileName));
                } catch (IOException e) {
                    result.errors.add(fileName + ": " + e.getMessage());
                }

                zis.closeEntry();
            }
        } finally {
            if (zis != null) {
                try {
                    zis.close();
                } catch (IOException e) {
                    // Ignore
                }
            }
        }

        // Import songs from SQLite database if found
        if (tempDbFile != null && tempDbFile.exists()) {
            try {
                importFromSqliteDatabase(tempDbFile, destDir, result);
            } catch (Exception e) {
                result.errors.add("Database import: " + e.getMessage());
            } finally {
                // Clean up temporary database file
                tempDbFile.delete();
            }
        }

        return result;
    }

    /**
     * Import songs from OnSong SQLite database.
     */
    private static void importFromSqliteDatabase(File dbFile, File destDir, ImportResult result) {
        SQLiteDatabase db = null;
        Cursor cursor = null;
        try {
            db = SQLiteDatabase.openDatabase(dbFile.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY);

            // Query songs with content
            cursor = db.rawQuery(
                "SELECT title, byline, key, content FROM Song WHERE content IS NOT NULL AND content != ''",
                null
            );

            while (cursor.moveToNext()) {
                String title = cursor.getString(0);
                String artist = cursor.getString(1);
                String key = cursor.getString(2);
                String content = cursor.getString(3);

                // Skip if no title or content
                if (title == null || title.trim().isEmpty() ||
                    content == null || content.trim().isEmpty()) {
                    continue;
                }

                result.totalFiles++;

                // Create safe filename from title
                String safeTitle = sanitizeFileName(title);
                if (safeTitle.isEmpty()) {
                    safeTitle = "Untitled_" + System.currentTimeMillis();
                }

                // Add key to filename if available
                String fileName = safeTitle;
                if (key != null && !key.trim().isEmpty()) {
                    fileName = safeTitle + "-" + key.trim();
                }
                fileName = fileName + ".onsong";

                File destFile = new File(destDir, fileName);

                // Skip if file already exists
                if (destFile.exists()) {
                    result.skippedFiles++;
                    continue;
                }

                try {
                    // Write song content to file
                    writeSongFile(destFile, content);
                    result.importedFiles++;
                    result.importedNames.add(title);
                } catch (IOException e) {
                    result.errors.add(title + ": " + e.getMessage());
                }
            }
        } catch (Exception e) {
            result.errors.add("Failed to read database: " + e.getMessage());
        } finally {
            if (cursor != null) {
                cursor.close();
            }
            if (db != null) {
                db.close();
            }
        }
    }

    /**
     * Create a safe filename from song title.
     */
    private static String sanitizeFileName(String name) {
        if (name == null) return "";
        // Remove or replace invalid filename characters
        String safe = name.replaceAll("[\\\\/:*?\"<>|]", "_");
        // Remove leading/trailing spaces and dots
        safe = safe.trim();
        while (safe.endsWith(".")) {
            safe = safe.substring(0, safe.length() - 1);
        }
        // Limit length
        if (safe.length() > 100) {
            safe = safe.substring(0, 100);
        }
        return safe;
    }

    /**
     * Write song content to file as UTF-8.
     */
    private static void writeSongFile(File destFile, String content) throws IOException {
        BufferedWriter writer = null;
        try {
            writer = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(destFile), UTF8));
            writer.write(content);
            writer.flush();
        } finally {
            if (writer != null) {
                writer.close();
            }
        }
    }

    /**
     * Import a single song file by copying it to FreeSong folder.
     */
    public static boolean importSingleFile(File sourceFile) throws IOException {
        if (!isSongFile(sourceFile.getName().toLowerCase())) {
            return false;
        }

        File destDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!destDir.exists()) {
            destDir.mkdirs();
        }

        File destFile = new File(destDir, sourceFile.getName());
        if (destFile.exists()) {
            return false; // Already exists
        }

        copyFile(sourceFile, destFile);
        return true;
    }

    private static boolean isSongFile(String lowerName) {
        return lowerName.endsWith(".onsong") ||
               lowerName.endsWith(".chordpro") ||
               lowerName.endsWith(".cho") ||
               lowerName.endsWith(".crd") ||
               lowerName.endsWith(".pro") ||
               lowerName.endsWith(".txt");
    }

    // Mac Roman charset for OnSong files
    private static final Charset MAC_ROMAN = Charset.forName("x-MacRoman");
    private static final Charset UTF8 = Charset.forName("UTF-8");

    private static void extractFile(ZipInputStream zis, File destFile) throws IOException {
        // For text files, convert from Mac Roman to UTF-8
        String name = destFile.getName().toLowerCase();
        if (name.endsWith(".txt") || name.endsWith(".onsong") ||
            name.endsWith(".chordpro") || name.endsWith(".cho") ||
            name.endsWith(".crd") || name.endsWith(".pro")) {
            extractTextFile(zis, destFile);
        } else {
            extractBinaryFile(zis, destFile);
        }
    }

    private static void extractTextFile(ZipInputStream zis, File destFile) throws IOException {
        BufferedReader reader = null;
        BufferedWriter writer = null;
        try {
            reader = new BufferedReader(new InputStreamReader(zis, MAC_ROMAN));
            writer = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(destFile), UTF8));

            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (!first) {
                    writer.newLine();
                }
                writer.write(line);
                first = false;
            }
            writer.flush();
        } finally {
            if (writer != null) {
                writer.close();
            }
            // Don't close reader as it wraps the ZipInputStream
        }
    }

    private static void extractBinaryFile(ZipInputStream zis, File destFile) throws IOException {
        BufferedOutputStream bos = null;
        try {
            bos = new BufferedOutputStream(new FileOutputStream(destFile), BUFFER_SIZE);
            byte[] buffer = new byte[BUFFER_SIZE];
            int count;
            while ((count = zis.read(buffer, 0, BUFFER_SIZE)) != -1) {
                bos.write(buffer, 0, count);
            }
            bos.flush();
        } finally {
            if (bos != null) {
                bos.close();
            }
        }
    }

    private static void copyFile(File source, File dest) throws IOException {
        InputStream is = null;
        BufferedOutputStream bos = null;
        try {
            is = new BufferedInputStream(new FileInputStream(source));
            bos = new BufferedOutputStream(new FileOutputStream(dest), BUFFER_SIZE);
            byte[] buffer = new byte[BUFFER_SIZE];
            int count;
            while ((count = is.read(buffer)) != -1) {
                bos.write(buffer, 0, count);
            }
            bos.flush();
        } finally {
            if (is != null) {
                try { is.close(); } catch (IOException e) { }
            }
            if (bos != null) {
                try { bos.close(); } catch (IOException e) { }
            }
        }
    }

    private static String getDisplayName(String fileName) {
        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
            return fileName.substring(0, dotIndex);
        }
        return fileName;
    }

    /**
     * Check if a file looks like an OnSong backup.
     */
    public static boolean isBackupFile(String fileName) {
        String lower = fileName.toLowerCase();
        return lower.endsWith(".backup") ||
               lower.endsWith(".zip") ||
               lower.endsWith(".onsong-backup");
    }
}

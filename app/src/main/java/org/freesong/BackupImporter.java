package org.freesong;

import android.content.Context;
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
        public int skippedBinary = 0;
        public int importedSetlists = 0;
        public int skippedSetlists = 0;
        public List<String> importedNames = new ArrayList<String>();
        public List<String> importedSetlistNames = new ArrayList<String>();
        public List<String> warnings = new ArrayList<String>();
        public List<String> errors = new ArrayList<String>();
    }

    public static class ImportSingleResult {
        public boolean success = false;
        public String message = "";
    }

    /**
     * Import songs from a backup file (ZIP format).
     * Supports both loose song files and OnSong SQLite database.
     */
    public static ImportResult importBackup(File backupFile) throws IOException {
        return importBackup(backupFile, null);
    }

    /**
     * Import songs and optionally setlists from a backup file.
     * @param backupFile The backup file to import
     * @param context Context for setlist import (pass null to skip setlist import)
     */
    public static ImportResult importBackup(File backupFile, Context context) throws IOException {
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
                    extractFile(zis, destFile, result);
                    // Check if file was actually created (not skipped binary)
                    if (destFile.exists()) {
                        result.importedFiles++;
                        result.importedNames.add(getDisplayName(fileName));
                    }
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
                // Import setlists if context provided
                if (context != null) {
                    importSetlistsFromDatabase(tempDbFile, destDir, context, result);
                }
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
     * Import setlists from OnSong SQLite database.
     */
    private static void importSetlistsFromDatabase(File dbFile, File songsDir, Context context, ImportResult result) {
        SQLiteDatabase db = null;
        Cursor setlistCursor = null;
        try {
            db = SQLiteDatabase.openDatabase(dbFile.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY);
            SetListDbHelper dbHelper = SetListDbHelper.getInstance(context);

            // Get existing setlist names to avoid duplicates
            List<SetList> existingSetlists = dbHelper.getAllSetLists();
            List<String> existingNames = new ArrayList<String>();
            for (SetList sl : existingSetlists) {
                existingNames.add(sl.getName().toLowerCase());
            }

            // Query all setlists
            setlistCursor = db.rawQuery(
                "SELECT ID, title FROM SongSet WHERE title IS NOT NULL AND title != '' ORDER BY title",
                null
            );

            while (setlistCursor.moveToNext()) {
                String setlistId = setlistCursor.getString(0);
                String setlistTitle = setlistCursor.getString(1);

                if (setlistTitle == null || setlistTitle.trim().isEmpty()) {
                    continue;
                }

                // Skip if setlist already exists
                if (existingNames.contains(setlistTitle.toLowerCase().trim())) {
                    result.skippedSetlists++;
                    continue;
                }

                // Get songs in this setlist
                Cursor itemsCursor = null;
                try {
                    itemsCursor = db.rawQuery(
                        "SELECT s.title, s.key, s.byline FROM SongSetItem ssi " +
                        "JOIN Song s ON ssi.songID = s.ID " +
                        "WHERE ssi.setID = ? ORDER BY ssi.orderIndex",
                        new String[]{setlistId}
                    );

                    if (itemsCursor.getCount() == 0) {
                        continue; // Empty setlist
                    }

                    // Create the setlist
                    SetList newSetList = new SetList(setlistTitle.trim());
                    long newSetlistId = dbHelper.createSetList(newSetList);
                    int songsAdded = 0;

                    while (itemsCursor.moveToNext()) {
                        String songTitle = itemsCursor.getString(0);
                        String songKey = itemsCursor.getString(1);
                        String songArtist = itemsCursor.getString(2);

                        if (songTitle == null || songTitle.trim().isEmpty()) {
                            continue;
                        }

                        // Try to find matching song file
                        File songFile = findSongFile(songsDir, songTitle, songKey);
                        if (songFile != null) {
                            SetList.SetListItem item = new SetList.SetListItem(
                                songFile.getAbsolutePath(),
                                songTitle,
                                songArtist != null ? songArtist : ""
                            );
                            dbHelper.addItemToSetList(newSetlistId, item);
                            songsAdded++;
                        }
                    }

                    if (songsAdded > 0) {
                        result.importedSetlists++;
                        result.importedSetlistNames.add(setlistTitle + " (" + songsAdded + " songs)");
                    } else {
                        // Remove empty setlist
                        dbHelper.deleteSetList(newSetlistId);
                    }

                } finally {
                    if (itemsCursor != null) {
                        itemsCursor.close();
                    }
                }
            }
        } catch (Exception e) {
            result.errors.add("Setlist import: " + e.getMessage());
        } finally {
            if (setlistCursor != null) {
                setlistCursor.close();
            }
            if (db != null) {
                db.close();
            }
        }
    }

    /**
     * Find a song file by title and optional key.
     */
    private static File findSongFile(File songsDir, String title, String key) {
        if (!songsDir.exists()) return null;

        String safeTitle = sanitizeFileName(title);

        // Try different filename patterns
        String[] patterns;
        if (key != null && !key.trim().isEmpty()) {
            patterns = new String[]{
                safeTitle + "-" + key.trim() + ".onsong",
                safeTitle + ".onsong",
                safeTitle + "-" + key.trim() + ".txt",
                safeTitle + ".txt",
                safeTitle + ".chordpro",
                safeTitle + ".cho"
            };
        } else {
            patterns = new String[]{
                safeTitle + ".onsong",
                safeTitle + ".txt",
                safeTitle + ".chordpro",
                safeTitle + ".cho"
            };
        }

        for (String pattern : patterns) {
            File file = new File(songsDir, pattern);
            if (file.exists()) {
                return file;
            }
        }

        // Try case-insensitive search
        File[] files = songsDir.listFiles();
        if (files != null) {
            String lowerTitle = safeTitle.toLowerCase();
            for (File file : files) {
                String name = file.getName().toLowerCase();
                if (name.startsWith(lowerTitle) && isSongFile(name)) {
                    return file;
                }
            }
        }

        return null;
    }

    /**
     * Import a single song file by copying it to FreeSong folder.
     */
    public static ImportSingleResult importSingleFile(File sourceFile) throws IOException {
        ImportSingleResult result = new ImportSingleResult();

        if (!isSongFile(sourceFile.getName().toLowerCase())) {
            result.success = false;
            result.message = "Not a song file";
            return result;
        }

        // Check for binary content
        byte[] header = new byte[1024];
        FileInputStream fis = null;
        try {
            fis = new FileInputStream(sourceFile);
            int read = fis.read(header);
            if (read > 0) {
                byte[] checkBytes = read < header.length ? java.util.Arrays.copyOf(header, read) : header;
                String binaryType = detectBinaryContent(checkBytes);
                if (binaryType != null) {
                    result.success = false;
                    result.message = "Cannot import " + binaryType;
                    return result;
                }
            }
        } finally {
            if (fis != null) {
                try { fis.close(); } catch (IOException e) { }
            }
        }

        File destDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!destDir.exists()) {
            destDir.mkdirs();
        }

        File destFile = new File(destDir, sourceFile.getName());
        if (destFile.exists()) {
            result.success = false;
            result.message = "File already exists";
            return result;
        }

        copyFile(sourceFile, destFile);
        result.success = true;
        result.message = "Imported successfully";
        return result;
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

    /**
     * Check if content appears to be binary (PDF, image, etc).
     * Returns a description of detected binary type, or null if text.
     */
    private static String detectBinaryContent(byte[] content) {
        if (content == null || content.length < 8) {
            return null;
        }

        // PDF: starts with %PDF
        if (content[0] == '%' && content[1] == 'P' &&
            content[2] == 'D' && content[3] == 'F') {
            return "PDF document";
        }

        // PNG: starts with 0x89 PNG
        if ((content[0] & 0xFF) == 0x89 && content[1] == 'P' &&
            content[2] == 'N' && content[3] == 'G') {
            return "PNG image";
        }

        // JPEG: starts with 0xFF 0xD8 0xFF
        if ((content[0] & 0xFF) == 0xFF && (content[1] & 0xFF) == 0xD8 &&
            (content[2] & 0xFF) == 0xFF) {
            return "JPEG image";
        }

        // GIF: starts with GIF87a or GIF89a
        if (content[0] == 'G' && content[1] == 'I' && content[2] == 'F' &&
            content[3] == '8' && (content[4] == '7' || content[4] == '9')) {
            return "GIF image";
        }

        // BMP: starts with BM
        if (content[0] == 'B' && content[1] == 'M') {
            return "BMP image";
        }

        // Check for high proportion of non-printable characters (binary indicator)
        int nonPrintable = 0;
        int checkLength = Math.min(content.length, 1024);
        for (int i = 0; i < checkLength; i++) {
            byte b = content[i];
            // Allow printable ASCII, tabs, newlines, and high UTF-8 bytes
            if (b != 0x09 && b != 0x0A && b != 0x0D &&
                (b < 0x20 || b == 0x7F) && b >= 0) {
                nonPrintable++;
            }
        }

        // If more than 10% non-printable in first 1KB, likely binary
        if (nonPrintable > checkLength / 10) {
            return "binary file";
        }

        return null; // Appears to be text
    }

    private static void extractFile(ZipInputStream zis, File destFile, ImportResult result) throws IOException {
        // For text files, convert from Mac Roman to UTF-8
        String name = destFile.getName().toLowerCase();
        if (name.endsWith(".txt") || name.endsWith(".onsong") ||
            name.endsWith(".chordpro") || name.endsWith(".cho") ||
            name.endsWith(".crd") || name.endsWith(".pro")) {
            extractTextFile(zis, destFile, result);
        } else {
            extractBinaryFile(zis, destFile);
        }
    }

    private static void extractTextFile(ZipInputStream zis, File destFile, ImportResult result) throws IOException {
        // First, read raw bytes to check for binary content
        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
        byte[] buffer = new byte[BUFFER_SIZE];
        int count;
        while ((count = zis.read(buffer, 0, BUFFER_SIZE)) != -1) {
            baos.write(buffer, 0, count);
        }
        byte[] rawBytes = baos.toByteArray();

        // Check for binary content
        String binaryType = detectBinaryContent(rawBytes);
        if (binaryType != null) {
            result.skippedBinary++;
            result.warnings.add(destFile.getName() + ": Skipped (" + binaryType + ")");
            return;
        }

        // Convert from Mac Roman to UTF-8 and write
        BufferedWriter writer = null;
        try {
            String content = new String(rawBytes, MAC_ROMAN);
            writer = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(destFile), UTF8));
            writer.write(content);
            writer.flush();
        } finally {
            if (writer != null) {
                writer.close();
            }
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

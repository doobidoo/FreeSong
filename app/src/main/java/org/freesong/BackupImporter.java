package org.freesong;

import android.os.Environment;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
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
     */
    public static ImportResult importBackup(File backupFile) throws IOException {
        ImportResult result = new ImportResult();

        File destDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!destDir.exists()) {
            destDir.mkdirs();
        }

        ZipInputStream zis = null;
        try {
            zis = new ZipInputStream(new BufferedInputStream(new FileInputStream(backupFile)));
            ZipEntry entry;

            while ((entry = zis.getNextEntry()) != null) {
                String name = entry.getName();

                // Skip directories and non-song files
                if (entry.isDirectory()) {
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

        return result;
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

    private static void extractFile(ZipInputStream zis, File destFile) throws IOException {
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

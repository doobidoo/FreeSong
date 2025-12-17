package org.freesong;

import android.content.Context;
import android.os.Environment;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.List;

/**
 * Manages setlist backup and restore to/from JSON file.
 * Backup file is stored in FreeSong folder to survive app uninstallation.
 */
public class SetlistBackupManager {

    private static final String BACKUP_FILENAME = "setlists-backup.json";
    private static final String CHARSET = "UTF-8";

    /**
     * Get the backup file location.
     */
    public static File getBackupFile() {
        File freeSongDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!freeSongDir.exists()) {
            freeSongDir.mkdirs();
        }
        return new File(freeSongDir, BACKUP_FILENAME);
    }

    /**
     * Export all setlists to JSON backup file.
     * @return true if successful
     */
    public static boolean exportSetlists(Context context) {
        try {
            SetListDbHelper dbHelper = SetListDbHelper.getInstance(context);
            List<SetList> setlists = dbHelper.getAllSetLists();

            JSONObject backup = new JSONObject();
            backup.put("version", 1);
            backup.put("exported_at", System.currentTimeMillis());

            JSONArray setlistsArray = new JSONArray();
            for (SetList setlist : setlists) {
                JSONObject setlistObj = new JSONObject();
                setlistObj.put("name", setlist.getName());
                setlistObj.put("created_at", setlist.getCreatedAt());
                setlistObj.put("modified_at", setlist.getModifiedAt());

                JSONArray itemsArray = new JSONArray();
                for (SetList.SetListItem item : setlist.getItems()) {
                    JSONObject itemObj = new JSONObject();
                    itemObj.put("song_path", item.getSongPath());
                    itemObj.put("song_title", item.getSongTitle());
                    itemObj.put("song_artist", item.getSongArtist());
                    itemObj.put("position", item.getPosition());
                    itemObj.put("notes", item.getNotes());
                    itemsArray.put(itemObj);
                }
                setlistObj.put("items", itemsArray);
                setlistsArray.put(setlistObj);
            }
            backup.put("setlists", setlistsArray);

            // Write to file
            File backupFile = getBackupFile();
            BufferedWriter writer = new BufferedWriter(
                new OutputStreamWriter(new FileOutputStream(backupFile), CHARSET));
            writer.write(backup.toString(2)); // Pretty print with indent
            writer.close();

            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Import setlists from JSON backup file.
     * @param merge If true, merge with existing setlists. If false, only import non-existing.
     * @return Number of setlists imported, or -1 on error
     */
    public static int importSetlists(Context context, boolean merge) {
        try {
            File backupFile = getBackupFile();
            if (!backupFile.exists()) {
                return 0;
            }

            // Read file
            StringBuilder content = new StringBuilder();
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(new FileInputStream(backupFile), CHARSET));
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line);
            }
            reader.close();

            JSONObject backup = new JSONObject(content.toString());
            JSONArray setlistsArray = backup.getJSONArray("setlists");

            SetListDbHelper dbHelper = SetListDbHelper.getInstance(context);
            List<SetList> existingSetlists = dbHelper.getAllSetLists();

            int imported = 0;
            for (int i = 0; i < setlistsArray.length(); i++) {
                JSONObject setlistObj = setlistsArray.getJSONObject(i);
                String name = setlistObj.getString("name");

                // Check if setlist already exists
                boolean exists = false;
                for (SetList existing : existingSetlists) {
                    if (existing.getName().equalsIgnoreCase(name)) {
                        exists = true;
                        break;
                    }
                }

                if (exists && !merge) {
                    continue; // Skip existing
                }

                if (exists) {
                    // Delete existing to replace with backup
                    for (SetList existing : existingSetlists) {
                        if (existing.getName().equalsIgnoreCase(name)) {
                            dbHelper.deleteSetList(existing.getId());
                            break;
                        }
                    }
                }

                // Create setlist
                SetList setlist = new SetList(name);
                if (setlistObj.has("created_at")) {
                    setlist.setCreatedAt(setlistObj.getLong("created_at"));
                }
                if (setlistObj.has("modified_at")) {
                    setlist.setModifiedAt(setlistObj.getLong("modified_at"));
                }

                long setlistId = dbHelper.createSetList(setlist);

                // Add items
                JSONArray itemsArray = setlistObj.getJSONArray("items");
                for (int j = 0; j < itemsArray.length(); j++) {
                    JSONObject itemObj = itemsArray.getJSONObject(j);
                    SetList.SetListItem item = new SetList.SetListItem(
                        itemObj.getString("song_path"),
                        itemObj.optString("song_title", ""),
                        itemObj.optString("song_artist", "")
                    );
                    if (itemObj.has("notes")) {
                        item.setNotes(itemObj.getString("notes"));
                    }
                    dbHelper.addItemToSetList(setlistId, item);
                }

                imported++;
            }

            return imported;
        } catch (Exception e) {
            e.printStackTrace();
            return -1;
        }
    }

    /**
     * Check if a backup file exists.
     */
    public static boolean backupExists() {
        return getBackupFile().exists();
    }

    /**
     * Get backup file info for display.
     */
    public static String getBackupInfo() {
        File backupFile = getBackupFile();
        if (!backupFile.exists()) {
            return null;
        }

        try {
            StringBuilder content = new StringBuilder();
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(new FileInputStream(backupFile), CHARSET));
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line);
            }
            reader.close();

            JSONObject backup = new JSONObject(content.toString());
            int count = backup.getJSONArray("setlists").length();
            long exportedAt = backup.optLong("exported_at", 0);

            String date = "";
            if (exportedAt > 0) {
                java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm");
                date = sdf.format(new java.util.Date(exportedAt));
            }

            return count + " setlists (" + date + ")";
        } catch (Exception e) {
            return "Unknown";
        }
    }
}

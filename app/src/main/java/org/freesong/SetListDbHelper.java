package org.freesong;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.util.ArrayList;
import java.util.List;

/**
 * SQLite database helper for setlist persistence.
 */
public class SetListDbHelper extends SQLiteOpenHelper {

    private static final String DATABASE_NAME = "freesong.db";
    private static final int DATABASE_VERSION = 1;

    // Table names
    private static final String TABLE_SETLISTS = "setlists";
    private static final String TABLE_SETLIST_ITEMS = "setlist_items";

    // SetList columns
    private static final String COL_ID = "_id";
    private static final String COL_NAME = "name";
    private static final String COL_CREATED_AT = "created_at";
    private static final String COL_MODIFIED_AT = "modified_at";

    // SetListItem columns
    private static final String COL_SETLIST_ID = "setlist_id";
    private static final String COL_SONG_PATH = "song_path";
    private static final String COL_SONG_TITLE = "song_title";
    private static final String COL_SONG_ARTIST = "song_artist";
    private static final String COL_POSITION = "position";
    private static final String COL_NOTES = "notes";

    private static SetListDbHelper instance;

    public static synchronized SetListDbHelper getInstance(Context context) {
        if (instance == null) {
            instance = new SetListDbHelper(context.getApplicationContext());
        }
        return instance;
    }

    private SetListDbHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        String createSetLists = "CREATE TABLE " + TABLE_SETLISTS + " (" +
            COL_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
            COL_NAME + " TEXT NOT NULL, " +
            COL_CREATED_AT + " INTEGER, " +
            COL_MODIFIED_AT + " INTEGER)";

        String createSetListItems = "CREATE TABLE " + TABLE_SETLIST_ITEMS + " (" +
            COL_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
            COL_SETLIST_ID + " INTEGER NOT NULL, " +
            COL_SONG_PATH + " TEXT NOT NULL, " +
            COL_SONG_TITLE + " TEXT, " +
            COL_SONG_ARTIST + " TEXT, " +
            COL_POSITION + " INTEGER, " +
            COL_NOTES + " TEXT, " +
            "FOREIGN KEY(" + COL_SETLIST_ID + ") REFERENCES " + TABLE_SETLISTS + "(" + COL_ID + ") ON DELETE CASCADE)";

        db.execSQL(createSetLists);
        db.execSQL(createSetListItems);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL("DROP TABLE IF EXISTS " + TABLE_SETLIST_ITEMS);
        db.execSQL("DROP TABLE IF EXISTS " + TABLE_SETLISTS);
        onCreate(db);
    }

    @Override
    public void onOpen(SQLiteDatabase db) {
        super.onOpen(db);
        db.execSQL("PRAGMA foreign_keys=ON");
    }

    // --- SetList CRUD operations ---

    public long createSetList(SetList setList) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put(COL_NAME, setList.getName());
        values.put(COL_CREATED_AT, setList.getCreatedAt());
        values.put(COL_MODIFIED_AT, setList.getModifiedAt());

        long id = db.insert(TABLE_SETLISTS, null, values);
        setList.setId(id);
        return id;
    }

    public void updateSetList(SetList setList) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put(COL_NAME, setList.getName());
        values.put(COL_MODIFIED_AT, System.currentTimeMillis());

        db.update(TABLE_SETLISTS, values, COL_ID + " = ?",
            new String[]{String.valueOf(setList.getId())});
    }

    public void deleteSetList(long setListId) {
        SQLiteDatabase db = getWritableDatabase();
        db.delete(TABLE_SETLIST_ITEMS, COL_SETLIST_ID + " = ?",
            new String[]{String.valueOf(setListId)});
        db.delete(TABLE_SETLISTS, COL_ID + " = ?",
            new String[]{String.valueOf(setListId)});
    }

    public SetList getSetList(long id) {
        SQLiteDatabase db = getReadableDatabase();
        Cursor cursor = db.query(TABLE_SETLISTS, null, COL_ID + " = ?",
            new String[]{String.valueOf(id)}, null, null, null);

        SetList setList = null;
        if (cursor.moveToFirst()) {
            setList = cursorToSetList(cursor);
            setList.setItems(getSetListItems(id));
        }
        cursor.close();
        return setList;
    }

    public List<SetList> getAllSetLists() {
        List<SetList> setLists = new ArrayList<SetList>();
        SQLiteDatabase db = getReadableDatabase();
        Cursor cursor = db.query(TABLE_SETLISTS, null, null, null, null, null,
            COL_MODIFIED_AT + " DESC");

        while (cursor.moveToNext()) {
            SetList setList = cursorToSetList(cursor);
            setList.setItems(getSetListItems(setList.getId()));
            setLists.add(setList);
        }
        cursor.close();
        return setLists;
    }

    private SetList cursorToSetList(Cursor cursor) {
        SetList setList = new SetList();
        setList.setId(cursor.getLong(cursor.getColumnIndex(COL_ID)));
        setList.setName(cursor.getString(cursor.getColumnIndex(COL_NAME)));
        setList.setCreatedAt(cursor.getLong(cursor.getColumnIndex(COL_CREATED_AT)));
        setList.setModifiedAt(cursor.getLong(cursor.getColumnIndex(COL_MODIFIED_AT)));
        return setList;
    }

    // --- SetListItem CRUD operations ---

    public long addItemToSetList(long setListId, SetList.SetListItem item) {
        SQLiteDatabase db = getWritableDatabase();

        // Get next position
        Cursor cursor = db.rawQuery(
            "SELECT MAX(" + COL_POSITION + ") FROM " + TABLE_SETLIST_ITEMS +
            " WHERE " + COL_SETLIST_ID + " = ?",
            new String[]{String.valueOf(setListId)});

        int nextPosition = 0;
        if (cursor.moveToFirst()) {
            nextPosition = cursor.getInt(0) + 1;
        }
        cursor.close();

        ContentValues values = new ContentValues();
        values.put(COL_SETLIST_ID, setListId);
        values.put(COL_SONG_PATH, item.getSongPath());
        values.put(COL_SONG_TITLE, item.getSongTitle());
        values.put(COL_SONG_ARTIST, item.getSongArtist());
        values.put(COL_POSITION, nextPosition);
        values.put(COL_NOTES, item.getNotes());

        long id = db.insert(TABLE_SETLIST_ITEMS, null, values);
        item.setId(id);
        item.setSetListId(setListId);
        item.setPosition(nextPosition);

        // Update setlist modified time
        updateSetListModifiedTime(setListId);

        return id;
    }

    public void removeItemFromSetList(long itemId) {
        SQLiteDatabase db = getWritableDatabase();

        // Get setlist ID before deleting
        Cursor cursor = db.query(TABLE_SETLIST_ITEMS, new String[]{COL_SETLIST_ID},
            COL_ID + " = ?", new String[]{String.valueOf(itemId)}, null, null, null);

        long setListId = -1;
        if (cursor.moveToFirst()) {
            setListId = cursor.getLong(0);
        }
        cursor.close();

        db.delete(TABLE_SETLIST_ITEMS, COL_ID + " = ?",
            new String[]{String.valueOf(itemId)});

        if (setListId != -1) {
            reorderSetListItems(setListId);
            updateSetListModifiedTime(setListId);
        }
    }

    public void updateItemPosition(long itemId, int newPosition) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put(COL_POSITION, newPosition);
        db.update(TABLE_SETLIST_ITEMS, values, COL_ID + " = ?",
            new String[]{String.valueOf(itemId)});
    }

    public List<SetList.SetListItem> getSetListItems(long setListId) {
        List<SetList.SetListItem> items = new ArrayList<SetList.SetListItem>();
        SQLiteDatabase db = getReadableDatabase();
        Cursor cursor = db.query(TABLE_SETLIST_ITEMS, null,
            COL_SETLIST_ID + " = ?", new String[]{String.valueOf(setListId)},
            null, null, COL_POSITION + " ASC");

        while (cursor.moveToNext()) {
            items.add(cursorToSetListItem(cursor));
        }
        cursor.close();
        return items;
    }

    private SetList.SetListItem cursorToSetListItem(Cursor cursor) {
        SetList.SetListItem item = new SetList.SetListItem();
        item.setId(cursor.getLong(cursor.getColumnIndex(COL_ID)));
        item.setSetListId(cursor.getLong(cursor.getColumnIndex(COL_SETLIST_ID)));
        item.setSongPath(cursor.getString(cursor.getColumnIndex(COL_SONG_PATH)));
        item.setSongTitle(cursor.getString(cursor.getColumnIndex(COL_SONG_TITLE)));
        item.setSongArtist(cursor.getString(cursor.getColumnIndex(COL_SONG_ARTIST)));
        item.setPosition(cursor.getInt(cursor.getColumnIndex(COL_POSITION)));
        item.setNotes(cursor.getString(cursor.getColumnIndex(COL_NOTES)));
        return item;
    }

    private void reorderSetListItems(long setListId) {
        SQLiteDatabase db = getWritableDatabase();
        Cursor cursor = db.query(TABLE_SETLIST_ITEMS, new String[]{COL_ID},
            COL_SETLIST_ID + " = ?", new String[]{String.valueOf(setListId)},
            null, null, COL_POSITION + " ASC");

        int position = 0;
        while (cursor.moveToNext()) {
            ContentValues values = new ContentValues();
            values.put(COL_POSITION, position++);
            db.update(TABLE_SETLIST_ITEMS, values, COL_ID + " = ?",
                new String[]{String.valueOf(cursor.getLong(0))});
        }
        cursor.close();
    }

    private void updateSetListModifiedTime(long setListId) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put(COL_MODIFIED_AT, System.currentTimeMillis());
        db.update(TABLE_SETLISTS, values, COL_ID + " = ?",
            new String[]{String.valueOf(setListId)});
    }

    public void moveItemInSetList(long setListId, int fromPosition, int toPosition) {
        List<SetList.SetListItem> items = getSetListItems(setListId);
        if (fromPosition < 0 || fromPosition >= items.size() ||
            toPosition < 0 || toPosition >= items.size()) {
            return;
        }

        // Reorder in memory
        SetList.SetListItem item = items.remove(fromPosition);
        items.add(toPosition, item);

        // Update positions in database
        SQLiteDatabase db = getWritableDatabase();
        for (int i = 0; i < items.size(); i++) {
            ContentValues values = new ContentValues();
            values.put(COL_POSITION, i);
            db.update(TABLE_SETLIST_ITEMS, values, COL_ID + " = ?",
                new String[]{String.valueOf(items.get(i).getId())});
        }

        updateSetListModifiedTime(setListId);
    }

    /**
     * Remove a song from all setlists by its file path.
     * Called when a song is deleted from the file system.
     * @param songPath The absolute path of the deleted song
     * @return Number of setlist entries removed
     */
    public int removeSongFromAllSetLists(String songPath) {
        SQLiteDatabase db = getWritableDatabase();

        // Find all setlists containing this song
        Cursor cursor = db.query(true, TABLE_SETLIST_ITEMS, new String[]{COL_SETLIST_ID},
            COL_SONG_PATH + " = ?", new String[]{songPath}, null, null, null, null);

        List<Long> affectedSetLists = new ArrayList<Long>();
        while (cursor.moveToNext()) {
            affectedSetLists.add(cursor.getLong(0));
        }
        cursor.close();

        // Delete all entries with this song path
        int deleted = db.delete(TABLE_SETLIST_ITEMS, COL_SONG_PATH + " = ?",
            new String[]{songPath});

        // Reorder items in affected setlists
        for (Long setListId : affectedSetLists) {
            reorderSetListItems(setListId);
            updateSetListModifiedTime(setListId);
        }

        return deleted;
    }
}

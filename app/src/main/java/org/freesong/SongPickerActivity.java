package org.freesong;

import android.app.Activity;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FilenameFilter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Activity for selecting songs to add to a setlist.
 */
public class SongPickerActivity extends Activity {

    private ListView songListView;
    private TextView selectedCountText;
    private Button cancelBtn;
    private Button addBtn;

    private List<File> songFiles = new ArrayList<File>();
    private Map<File, String> songTitles = new HashMap<File, String>();
    private Set<Integer> selectedPositions = new HashSet<Integer>();
    private ArrayAdapter<String> adapter;
    private long setListId;
    private SetListDbHelper dbHelper;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_song_picker);

        setListId = getIntent().getLongExtra("setListId", -1);
        if (setListId == -1) {
            Toast.makeText(this, "Invalid setlist", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        dbHelper = SetListDbHelper.getInstance(this);

        songListView = (ListView) findViewById(R.id.songListView);
        selectedCountText = (TextView) findViewById(R.id.selectedCountText);
        cancelBtn = (Button) findViewById(R.id.cancelBtn);
        addBtn = (Button) findViewById(R.id.addBtn);

        loadSongs();
        setupListView();

        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                setResult(RESULT_CANCELED);
                finish();
            }
        });

        addBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                addSelectedSongs();
            }
        });

        updateSelectedCount();
    }

    private void loadSongs() {
        songFiles.clear();
        songTitles.clear();

        // Get existing song paths in setlist to exclude duplicates
        List<SetList.SetListItem> existingItems = dbHelper.getSetListItems(setListId);
        Set<String> existingPaths = new HashSet<String>();
        for (SetList.SetListItem item : existingItems) {
            existingPaths.add(item.getSongPath());
        }

        // Look for songs in standard locations
        List<File> searchDirs = new ArrayList<File>();
        searchDirs.add(new File(Environment.getExternalStorageDirectory(), "FreeSong"));
        searchDirs.add(new File(Environment.getExternalStorageDirectory(), "OnSong"));
        searchDirs.add(new File(Environment.getExternalStorageDirectory(), "Download"));

        FilenameFilter songFilter = new FilenameFilter() {
            @Override
            public boolean accept(File dir, String filename) {
                String lower = filename.toLowerCase();
                return lower.endsWith(".onsong") ||
                       lower.endsWith(".chordpro") ||
                       lower.endsWith(".cho") ||
                       lower.endsWith(".crd") ||
                       lower.endsWith(".pro") ||
                       lower.endsWith(".txt");
            }
        };

        for (File dir : searchDirs) {
            if (dir.exists() && dir.isDirectory()) {
                File[] files = dir.listFiles(songFilter);
                if (files != null) {
                    for (File file : files) {
                        if (!existingPaths.contains(file.getAbsolutePath())) {
                            songFiles.add(file);
                            songTitles.put(file, getSongTitle(file));
                        }
                    }
                }
            }
        }

        // Sort by song title
        Collections.sort(songFiles, new Comparator<File>() {
            @Override
            public int compare(File f1, File f2) {
                String t1 = songTitles.get(f1);
                String t2 = songTitles.get(f2);
                return t1.compareToIgnoreCase(t2);
            }
        });
    }

    private String getSongTitle(File file) {
        try {
            Song song = SongParser.parseFile(file);
            String title = song.getTitle();
            if (title != null && !title.isEmpty()) {
                return title;
            }
        } catch (Exception e) {
            // Fall back to filename
        }
        // Use filename without extension as fallback
        String name = file.getName();
        int dotIndex = name.lastIndexOf('.');
        if (dotIndex > 0) {
            name = name.substring(0, dotIndex);
        }
        return name;
    }

    private void setupListView() {
        List<String> songNames = new ArrayList<String>();
        for (File file : songFiles) {
            songNames.add(songTitles.get(file));
        }

        adapter = new ArrayAdapter<String>(this,
            android.R.layout.simple_list_item_multiple_choice, songNames);
        songListView.setAdapter(adapter);

        songListView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                if (selectedPositions.contains(position)) {
                    selectedPositions.remove(position);
                } else {
                    selectedPositions.add(position);
                }
                updateSelectedCount();
            }
        });
    }

    private void updateSelectedCount() {
        int count = selectedPositions.size();
        selectedCountText.setText(count + " selected");
        addBtn.setEnabled(count > 0);
    }

    private void addSelectedSongs() {
        if (selectedPositions.isEmpty()) {
            Toast.makeText(this, "No songs selected", Toast.LENGTH_SHORT).show();
            return;
        }

        int added = 0;
        for (int position : selectedPositions) {
            File file = songFiles.get(position);
            try {
                Song song = SongParser.parseFile(file);
                SetList.SetListItem item = new SetList.SetListItem(
                    file.getAbsolutePath(),
                    song.getTitle(),
                    song.getArtist()
                );
                dbHelper.addItemToSetList(setListId, item);
                added++;
            } catch (Exception e) {
                // Use filename if parsing fails
                String name = file.getName();
                int dotIndex = name.lastIndexOf('.');
                if (dotIndex > 0) {
                    name = name.substring(0, dotIndex);
                }
                SetList.SetListItem item = new SetList.SetListItem(
                    file.getAbsolutePath(),
                    name,
                    ""
                );
                dbHelper.addItemToSetList(setListId, item);
                added++;
            }
        }

        Toast.makeText(this, "Added " + added + " song" + (added != 1 ? "s" : ""),
            Toast.LENGTH_SHORT).show();

        setResult(RESULT_OK);
        finish();
    }
}

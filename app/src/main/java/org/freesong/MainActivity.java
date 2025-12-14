package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import android.text.Editable;
import android.text.TextWatcher;

import java.io.File;
import java.io.FilenameFilter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * Main activity showing the song library.
 */
public class MainActivity extends Activity {

    private static final int REQUEST_IMPORT = 100;

    private ListView songListView;
    private TextView emptyText;
    private TextView songCountText;
    private Button setlistsBtn;
    private Button themeBtn;
    private Button importBtn;
    private EditText searchField;
    private List<File> allSongFiles = new ArrayList<File>();
    private List<File> filteredSongFiles = new ArrayList<File>();
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_main);

        songListView = (ListView) findViewById(R.id.songListView);
        emptyText = (TextView) findViewById(R.id.emptyText);
        songCountText = (TextView) findViewById(R.id.songCountText);
        setlistsBtn = (Button) findViewById(R.id.setlistsBtn);
        themeBtn = (Button) findViewById(R.id.themeBtn);
        importBtn = (Button) findViewById(R.id.importBtn);
        searchField = (EditText) findViewById(R.id.searchField);

        setlistsBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openSetLists();
            }
        });

        themeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleTheme();
            }
        });

        importBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openImport();
            }
        });

        searchField.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                filterSongs(s.toString());
            }
        });

        setupSongList();
    }

    private void toggleTheme() {
        ThemeManager.toggleDarkMode(this);
        recreate();
    }

    private void openSetLists() {
        Intent intent = new Intent(this, SetListsActivity.class);
        startActivity(intent);
    }

    private void openImport() {
        Intent intent = new Intent(this, FileBrowserActivity.class);
        startActivityForResult(intent, REQUEST_IMPORT);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_IMPORT && resultCode == RESULT_OK) {
            // Reload songs after import
            loadSongs();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        loadSongs();
    }

    private void setupSongList() {
        adapter = new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, new ArrayList<String>());
        songListView.setAdapter(adapter);

        songListView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                openSong(filteredSongFiles.get(position));
            }
        });

        songListView.setOnItemLongClickListener(new AdapterView.OnItemLongClickListener() {
            @Override
            public boolean onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
                showSongInfo(filteredSongFiles.get(position));
                return true;
            }
        });
    }

    private void loadSongs() {
        allSongFiles.clear();

        // Look for songs in FreeSong folder on external storage
        File freeSongDir = new File(Environment.getExternalStorageDirectory(), "FreeSong");
        if (!freeSongDir.exists()) {
            freeSongDir.mkdirs();
        }

        // Also check common OnSong locations
        List<File> searchDirs = new ArrayList<File>();
        searchDirs.add(freeSongDir);
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
                    allSongFiles.addAll(Arrays.asList(files));
                }
            }
        }

        // Sort by filename
        Collections.sort(allSongFiles, new Comparator<File>() {
            @Override
            public int compare(File f1, File f2) {
                return f1.getName().compareToIgnoreCase(f2.getName());
            }
        });

        // Apply current filter
        filterSongs(searchField.getText().toString());
    }

    private void filterSongs(String query) {
        filteredSongFiles.clear();
        adapter.clear();

        String lowerQuery = query.toLowerCase().trim();

        for (File file : allSongFiles) {
            String name = file.getName();
            int dotIndex = name.lastIndexOf('.');
            if (dotIndex > 0) {
                name = name.substring(0, dotIndex);
            }

            if (lowerQuery.isEmpty() || name.toLowerCase().contains(lowerQuery)) {
                filteredSongFiles.add(file);
                adapter.add(name);
            }
        }

        updateSongCount();
    }

    private void updateSongCount() {
        int filtered = filteredSongFiles.size();
        int total = allSongFiles.size();

        if (filtered == total) {
            songCountText.setText(total + " song" + (total != 1 ? "s" : ""));
        } else {
            songCountText.setText(filtered + " of " + total + " songs");
        }

        // Show/hide empty message
        if (filteredSongFiles.isEmpty()) {
            emptyText.setVisibility(View.VISIBLE);
            songListView.setVisibility(View.GONE);
            if (allSongFiles.isEmpty()) {
                emptyText.setText(R.string.no_songs);
            } else {
                emptyText.setText("No songs match your search");
            }
        } else {
            emptyText.setVisibility(View.GONE);
            songListView.setVisibility(View.VISIBLE);
        }
    }

    private void openSong(File file) {
        Intent intent = new Intent(this, SongViewActivity.class);
        intent.putExtra("songPath", file.getAbsolutePath());
        startActivity(intent);
    }

    private void showSongInfo(final File file) {
        try {
            final Song song = SongParser.parseFile(file);
            StringBuilder info = new StringBuilder();
            info.append("Title: ").append(song.getTitle()).append("\n");
            info.append("Artist: ").append(song.getArtist()).append("\n");
            if (!song.getKey().isEmpty()) {
                info.append("Key: ").append(song.getKey()).append("\n");
            }
            if (!song.getTempo().isEmpty()) {
                info.append("Tempo: ").append(song.getTempo()).append("\n");
            }
            info.append("File: ").append(file.getName());

            new AlertDialog.Builder(this)
                .setTitle("Song Info")
                .setMessage(info.toString())
                .setPositiveButton("Open", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        openSong(file);
                    }
                })
                .setNeutralButton("Add to Setlist", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        showAddToSetlistDialog(file, song);
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
        } catch (Exception e) {
            Toast.makeText(this, "Error reading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void showAddToSetlistDialog(final File file, final Song song) {
        final SetListDbHelper dbHelper = SetListDbHelper.getInstance(this);
        final List<SetList> setLists = dbHelper.getAllSetLists();

        if (setLists.isEmpty()) {
            new AlertDialog.Builder(this)
                .setTitle("No Setlists")
                .setMessage("Create a setlist first.")
                .setPositiveButton("Create Setlist", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        openSetLists();
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
            return;
        }

        String[] setlistNames = new String[setLists.size()];
        for (int i = 0; i < setLists.size(); i++) {
            setlistNames[i] = setLists.get(i).getName();
        }

        new AlertDialog.Builder(this)
            .setTitle("Add to Setlist")
            .setItems(setlistNames, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    SetList selectedSetList = setLists.get(which);
                    SetList.SetListItem item = new SetList.SetListItem(
                        file.getAbsolutePath(),
                        song.getTitle(),
                        song.getArtist()
                    );
                    dbHelper.addItemToSetList(selectedSetList.getId(), item);
                    Toast.makeText(MainActivity.this,
                        "Added to \"" + selectedSetList.getName() + "\"",
                        Toast.LENGTH_SHORT).show();
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
    }
}

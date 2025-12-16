package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.AsyncTask;
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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
    private Button aboutBtn;
    private EditText searchField;
    private List<File> allSongFiles = new ArrayList<File>();
    private List<File> filteredSongFiles = new ArrayList<File>();
    private Map<File, String> songTitles = new HashMap<File, String>();
    private Map<File, String> songArtists = new HashMap<File, String>();
    private ArrayAdapter<String> adapter;
    private boolean songsLoaded = false;

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
        aboutBtn = (Button) findViewById(R.id.aboutBtn);
        searchField = (EditText) findViewById(R.id.searchField);

        aboutBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showAboutDialog();
            }
        });

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
        updateThemeButton();

        // Restore state if available (e.g., after theme change)
        if (savedInstanceState != null && savedInstanceState.getBoolean("songsLoaded", false)) {
            restoreSongList(savedInstanceState);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (!allSongFiles.isEmpty()) {
            ArrayList<String> paths = new ArrayList<String>();
            ArrayList<String> titles = new ArrayList<String>();
            ArrayList<String> artists = new ArrayList<String>();
            for (File f : allSongFiles) {
                paths.add(f.getAbsolutePath());
                titles.add(songTitles.get(f));
                artists.add(songArtists.get(f));
            }
            outState.putStringArrayList("songPaths", paths);
            outState.putStringArrayList("songTitles", titles);
            outState.putStringArrayList("songArtists", artists);
            outState.putBoolean("songsLoaded", true);
            outState.putString("searchQuery", searchField.getText().toString());
        }
    }

    private void restoreSongList(Bundle savedState) {
        ArrayList<String> paths = savedState.getStringArrayList("songPaths");
        ArrayList<String> titles = savedState.getStringArrayList("songTitles");
        ArrayList<String> artists = savedState.getStringArrayList("songArtists");
        String searchQuery = savedState.getString("searchQuery", "");

        if (paths != null && titles != null && artists != null) {
            allSongFiles.clear();
            songTitles.clear();
            songArtists.clear();

            for (int i = 0; i < paths.size(); i++) {
                File file = new File(paths.get(i));
                allSongFiles.add(file);
                songTitles.put(file, titles.get(i));
                songArtists.put(file, artists.get(i));
            }

            songsLoaded = true;
            searchField.setText(searchQuery);
            filterSongs(searchQuery);
        }
    }

    private void updateThemeButton() {
        // Show sun in dark mode (to switch to light), moon in light mode (to switch to dark)
        if (ThemeManager.isDarkMode(this)) {
            themeBtn.setText(R.string.theme_icon_sun);
            themeBtn.setTextColor(getResources().getColor(R.color.text_primary_dark));
        } else {
            themeBtn.setText(R.string.theme_icon_moon);
            themeBtn.setTextColor(0xFF333333); // Dark text for visibility on light background
        }
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
        // Only reload if list is empty and not restored from saved state
        if (allSongFiles.isEmpty() && !songsLoaded) {
            loadSongs();
        }
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
        // Show loading indicator
        emptyText.setText("Loading songs...");
        emptyText.setVisibility(View.VISIBLE);
        songListView.setVisibility(View.GONE);

        new AsyncTask<Void, Integer, Void>() {
            private int totalFiles = 0;

            @Override
            protected Void doInBackground(Void... params) {
                allSongFiles.clear();
                songTitles.clear();
                songArtists.clear();

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

                // First pass: collect all files
                List<File> filesToLoad = new ArrayList<File>();
                for (File dir : searchDirs) {
                    if (dir.exists() && dir.isDirectory()) {
                        File[] files = dir.listFiles(songFilter);
                        if (files != null) {
                            for (File file : files) {
                                filesToLoad.add(file);
                            }
                        }
                    }
                }

                totalFiles = filesToLoad.size();
                int loaded = 0;

                // Second pass: load metadata with progress
                for (File file : filesToLoad) {
                    allSongFiles.add(file);
                    loadSongInfo(file);
                    loaded++;
                    if (loaded % 50 == 0 || loaded == totalFiles) {
                        publishProgress(loaded);
                    }
                }

                // Sort by song title
                Collections.sort(allSongFiles, new Comparator<File>() {
                    @Override
                    public int compare(File f1, File f2) {
                        String t1 = songTitles.get(f1);
                        String t2 = songTitles.get(f2);
                        if (t1 == null) t1 = "";
                        if (t2 == null) t2 = "";
                        return t1.compareToIgnoreCase(t2);
                    }
                });

                return null;
            }

            @Override
            protected void onProgressUpdate(Integer... values) {
                emptyText.setText("Loading songs... " + values[0] + "/" + totalFiles);
            }

            @Override
            protected void onPostExecute(Void result) {
                songsLoaded = true;
                // Apply current filter on UI thread
                filterSongs(searchField.getText().toString());
            }
        }.execute();
    }

    private void loadSongInfo(File file) {
        String title = null;
        String artist = "";
        try {
            Song song = SongParser.parseFile(file);
            title = song.getTitle();
            artist = song.getArtist();
        } catch (Exception e) {
            // Fall back to filename
        }
        // Use filename without extension as fallback for title
        if (title == null || title.isEmpty()) {
            String name = file.getName();
            int dotIndex = name.lastIndexOf('.');
            if (dotIndex > 0) {
                name = name.substring(0, dotIndex);
            }
            title = name;
        }
        songTitles.put(file, title);
        songArtists.put(file, artist != null ? artist : "");
    }

    private void filterSongs(String query) {
        filteredSongFiles.clear();
        adapter.clear();

        String lowerQuery = query.toLowerCase().trim();

        for (File file : allSongFiles) {
            String title = songTitles.get(file);
            String artist = songArtists.get(file);
            if (title == null) {
                title = file.getName();
            }
            if (artist == null) {
                artist = "";
            }

            // Search in both title and artist
            if (lowerQuery.isEmpty() ||
                title.toLowerCase().contains(lowerQuery) ||
                artist.toLowerCase().contains(lowerQuery)) {
                filteredSongFiles.add(file);
                // Show artist in list if available
                if (!artist.isEmpty()) {
                    adapter.add(title + " - " + artist);
                } else {
                    adapter.add(title);
                }
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

        // Pass filtered list for swipe navigation between songs
        ArrayList<String> songPaths = new ArrayList<String>();
        for (File f : filteredSongFiles) {
            songPaths.add(f.getAbsolutePath());
        }
        intent.putStringArrayListExtra("setlistPaths", songPaths);
        intent.putExtra("currentIndex", filteredSongFiles.indexOf(file));

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

            String[] options = {"Open", "Add to Setlist", "Delete"};

            new AlertDialog.Builder(this)
                .setTitle(song.getTitle())
                .setMessage(info.toString())
                .setItems(options, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        switch (which) {
                            case 0: // Open
                                openSong(file);
                                break;
                            case 1: // Add to Setlist
                                showAddToSetlistDialog(file, song);
                                break;
                            case 2: // Delete
                                confirmDeleteSong(file, song.getTitle());
                                break;
                        }
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
        } catch (Exception e) {
            Toast.makeText(this, "Error reading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void confirmDeleteSong(final File file, String title) {
        new AlertDialog.Builder(this)
            .setTitle("Delete Song")
            .setMessage("Delete \"" + title + "\"?\n\nFile: " + file.getName() + "\n\nThis cannot be undone.")
            .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    if (file.delete()) {
                        Toast.makeText(MainActivity.this, "Song deleted", Toast.LENGTH_SHORT).show();
                        // Remove from lists without full reload
                        allSongFiles.remove(file);
                        songTitles.remove(file);
                        songArtists.remove(file);
                        filterSongs(searchField.getText().toString());
                    } else {
                        Toast.makeText(MainActivity.this, "Could not delete file", Toast.LENGTH_SHORT).show();
                    }
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
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

    private void showAboutDialog() {
        String version = "Unknown";
        try {
            PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            version = pInfo.versionName;
        } catch (PackageManager.NameNotFoundException e) {
            // Use default
        }

        StringBuilder message = new StringBuilder();
        message.append("Version: ").append(version).append("\n\n");
        message.append("Author: ").append(getString(R.string.app_author)).append("\n\n");
        message.append(getString(R.string.app_description)).append("\n\n");
        message.append("License: ").append(getString(R.string.app_license)).append("\n\n");
        message.append(getString(R.string.app_url));

        new AlertDialog.Builder(this)
            .setTitle(getString(R.string.app_name))
            .setMessage(message.toString())
            .setPositiveButton("OK", null)
            .show();
    }
}

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
import android.widget.Toast;

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

    private ListView songListView;
    private TextView emptyText;
    private List<File> songFiles = new ArrayList<File>();
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        songListView = (ListView) findViewById(R.id.songListView);
        emptyText = (TextView) findViewById(R.id.emptyText);

        setupSongList();
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
                openSong(songFiles.get(position));
            }
        });

        songListView.setOnItemLongClickListener(new AdapterView.OnItemLongClickListener() {
            @Override
            public boolean onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
                showSongInfo(songFiles.get(position));
                return true;
            }
        });
    }

    private void loadSongs() {
        songFiles.clear();
        adapter.clear();

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
                    songFiles.addAll(Arrays.asList(files));
                }
            }
        }

        // Sort by filename
        Collections.sort(songFiles, new Comparator<File>() {
            @Override
            public int compare(File f1, File f2) {
                return f1.getName().compareToIgnoreCase(f2.getName());
            }
        });

        // Update adapter
        for (File file : songFiles) {
            String name = file.getName();
            // Remove extension for display
            int dotIndex = name.lastIndexOf('.');
            if (dotIndex > 0) {
                name = name.substring(0, dotIndex);
            }
            adapter.add(name);
        }

        // Show/hide empty message
        if (songFiles.isEmpty()) {
            emptyText.setVisibility(View.VISIBLE);
            songListView.setVisibility(View.GONE);
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

    private void showSongInfo(File file) {
        try {
            Song song = SongParser.parseFile(file);
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
                .setNegativeButton("Cancel", null)
                .show();
        } catch (Exception e) {
            Toast.makeText(this, "Error reading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }
}

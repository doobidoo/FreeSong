package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * Activity for viewing and editing a setlist.
 */
public class SetListViewActivity extends Activity {

    private static final int REQUEST_ADD_SONGS = 1;

    private TextView setlistNameText;
    private TextView songCountText;
    private ListView songListView;
    private TextView emptyText;
    private Button addSongBtn;
    private Button playSetlistBtn;
    private Button editSetlistBtn;

    private SetList setList;
    private List<SetList.SetListItem> items = new ArrayList<SetList.SetListItem>();
    private SongListAdapter adapter;
    private SetListDbHelper dbHelper;
    private boolean editMode = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_setlist_view);

        dbHelper = SetListDbHelper.getInstance(this);

        setlistNameText = (TextView) findViewById(R.id.setlistNameText);
        songCountText = (TextView) findViewById(R.id.songCountText);
        songListView = (ListView) findViewById(R.id.songListView);
        emptyText = (TextView) findViewById(R.id.emptyText);
        addSongBtn = (Button) findViewById(R.id.addSongBtn);
        playSetlistBtn = (Button) findViewById(R.id.playSetlistBtn);
        editSetlistBtn = (Button) findViewById(R.id.editSetlistBtn);

        adapter = new SongListAdapter();
        songListView.setAdapter(adapter);

        songListView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                if (editMode) {
                    showEditItemOptions(position);
                } else {
                    playSong(position);
                }
            }
        });

        songListView.setOnItemLongClickListener(new AdapterView.OnItemLongClickListener() {
            @Override
            public boolean onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
                showEditItemOptions(position);
                return true;
            }
        });

        addSongBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openSongPicker();
            }
        });

        playSetlistBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (!items.isEmpty()) {
                    playSong(0);
                } else {
                    Toast.makeText(SetListViewActivity.this, "Setlist is empty",
                        Toast.LENGTH_SHORT).show();
                }
            }
        });

        editSetlistBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleEditMode();
            }
        });

        loadSetList();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (setList != null) {
            loadSetList();
        }
    }

    private void loadSetList() {
        long setListId = getIntent().getLongExtra("setListId", -1);
        if (setListId == -1) {
            Toast.makeText(this, "Invalid setlist", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        setList = dbHelper.getSetList(setListId);
        if (setList == null) {
            Toast.makeText(this, "Setlist not found", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        items = setList.getItems();
        updateUI();
    }

    private void updateUI() {
        setlistNameText.setText(setList.getName());
        int count = items.size();
        songCountText.setText(count + (count == 1 ? " song" : " songs"));

        adapter.notifyDataSetChanged();

        if (items.isEmpty()) {
            emptyText.setVisibility(View.VISIBLE);
            songListView.setVisibility(View.GONE);
        } else {
            emptyText.setVisibility(View.GONE);
            songListView.setVisibility(View.VISIBLE);
        }
    }

    private void toggleEditMode() {
        editMode = !editMode;
        editSetlistBtn.setText(editMode ? "Done" : "Edit");
        adapter.notifyDataSetChanged();

        if (editMode) {
            Toast.makeText(this, "Tap a song to move or remove", Toast.LENGTH_SHORT).show();
        }
    }

    private void playSong(int position) {
        SetList.SetListItem item = items.get(position);
        File file = new File(item.getSongPath());

        if (!file.exists()) {
            Toast.makeText(this, "Song file not found", Toast.LENGTH_SHORT).show();
            return;
        }

        // Build list of song paths for swipe navigation
        ArrayList<String> songPaths = new ArrayList<String>();
        for (SetList.SetListItem i : items) {
            songPaths.add(i.getSongPath());
        }

        Intent intent = new Intent(this, SongViewActivity.class);
        intent.putExtra("songPath", item.getSongPath());
        intent.putStringArrayListExtra("setlistPaths", songPaths);
        intent.putExtra("currentIndex", position);
        startActivity(intent);
    }

    private void openSongPicker() {
        Intent intent = new Intent(this, SongPickerActivity.class);
        intent.putExtra("setListId", setList.getId());
        startActivityForResult(intent, REQUEST_ADD_SONGS);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_ADD_SONGS && resultCode == RESULT_OK) {
            loadSetList();
        }
    }

    private void showEditItemOptions(final int position) {
        final SetList.SetListItem item = items.get(position);
        String[] options;

        if (items.size() == 1) {
            options = new String[]{"Play", "Remove"};
        } else if (position == 0) {
            options = new String[]{"Play", "Move Down", "Remove"};
        } else if (position == items.size() - 1) {
            options = new String[]{"Play", "Move Up", "Remove"};
        } else {
            options = new String[]{"Play", "Move Up", "Move Down", "Remove"};
        }

        new AlertDialog.Builder(this)
            .setTitle(item.getSongTitle())
            .setItems(options, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    String action = null;
                    if (items.size() == 1) {
                        switch (which) {
                            case 0: action = "play"; break;
                            case 1: action = "remove"; break;
                        }
                    } else if (position == 0) {
                        switch (which) {
                            case 0: action = "play"; break;
                            case 1: action = "down"; break;
                            case 2: action = "remove"; break;
                        }
                    } else if (position == items.size() - 1) {
                        switch (which) {
                            case 0: action = "play"; break;
                            case 1: action = "up"; break;
                            case 2: action = "remove"; break;
                        }
                    } else {
                        switch (which) {
                            case 0: action = "play"; break;
                            case 1: action = "up"; break;
                            case 2: action = "down"; break;
                            case 3: action = "remove"; break;
                        }
                    }

                    if ("play".equals(action)) {
                        playSong(position);
                    } else if ("up".equals(action)) {
                        moveItem(position, position - 1);
                    } else if ("down".equals(action)) {
                        moveItem(position, position + 1);
                    } else if ("remove".equals(action)) {
                        confirmRemoveItem(item);
                    }
                }
            })
            .show();
    }

    private void moveItem(int from, int to) {
        dbHelper.moveItemInSetList(setList.getId(), from, to);
        items = dbHelper.getSetListItems(setList.getId());
        updateUI();
    }

    private void confirmRemoveItem(final SetList.SetListItem item) {
        new AlertDialog.Builder(this)
            .setTitle("Remove Song")
            .setMessage("Remove \"" + item.getSongTitle() + "\" from this setlist?")
            .setPositiveButton("Remove", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    dbHelper.removeItemFromSetList(item.getId());
                    items = dbHelper.getSetListItems(setList.getId());
                    updateUI();
                    Toast.makeText(SetListViewActivity.this, "Removed", Toast.LENGTH_SHORT).show();
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
    }

    private class SongListAdapter extends BaseAdapter {

        @Override
        public int getCount() {
            return items.size();
        }

        @Override
        public Object getItem(int position) {
            return items.get(position);
        }

        @Override
        public long getItemId(int position) {
            return items.get(position).getId();
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            if (convertView == null) {
                convertView = LayoutInflater.from(SetListViewActivity.this)
                    .inflate(R.layout.item_setlist_song, parent, false);
            }

            SetList.SetListItem item = items.get(position);

            TextView numberText = (TextView) convertView.findViewById(R.id.songNumber);
            TextView titleText = (TextView) convertView.findViewById(R.id.songTitle);
            TextView artistText = (TextView) convertView.findViewById(R.id.songArtist);

            numberText.setText((position + 1) + ".");
            titleText.setText(item.getSongTitle());
            artistText.setText(item.getSongArtist());

            return convertView;
        }
    }
}

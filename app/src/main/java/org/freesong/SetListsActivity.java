package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Activity for managing setlists.
 */
public class SetListsActivity extends Activity {

    private ListView setlistListView;
    private TextView emptyText;
    private Button newSetlistBtn;
    private Button themeBtn;
    private Button exportBtn;
    private Button importBtn;

    private List<SetList> setLists = new ArrayList<SetList>();
    private SetListAdapter adapter;
    private SetListDbHelper dbHelper;
    private boolean checkedForRestore = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_setlists);

        dbHelper = SetListDbHelper.getInstance(this);

        setlistListView = (ListView) findViewById(R.id.setlistListView);
        emptyText = (TextView) findViewById(R.id.emptyText);
        newSetlistBtn = (Button) findViewById(R.id.newSetlistBtn);
        themeBtn = (Button) findViewById(R.id.themeBtn);

        updateThemeButton();

        themeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleTheme();
            }
        });

        adapter = new SetListAdapter();
        setlistListView.setAdapter(adapter);

        setlistListView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                openSetList(setLists.get(position));
            }
        });

        setlistListView.setOnItemLongClickListener(new AdapterView.OnItemLongClickListener() {
            @Override
            public boolean onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
                showSetListOptions(setLists.get(position));
                return true;
            }
        });

        newSetlistBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showCreateSetListDialog();
            }
        });

        exportBtn = (Button) findViewById(R.id.exportBtn);
        importBtn = (Button) findViewById(R.id.importBtn);

        exportBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                exportSetlists();
            }
        });

        importBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showImportDialog();
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        loadSetLists();
    }

    private void loadSetLists() {
        setLists = dbHelper.getAllSetLists();

        // Check for auto-restore on first load if DB is empty
        if (!checkedForRestore && setLists.isEmpty() && SetlistBackupManager.backupExists()) {
            checkedForRestore = true;
            showAutoRestoreDialog();
            return;
        }
        checkedForRestore = true;

        adapter.notifyDataSetChanged();

        if (setLists.isEmpty()) {
            emptyText.setVisibility(View.VISIBLE);
            setlistListView.setVisibility(View.GONE);
        } else {
            emptyText.setVisibility(View.GONE);
            setlistListView.setVisibility(View.VISIBLE);
        }

        // Update import button text based on backup availability
        if (SetlistBackupManager.backupExists()) {
            String info = SetlistBackupManager.getBackupInfo();
            importBtn.setText("Import (" + info + ")");
        } else {
            importBtn.setText("Import");
        }
    }

    private void showAutoRestoreDialog() {
        String info = SetlistBackupManager.getBackupInfo();
        new AlertDialog.Builder(this)
            .setTitle("Restore Setlists?")
            .setMessage("A backup was found:\n" + info + "\n\nRestore setlists from backup?")
            .setPositiveButton("Restore", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    new ImportSetlistsTask(true).execute(false);
                }
            })
            .setNegativeButton("Skip", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    loadSetLists();
                }
            })
            .setCancelable(false)
            .show();
    }

    private void exportSetlists() {
        if (setLists.isEmpty()) {
            Toast.makeText(this, "No setlists to export", Toast.LENGTH_SHORT).show();
            return;
        }

        boolean success = SetlistBackupManager.exportSetlists(this);
        if (success) {
            Toast.makeText(this, "Exported " + setLists.size() + " setlist(s) to FreeSong folder",
                Toast.LENGTH_SHORT).show();
            loadSetLists(); // Refresh import button text
        } else {
            Toast.makeText(this, "Export failed", Toast.LENGTH_SHORT).show();
        }
    }

    private void showImportDialog() {
        if (!SetlistBackupManager.backupExists()) {
            Toast.makeText(this, "No backup file found in FreeSong folder", Toast.LENGTH_SHORT).show();
            return;
        }

        String info = SetlistBackupManager.getBackupInfo();
        String[] options = {"Import (skip existing)", "Import (replace existing)"};

        new AlertDialog.Builder(this)
            .setTitle("Import Setlists")
            .setMessage("Backup: " + info)
            .setItems(options, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    boolean merge = (which == 1);
                    new ImportSetlistsTask(false).execute(merge);
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
    }

    private void openSetList(SetList setList) {
        Intent intent = new Intent(this, SetListViewActivity.class);
        intent.putExtra("setListId", setList.getId());
        startActivity(intent);
    }

    private void showCreateSetListDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("New Setlist");

        final EditText input = new EditText(this);
        input.setHint("Setlist name");
        builder.setView(input);

        builder.setPositiveButton("Create", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                String name = input.getText().toString().trim();
                if (!name.isEmpty()) {
                    createSetList(name);
                } else {
                    Toast.makeText(SetListsActivity.this, "Please enter a name",
                        Toast.LENGTH_SHORT).show();
                }
            }
        });

        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    private void createSetList(String name) {
        SetList setList = new SetList(name);
        dbHelper.createSetList(setList);
        loadSetLists();
        Toast.makeText(this, "Created: " + name, Toast.LENGTH_SHORT).show();
    }

    private void showSetListOptions(final SetList setList) {
        String[] options = {"Open", "Rename", "Delete"};

        new AlertDialog.Builder(this)
            .setTitle(setList.getName())
            .setItems(options, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    switch (which) {
                        case 0:
                            openSetList(setList);
                            break;
                        case 1:
                            showRenameDialog(setList);
                            break;
                        case 2:
                            confirmDelete(setList);
                            break;
                    }
                }
            })
            .show();
    }

    private void showRenameDialog(final SetList setList) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Rename Setlist");

        final EditText input = new EditText(this);
        input.setText(setList.getName());
        input.setSelection(input.getText().length());
        builder.setView(input);

        builder.setPositiveButton("Rename", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                String name = input.getText().toString().trim();
                if (!name.isEmpty()) {
                    setList.setName(name);
                    dbHelper.updateSetList(setList);
                    loadSetLists();
                    Toast.makeText(SetListsActivity.this, "Renamed", Toast.LENGTH_SHORT).show();
                }
            }
        });

        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    private void toggleTheme() {
        ThemeManager.toggleDarkMode(this);
        recreate();
    }

    private void updateThemeButton() {
        if (ThemeManager.isDarkMode(this)) {
            themeBtn.setText(R.string.theme_icon_sun);
        } else {
            themeBtn.setText(R.string.theme_icon_moon);
        }
    }

    private void confirmDelete(final SetList setList) {
        new AlertDialog.Builder(this)
            .setTitle("Delete Setlist")
            .setMessage("Delete \"" + setList.getName() + "\"?\n\nThis cannot be undone.")
            .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    dbHelper.deleteSetList(setList.getId());
                    loadSetLists();
                    Toast.makeText(SetListsActivity.this, "Deleted", Toast.LENGTH_SHORT).show();
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
    }

    /**
     * AsyncTask to perform setlist import in background thread.
     * Prevents ANR when importing large backup files.
     */
    private class ImportSetlistsTask extends AsyncTask<Boolean, Void, Integer> {
        private ProgressDialog progressDialog;
        private boolean isAutoRestore;

        public ImportSetlistsTask(boolean isAutoRestore) {
            this.isAutoRestore = isAutoRestore;
        }

        @Override
        protected void onPreExecute() {
            progressDialog = new ProgressDialog(SetListsActivity.this);
            progressDialog.setMessage("Importing setlists...");
            progressDialog.setCancelable(false);
            progressDialog.show();
        }

        @Override
        protected Integer doInBackground(Boolean... params) {
            boolean merge = params[0];
            return SetlistBackupManager.importSetlists(SetListsActivity.this, merge);
        }

        @Override
        protected void onPostExecute(Integer result) {
            if (progressDialog != null && progressDialog.isShowing()) {
                progressDialog.dismiss();
            }

            if (result >= 0) {
                String action = isAutoRestore ? "Restored" : "Imported";
                Toast.makeText(SetListsActivity.this,
                    action + " " + result + " setlist(s)", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(SetListsActivity.this, "Import failed", Toast.LENGTH_SHORT).show();
            }
            loadSetLists();
        }
    }

    private class SetListAdapter extends BaseAdapter {

        private SimpleDateFormat dateFormat = new SimpleDateFormat("MMM d, yyyy", Locale.getDefault());

        @Override
        public int getCount() {
            return setLists.size();
        }

        @Override
        public Object getItem(int position) {
            return setLists.get(position);
        }

        @Override
        public long getItemId(int position) {
            return setLists.get(position).getId();
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            if (convertView == null) {
                convertView = LayoutInflater.from(SetListsActivity.this)
                    .inflate(R.layout.item_setlist, parent, false);
            }

            SetList setList = setLists.get(position);

            TextView nameText = (TextView) convertView.findViewById(R.id.setlistName);
            TextView infoText = (TextView) convertView.findViewById(R.id.setlistInfo);

            nameText.setText(setList.getName());

            int songCount = setList.getItems().size();
            String info = songCount + (songCount == 1 ? " song" : " songs");
            info += " - " + dateFormat.format(new Date(setList.getModifiedAt()));
            infoText.setText(info);

            return convertView;
        }
    }
}

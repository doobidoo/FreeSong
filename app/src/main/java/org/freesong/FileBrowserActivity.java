package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Environment;
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
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * Simple file browser for selecting backup files to import.
 */
public class FileBrowserActivity extends Activity {

    private ListView fileListView;
    private TextView pathText;
    private Button cancelBtn;
    private Button themeBtn;

    private File currentDir;
    private List<File> files = new ArrayList<File>();
    private FileAdapter adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_file_browser);

        fileListView = (ListView) findViewById(R.id.fileListView);
        pathText = (TextView) findViewById(R.id.pathText);
        cancelBtn = (Button) findViewById(R.id.cancelBtn);
        themeBtn = (Button) findViewById(R.id.themeBtn);

        updateThemeButton();

        themeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleTheme();
            }
        });

        adapter = new FileAdapter();
        fileListView.setAdapter(adapter);

        fileListView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                File file = files.get(position);
                if (file.isDirectory()) {
                    navigateTo(file);
                } else {
                    selectFile(file);
                }
            }
        });

        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                setResult(RESULT_CANCELED);
                finish();
            }
        });

        // Start at external storage root
        currentDir = Environment.getExternalStorageDirectory();
        loadFiles();
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

    @Override
    public void onBackPressed() {
        if (currentDir != null && currentDir.getParentFile() != null) {
            File parent = currentDir.getParentFile();
            if (parent.canRead()) {
                navigateTo(parent);
                return;
            }
        }
        super.onBackPressed();
    }

    private void navigateTo(File dir) {
        if (dir.canRead()) {
            currentDir = dir;
            loadFiles();
        } else {
            Toast.makeText(this, "Cannot access this folder", Toast.LENGTH_SHORT).show();
        }
    }

    private void loadFiles() {
        files.clear();
        pathText.setText(currentDir.getAbsolutePath());

        // Add parent directory option if not at root
        File parent = currentDir.getParentFile();
        if (parent != null && parent.canRead()) {
            // We'll handle ".." specially in the adapter
        }

        File[] fileArray = currentDir.listFiles();
        if (fileArray != null) {
            for (File file : fileArray) {
                // Skip hidden files
                if (file.getName().startsWith(".")) {
                    continue;
                }
                // Show directories and importable files
                if (file.isDirectory() || isImportableFile(file)) {
                    files.add(file);
                }
            }
        }

        // Sort: directories first, then files, both alphabetically
        Collections.sort(files, new Comparator<File>() {
            @Override
            public int compare(File f1, File f2) {
                if (f1.isDirectory() && !f2.isDirectory()) {
                    return -1;
                } else if (!f1.isDirectory() && f2.isDirectory()) {
                    return 1;
                }
                return f1.getName().compareToIgnoreCase(f2.getName());
            }
        });

        // Add parent at top if available
        if (parent != null && parent.canRead()) {
            files.add(0, parent);
        }

        adapter.notifyDataSetChanged();
    }

    private boolean isImportableFile(File file) {
        String name = file.getName().toLowerCase();
        return BackupImporter.isBackupFile(name) ||
               name.endsWith(".onsong") ||
               name.endsWith(".chordpro") ||
               name.endsWith(".cho") ||
               name.endsWith(".crd") ||
               name.endsWith(".pro") ||
               name.endsWith(".txt");
    }

    private void selectFile(final File file) {
        String name = file.getName().toLowerCase();

        if (BackupImporter.isBackupFile(name)) {
            // It's a backup file - confirm and import
            new AlertDialog.Builder(this)
                .setTitle("Import Backup")
                .setMessage("Import songs from:\n" + file.getName() + "?")
                .setPositiveButton("Import", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        importBackupFile(file);
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
        } else {
            // It's a single song file
            new AlertDialog.Builder(this)
                .setTitle("Import Song")
                .setMessage("Import:\n" + file.getName() + "?")
                .setPositiveButton("Import", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        importSingleFile(file);
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
        }
    }

    private void importBackupFile(final File file) {
        final ProgressDialog progress = new ProgressDialog(this);
        progress.setMessage("Importing songs...\nThis may take a while for large backups.");
        progress.setCancelable(false);
        progress.setProgressStyle(ProgressDialog.STYLE_SPINNER);
        progress.show();

        // Keep screen on during import
        getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        new AsyncTask<Void, Void, BackupImporter.ImportResult>() {
            private Exception error;

            @Override
            protected BackupImporter.ImportResult doInBackground(Void... params) {
                try {
                    return BackupImporter.importBackup(file);
                } catch (Exception e) {
                    error = e;
                    return null;
                }
            }

            @Override
            protected void onPostExecute(BackupImporter.ImportResult result) {
                progress.dismiss();
                // Allow screen to turn off again
                getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

                if (error != null) {
                    Toast.makeText(FileBrowserActivity.this,
                        "Import failed: " + error.getMessage(),
                        Toast.LENGTH_LONG).show();
                    return;
                }

                StringBuilder message = new StringBuilder();
                message.append("Imported: ").append(result.importedFiles).append(" songs\n");
                if (result.skippedFiles > 0) {
                    message.append("Skipped: ").append(result.skippedFiles).append(" (already exist)\n");
                }
                if (!result.errors.isEmpty()) {
                    message.append("Errors: ").append(result.errors.size());
                }

                new AlertDialog.Builder(FileBrowserActivity.this)
                    .setTitle("Import Complete")
                    .setMessage(message.toString())
                    .setPositiveButton("OK", new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                            setResult(RESULT_OK);
                            finish();
                        }
                    })
                    .show();
            }
        }.execute();
    }

    private void importSingleFile(File file) {
        try {
            boolean imported = BackupImporter.importSingleFile(file);
            if (imported) {
                Toast.makeText(this, "Imported: " + file.getName(), Toast.LENGTH_SHORT).show();
                setResult(RESULT_OK);
                finish();
            } else {
                Toast.makeText(this, "File already exists or invalid", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            Toast.makeText(this, "Import failed: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private class FileAdapter extends BaseAdapter {

        private DecimalFormat sizeFormat = new DecimalFormat("#.##");

        @Override
        public int getCount() {
            return files.size();
        }

        @Override
        public Object getItem(int position) {
            return files.get(position);
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            if (convertView == null) {
                convertView = LayoutInflater.from(FileBrowserActivity.this)
                    .inflate(R.layout.item_file, parent, false);
            }

            File file = files.get(position);
            boolean isParent = (position == 0 && file.equals(currentDir.getParentFile()));

            TextView iconText = (TextView) convertView.findViewById(R.id.fileIcon);
            TextView nameText = (TextView) convertView.findViewById(R.id.fileName);
            TextView infoText = (TextView) convertView.findViewById(R.id.fileInfo);

            if (isParent) {
                iconText.setText("⬆");
                nameText.setText("..");
                infoText.setVisibility(View.GONE);
            } else if (file.isDirectory()) {
                iconText.setText("📁");
                nameText.setText(file.getName());
                infoText.setVisibility(View.GONE);
            } else {
                String name = file.getName().toLowerCase();
                if (BackupImporter.isBackupFile(name)) {
                    iconText.setText("📦");
                } else {
                    iconText.setText("🎵");
                }
                nameText.setText(file.getName());
                infoText.setText(formatFileSize(file.length()));
                infoText.setVisibility(View.VISIBLE);
            }

            return convertView;
        }

        private String formatFileSize(long bytes) {
            if (bytes < 1024) {
                return bytes + " B";
            } else if (bytes < 1024 * 1024) {
                return sizeFormat.format(bytes / 1024.0) + " KB";
            } else {
                return sizeFormat.format(bytes / (1024.0 * 1024.0)) + " MB";
            }
        }
    }
}

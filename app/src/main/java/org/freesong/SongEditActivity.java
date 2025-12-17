package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;

/**
 * Activity for editing song files.
 */
public class SongEditActivity extends Activity {

    public static final int RESULT_DELETED = 2;

    private LinearLayout rootLayout;
    private LinearLayout headerLayout;
    private TextView titleText;
    private EditText songEditor;
    private Button cancelBtn;
    private Button saveBtn;
    private Button themeBtn;
    private Button formatBtn;
    private Button deleteBtn;
    private Button accidentalBtn;
    private String songPath;
    private String originalContent;
    private boolean isInlineMode = true; // Track current format (inline = ChordPro style)
    private boolean useSharps = true; // Track current accidental style

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_song_edit);

        rootLayout = (LinearLayout) findViewById(R.id.editRootLayout);
        headerLayout = (LinearLayout) findViewById(R.id.editHeaderLayout);
        titleText = (TextView) findViewById(R.id.editTitleText);
        songEditor = (EditText) findViewById(R.id.songEditor);
        cancelBtn = (Button) findViewById(R.id.cancelBtn);
        saveBtn = (Button) findViewById(R.id.saveBtn);
        themeBtn = (Button) findViewById(R.id.themeBtn);
        formatBtn = (Button) findViewById(R.id.formatBtn);
        deleteBtn = (Button) findViewById(R.id.deleteBtn);
        accidentalBtn = (Button) findViewById(R.id.accidentalBtn);

        applyThemeColors();
        updateThemeButton();

        formatBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleChordFormat();
            }
        });

        themeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleTheme();
            }
        });

        deleteBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmDelete();
            }
        });

        accidentalBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleAccidentals();
            }
        });

        songPath = getIntent().getStringExtra("songPath");
        if (songPath == null) {
            Toast.makeText(this, "No song path provided", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        loadSong();

        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                checkUnsavedChanges();
            }
        });

        saveBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                saveSong();
            }
        });
    }

    private void applyThemeColors() {
        if (ThemeManager.isDarkMode(this)) {
            rootLayout.setBackgroundColor(getResources().getColor(R.color.background_dark));
            headerLayout.setBackgroundColor(getResources().getColor(R.color.header_background_dark));
            titleText.setTextColor(getResources().getColor(R.color.text_primary_dark));
            songEditor.setBackgroundColor(getResources().getColor(R.color.editor_background_dark));
            songEditor.setTextColor(getResources().getColor(R.color.editor_text_dark));
        } else {
            rootLayout.setBackgroundColor(getResources().getColor(R.color.background_light));
            headerLayout.setBackgroundColor(getResources().getColor(R.color.header_background_light));
            titleText.setTextColor(getResources().getColor(R.color.text_primary_light));
            songEditor.setBackgroundColor(getResources().getColor(R.color.editor_background_light));
            songEditor.setTextColor(getResources().getColor(R.color.editor_text_light));
        }
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

    private void loadSong() {
        try {
            File file = new File(songPath);
            StringBuilder content = new StringBuilder();
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(new FileInputStream(file), "UTF-8"));
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            reader.close();

            originalContent = content.toString();
            songEditor.setText(originalContent);

            // Detect initial format and update button
            isInlineMode = ChordFormatConverter.isInlineFormat(originalContent);
            updateFormatButton();

            // Detect initial accidental style and update button
            useSharps = AccidentalConverter.isSharpsFormat(originalContent);
            updateAccidentalButton();
        } catch (Exception e) {
            Toast.makeText(this, "Error loading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            finish();
        }
    }

    private void toggleChordFormat() {
        String content = songEditor.getText().toString();
        String converted;

        // Save cursor position
        int cursorPos = songEditor.getSelectionStart();

        if (isInlineMode) {
            // Convert inline -> above
            converted = ChordFormatConverter.inlineToAbove(content);
            isInlineMode = false;
        } else {
            // Convert above -> inline
            converted = ChordFormatConverter.aboveToInline(content);
            isInlineMode = true;
        }

        songEditor.setText(converted);
        // Restore cursor position (approximately)
        songEditor.setSelection(Math.min(cursorPos, converted.length()));
        updateFormatButton();
    }

    private void updateFormatButton() {
        // Button shows what you'll convert TO when clicked
        if (isInlineMode) {
            formatBtn.setText("Above");
        } else {
            formatBtn.setText("Inline");
        }
    }

    private void saveSong() {
        String newContent = songEditor.getText().toString();

        // Check if content is empty/whitespace only
        if (newContent.trim().isEmpty()) {
            confirmDeleteEmptySong();
            return;
        }

        try {
            File file = new File(songPath);
            OutputStreamWriter writer = new OutputStreamWriter(
                new FileOutputStream(file), "UTF-8");
            writer.write(newContent);
            writer.close();

            originalContent = newContent;
            Toast.makeText(this, "Song saved", Toast.LENGTH_SHORT).show();
            setResult(RESULT_OK);
            finish();
        } catch (Exception e) {
            Toast.makeText(this, "Error saving: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void confirmDelete() {
        new AlertDialog.Builder(this)
            .setTitle("Delete Song")
            .setMessage("Delete this song?\n\nThis cannot be undone.")
            .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    deleteSong();
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
    }

    private void deleteSong() {
        File file = new File(songPath);
        if (file.delete()) {
            // Remove song from all setlists
            SetListDbHelper dbHelper = SetListDbHelper.getInstance(this);
            int removedFromSetlists = dbHelper.removeSongFromAllSetLists(songPath);

            String message = "Song deleted";
            if (removedFromSetlists > 0) {
                message += " (removed from " + removedFromSetlists + " setlist" +
                    (removedFromSetlists > 1 ? "s" : "") + ")";
            }
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show();

            Intent resultIntent = new Intent();
            resultIntent.putExtra("deletedPath", songPath);
            setResult(RESULT_DELETED, resultIntent);
            finish();
        } else {
            Toast.makeText(this, "Could not delete file", Toast.LENGTH_SHORT).show();
        }
    }

    private void confirmDeleteEmptySong() {
        new AlertDialog.Builder(this)
            .setTitle("Empty Song")
            .setMessage("This song is empty. Delete it?")
            .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    deleteSong();
                }
            })
            .setNegativeButton("Keep Empty", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    saveEmptySong();
                }
            })
            .setNeutralButton("Cancel", null)
            .show();
    }

    private void saveEmptySong() {
        try {
            String newContent = songEditor.getText().toString();
            File file = new File(songPath);
            OutputStreamWriter writer = new OutputStreamWriter(
                new FileOutputStream(file), "UTF-8");
            writer.write(newContent);
            writer.close();
            originalContent = newContent;
            Toast.makeText(this, "Song saved", Toast.LENGTH_SHORT).show();
            setResult(RESULT_OK);
            finish();
        } catch (Exception e) {
            Toast.makeText(this, "Error saving: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void toggleAccidentals() {
        String content = songEditor.getText().toString();
        int cursorPos = songEditor.getSelectionStart();

        String converted;
        if (useSharps) {
            // Currently sharps, convert to flats
            converted = AccidentalConverter.convertToFlats(content);
            useSharps = false;
        } else {
            // Currently flats, convert to sharps
            converted = AccidentalConverter.convertToSharps(content);
            useSharps = true;
        }

        songEditor.setText(converted);
        songEditor.setSelection(Math.min(cursorPos, converted.length()));
        updateAccidentalButton();
    }

    private void updateAccidentalButton() {
        // Show what you'll convert TO when clicked
        if (useSharps) {
            accidentalBtn.setText("-> b");
        } else {
            accidentalBtn.setText("-> #");
        }
    }

    private boolean hasUnsavedChanges() {
        String currentContent = songEditor.getText().toString();
        return !currentContent.equals(originalContent);
    }

    private void checkUnsavedChanges() {
        if (hasUnsavedChanges()) {
            new AlertDialog.Builder(this)
                .setTitle("Unsaved Changes")
                .setMessage("Discard changes?")
                .setPositiveButton("Discard", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        setResult(RESULT_CANCELED);
                        finish();
                    }
                })
                .setNegativeButton("Keep Editing", null)
                .show();
        } else {
            setResult(RESULT_CANCELED);
            finish();
        }
    }

    @Override
    public void onBackPressed() {
        checkUnsavedChanges();
    }
}

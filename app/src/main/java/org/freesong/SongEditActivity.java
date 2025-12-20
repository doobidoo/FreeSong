package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.Layout;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
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
    private Button helpBtn;
    private Button fontUpBtn;
    private Button fontDownBtn;
    private String songPath;
    private String originalContent;
    private boolean isInlineMode = true; // Track current format (inline = ChordPro style)
    private boolean useSharps = true; // Track current accidental style
    private float fontSize = 14f; // Default editor font size
    private static final String PREFS_NAME = "FreeSongEditorPrefs";
    private static final String PREF_FONT_SIZE = "editorFontSize";

    // Floating toolbar for chord movement
    private PopupWindow chordMovePopup;
    private View chordMoveToolbar;
    private TextView chordLabel;
    private int currentChordStart = -1;
    private int currentChordEnd = -1;
    private String currentChord = null;
    private boolean inlineModeHintShown = false;

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

        helpBtn = (Button) findViewById(R.id.helpBtn);
        helpBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showChordHelp();
            }
        });

        // Font size buttons
        fontUpBtn = (Button) findViewById(R.id.fontUpBtn);
        fontDownBtn = (Button) findViewById(R.id.fontDownBtn);

        fontUpBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                changeFontSize(2);
            }
        });

        fontDownBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                changeFontSize(-2);
            }
        });

        // Load saved font size
        loadFontSize();

        songPath = getIntent().getStringExtra("songPath");
        if (songPath == null) {
            Toast.makeText(this, "No song path provided", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        loadSong();

        // Initialize floating chord move toolbar
        initChordMoveToolbar();

        // Listen for cursor position changes to detect chords
        songEditor.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                // Check chord at current cursor position after text changes
                songEditor.post(new Runnable() {
                    @Override
                    public void run() {
                        checkForChordAtCursor();
                    }
                });
            }
        });

        // Also check on selection change (cursor movement without typing)
        songEditor.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                checkForChordAtCursor();
            }
        });

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

    private void showChordHelp() {
        new AlertDialog.Builder(this)
            .setTitle(R.string.chord_help_title)
            .setMessage(R.string.chord_help_content)
            .setPositiveButton(R.string.ok, null)
            .show();
    }

    // ========== Floating Chord Move Toolbar ==========

    private void initChordMoveToolbar() {
        LayoutInflater inflater = LayoutInflater.from(this);
        chordMoveToolbar = inflater.inflate(R.layout.chord_move_toolbar, null);

        chordLabel = (TextView) chordMoveToolbar.findViewById(R.id.chordLabel);
        Button moveWordLeftBtn = (Button) chordMoveToolbar.findViewById(R.id.moveWordLeftBtn);
        Button moveCharLeftBtn = (Button) chordMoveToolbar.findViewById(R.id.moveCharLeftBtn);
        Button moveCharRightBtn = (Button) chordMoveToolbar.findViewById(R.id.moveCharRightBtn);
        Button moveWordRightBtn = (Button) chordMoveToolbar.findViewById(R.id.moveWordRightBtn);

        moveWordLeftBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                moveChord(-1, true); // Move left by word
            }
        });

        moveCharLeftBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                moveChord(-1, false); // Move left by char
            }
        });

        moveCharRightBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                moveChord(1, false); // Move right by char
            }
        });

        moveWordRightBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                moveChord(1, true); // Move right by word
            }
        });

        chordMovePopup = new PopupWindow(
            chordMoveToolbar,
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
            false // Not focusable - allow EditText to keep focus
        );
        chordMovePopup.setOutsideTouchable(false);
    }

    private void checkForChordAtCursor() {
        String text = songEditor.getText().toString();
        int cursorPos = songEditor.getSelectionStart();

        if (cursorPos < 0 || cursorPos > text.length()) {
            hideChordMoveToolbar();
            return;
        }

        // Find chord at or near cursor position
        int[] chordBounds = findChordAtPosition(text, cursorPos);
        if (chordBounds != null) {
            if (!isInlineMode) {
                // Chord move toolbar only works in inline mode - show hint once
                hideChordMoveToolbar();
                if (!inlineModeHintShown) {
                    Toast.makeText(this, "Akkord-Verschiebung: Wechsle zu 'Inline' Format", Toast.LENGTH_SHORT).show();
                    inlineModeHintShown = true;
                }
                return;
            }
            currentChordStart = chordBounds[0];
            currentChordEnd = chordBounds[1];
            currentChord = text.substring(currentChordStart, currentChordEnd);
            showChordMoveToolbar();
        } else {
            hideChordMoveToolbar();
        }
    }

    /**
     * Find inline chord [xxx] at or touching the given position.
     * Returns int[2] with {start, end} or null if no chord found.
     */
    private int[] findChordAtPosition(String text, int pos) {
        // Search backwards for '[' and forwards for ']'
        int bracketStart = -1;
        int bracketEnd = -1;

        // Look backwards for '['
        for (int i = pos; i >= 0; i--) {
            char c = text.charAt(i);
            if (c == '[') {
                bracketStart = i;
                break;
            } else if (c == ']' || c == '\n') {
                // Hit end of another chord or newline before finding start
                break;
            }
        }

        if (bracketStart < 0) {
            // Also check if cursor is right after ']' - might want to edit that chord
            if (pos > 0 && text.charAt(pos - 1) == ']') {
                // Find the matching '['
                for (int i = pos - 2; i >= 0; i--) {
                    if (text.charAt(i) == '[') {
                        bracketStart = i;
                        bracketEnd = pos;
                        break;
                    } else if (text.charAt(i) == '\n') {
                        break;
                    }
                }
            }
            if (bracketStart < 0) {
                return null;
            }
        }

        if (bracketEnd < 0) {
            // Look forwards for ']'
            for (int i = Math.max(pos, bracketStart + 1); i < text.length(); i++) {
                char c = text.charAt(i);
                if (c == ']') {
                    bracketEnd = i + 1;
                    break;
                } else if (c == '[' || c == '\n') {
                    // Hit start of another chord or newline
                    break;
                }
            }
        }

        if (bracketStart >= 0 && bracketEnd > bracketStart) {
            return new int[]{bracketStart, bracketEnd};
        }
        return null;
    }

    private void showChordMoveToolbar() {
        if (currentChord == null || chordMovePopup == null) return;

        chordLabel.setText(currentChord);

        // Calculate position above the cursor
        Layout layout = songEditor.getLayout();
        if (layout == null) return;

        int line = layout.getLineForOffset(currentChordStart);
        int baseline = layout.getLineBaseline(line);
        int ascent = layout.getLineAscent(line);

        // Get EditText location on screen
        int[] editorLocation = new int[2];
        songEditor.getLocationOnScreen(editorLocation);

        // Calculate x position (centered on chord)
        float xPos = layout.getPrimaryHorizontal(currentChordStart);
        int x = editorLocation[0] + (int) xPos + songEditor.getPaddingLeft() - songEditor.getScrollX();

        // Calculate y position (above the line)
        int y = editorLocation[1] + baseline + ascent - songEditor.getScrollY() + songEditor.getPaddingTop();
        y -= 50; // Offset above the text

        // Show or update popup
        if (chordMovePopup.isShowing()) {
            chordMovePopup.update(x, y, -1, -1);
        } else {
            chordMovePopup.showAtLocation(songEditor, Gravity.NO_GRAVITY, x, y);
        }
    }

    private void hideChordMoveToolbar() {
        if (chordMovePopup != null && chordMovePopup.isShowing()) {
            chordMovePopup.dismiss();
        }
        currentChordStart = -1;
        currentChordEnd = -1;
        currentChord = null;
    }

    /**
     * Move the current chord left or right.
     * @param direction -1 for left, +1 for right
     * @param byWord true to move by word boundary, false for single character
     */
    private void moveChord(int direction, boolean byWord) {
        if (currentChord == null || currentChordStart < 0 || currentChordEnd < 0) return;

        String text = songEditor.getText().toString();
        int chordLength = currentChord.length();

        // Find line boundaries in original text
        int lineStart = text.lastIndexOf('\n', currentChordStart - 1) + 1;
        int lineEnd = text.indexOf('\n', currentChordStart);
        if (lineEnd < 0) lineEnd = text.length();

        // First, remove the chord to get the "base" text
        String textWithoutChord = text.substring(0, currentChordStart) + text.substring(currentChordEnd);
        int lineEndWithoutChord = lineEnd - chordLength;

        // Calculate new position in the text WITHOUT the chord
        int newPosInBase;
        if (byWord) {
            // For word movement, find boundary in original text then convert
            int wordBoundary = findWordBoundary(text, currentChordStart, direction);
            // Convert to position in base text
            if (wordBoundary >= currentChordEnd) {
                newPosInBase = wordBoundary - chordLength;
            } else if (wordBoundary <= currentChordStart) {
                newPosInBase = wordBoundary;
            } else {
                newPosInBase = currentChordStart; // Was inside chord
            }
        } else {
            // Simple char movement
            if (direction < 0) {
                newPosInBase = currentChordStart - 1;
            } else {
                newPosInBase = currentChordStart + 1;
            }
        }

        // Clamp to line boundaries (in base text)
        int lineStartInBase = textWithoutChord.lastIndexOf('\n', Math.max(0, currentChordStart - 1)) + 1;
        if (newPosInBase < lineStartInBase) newPosInBase = lineStartInBase;
        if (newPosInBase > lineEndWithoutChord) newPosInBase = lineEndWithoutChord;

        // Check if there's actual movement
        if (newPosInBase == currentChordStart) return;

        // Insert chord at new position
        StringBuilder sb = new StringBuilder(textWithoutChord);
        sb.insert(newPosInBase, currentChord);

        // Update editor
        songEditor.setText(sb.toString());

        // Update chord bounds and cursor
        currentChordStart = newPosInBase;
        currentChordEnd = newPosInBase + chordLength;
        songEditor.setSelection(currentChordStart + 1); // Position cursor inside chord

        // Refresh toolbar position
        showChordMoveToolbar();
    }

    /**
     * Find next word boundary in the given direction.
     * Word boundaries are: spaces, start/end of line.
     */
    private int findWordBoundary(String text, int pos, int direction) {
        int lineStart = text.lastIndexOf('\n', pos - 1) + 1;
        int lineEnd = text.indexOf('\n', pos);
        if (lineEnd < 0) lineEnd = text.length();

        if (direction < 0) {
            // Moving left - find previous word start
            int searchPos = pos - 1;

            // Skip any spaces
            while (searchPos > lineStart && text.charAt(searchPos) == ' ') {
                searchPos--;
            }

            // Skip chord brackets if present
            if (searchPos > lineStart && text.charAt(searchPos) == '[') {
                searchPos--;
            }
            while (searchPos > lineStart && text.charAt(searchPos) == ' ') {
                searchPos--;
            }

            // Find start of word (or previous chord)
            while (searchPos > lineStart) {
                char c = text.charAt(searchPos - 1);
                if (c == ' ' || c == ']') {
                    break;
                }
                searchPos--;
            }
            return searchPos;
        } else {
            // Moving right - find next word start
            int searchPos = pos + 1;

            // Skip current chord
            while (searchPos < lineEnd && text.charAt(searchPos) != ']') {
                searchPos++;
            }
            if (searchPos < lineEnd && text.charAt(searchPos) == ']') {
                searchPos++;
            }

            // Skip any spaces
            while (searchPos < lineEnd && text.charAt(searchPos) == ' ') {
                searchPos++;
            }

            // Skip any word characters until next space or chord
            while (searchPos < lineEnd) {
                char c = text.charAt(searchPos);
                if (c == ' ' || c == '[') {
                    break;
                }
                searchPos++;
            }

            // Skip trailing spaces
            while (searchPos < lineEnd && text.charAt(searchPos) == ' ') {
                searchPos++;
            }

            return searchPos;
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        hideChordMoveToolbar();
    }

    // ========== End Floating Chord Move Toolbar ==========

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

    // ========== Font Size ==========

    private void loadFontSize() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        fontSize = prefs.getFloat(PREF_FONT_SIZE, 14f);
        applyFontSize();
    }

    private void saveFontSize() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        prefs.edit().putFloat(PREF_FONT_SIZE, fontSize).apply();
    }

    private void changeFontSize(float delta) {
        fontSize = Math.max(10, Math.min(32, fontSize + delta));
        applyFontSize();
        saveFontSize();
    }

    private void applyFontSize() {
        songEditor.setTextSize(fontSize);
    }
}

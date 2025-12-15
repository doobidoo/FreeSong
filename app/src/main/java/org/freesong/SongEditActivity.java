package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
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

    private EditText songEditor;
    private Button cancelBtn;
    private Button saveBtn;
    private String songPath;
    private String originalContent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_song_edit);

        songEditor = (EditText) findViewById(R.id.songEditor);
        cancelBtn = (Button) findViewById(R.id.cancelBtn);
        saveBtn = (Button) findViewById(R.id.saveBtn);

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
        } catch (Exception e) {
            Toast.makeText(this, "Error loading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            finish();
        }
    }

    private void saveSong() {
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

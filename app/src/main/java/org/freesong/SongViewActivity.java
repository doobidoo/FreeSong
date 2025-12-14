package org.freesong;

import android.app.Activity;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.StyleSpan;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;

/**
 * Activity for viewing and interacting with a song.
 */
public class SongViewActivity extends Activity {

    private Song song;
    private int transposition = 0;
    private boolean autoScrolling = false;
    private int scrollSpeed = 50; // pixels per second
    private float fontSize = 18f;

    private TextView titleText;
    private TextView artistText;
    private TextView keyText;
    private TextView songContent;
    private ScrollView scrollView;
    private Button transposeUpBtn;
    private Button transposeDownBtn;
    private Button autoScrollBtn;
    private Button fontUpBtn;
    private Button fontDownBtn;
    private SeekBar speedSeekBar;

    private Handler scrollHandler = new Handler();
    private GestureDetector gestureDetector;

    private int chordColor;
    private int sectionColor;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyFullscreenTheme(this);
        setContentView(R.layout.activity_song_view);

        // Keep screen on
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        // Set theme-aware colors
        if (ThemeManager.isDarkMode(this)) {
            chordColor = getResources().getColor(R.color.chord_color_dark);
            sectionColor = getResources().getColor(R.color.section_color_dark);
        } else {
            chordColor = getResources().getColor(R.color.chord_color_light);
            sectionColor = getResources().getColor(R.color.section_color_light);
        }

        initViews();
        loadSong();
        setupGestures();
    }

    private void initViews() {
        titleText = (TextView) findViewById(R.id.titleText);
        artistText = (TextView) findViewById(R.id.artistText);
        keyText = (TextView) findViewById(R.id.keyText);
        songContent = (TextView) findViewById(R.id.songContent);
        scrollView = (ScrollView) findViewById(R.id.scrollView);
        transposeUpBtn = (Button) findViewById(R.id.transposeUpBtn);
        transposeDownBtn = (Button) findViewById(R.id.transposeDownBtn);
        autoScrollBtn = (Button) findViewById(R.id.autoScrollBtn);
        fontUpBtn = (Button) findViewById(R.id.fontUpBtn);
        fontDownBtn = (Button) findViewById(R.id.fontDownBtn);
        speedSeekBar = (SeekBar) findViewById(R.id.speedSeekBar);

        transposeUpBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                transpose(1);
            }
        });

        transposeDownBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                transpose(-1);
            }
        });

        autoScrollBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleAutoScroll();
            }
        });

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

        speedSeekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                scrollSpeed = 10 + progress * 2; // 10-210 pixels per second
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        speedSeekBar.setProgress(20); // Default medium speed
    }

    private void loadSong() {
        String songPath = getIntent().getStringExtra("songPath");
        if (songPath == null) {
            Toast.makeText(this, "No song path provided", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        try {
            song = SongParser.parseFile(new File(songPath));
            displaySong();
        } catch (Exception e) {
            Toast.makeText(this, "Error loading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            finish();
        }
    }

    private void displaySong() {
        titleText.setText(song.getTitle());
        artistText.setText(song.getArtist());
        updateKeyDisplay();

        SpannableStringBuilder content = new SpannableStringBuilder();

        for (Song.SongSection section : song.getSections()) {
            // Section label
            if (!section.getLabel().isEmpty()) {
                int start = content.length();
                content.append("[").append(section.getLabel()).append("]\n");
                content.setSpan(new ForegroundColorSpan(sectionColor), start, content.length(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                content.setSpan(new StyleSpan(Typeface.BOLD), start, content.length(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            }

            for (Song.SongLine line : section.getLines()) {
                // Build chord line
                if (!line.getChords().isEmpty()) {
                    StringBuilder chordLine = new StringBuilder();
                    int lastPos = 0;
                    for (Song.ChordPosition cp : line.getChords()) {
                        // Pad with spaces to reach position
                        while (chordLine.length() < cp.getPosition()) {
                            chordLine.append(" ");
                        }
                        chordLine.append(cp.getChord());
                    }
                    if (chordLine.length() > 0) {
                        int start = content.length();
                        content.append(chordLine.toString()).append("\n");
                        content.setSpan(new ForegroundColorSpan(chordColor), start, content.length(),
                            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                        content.setSpan(new StyleSpan(Typeface.BOLD), start, content.length(),
                            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                    }
                }

                // Lyrics line
                content.append(line.getLyrics()).append("\n");
            }

            content.append("\n");
        }

        songContent.setText(content);
        songContent.setTextSize(fontSize);
    }

    private void updateKeyDisplay() {
        String key = song.getKey();
        if (key != null && !key.isEmpty()) {
            String display = "Key: " + key;
            if (transposition != 0) {
                display += " (" + Transposer.getTranspositionName(transposition) + ")";
            }
            keyText.setText(display);
            keyText.setVisibility(View.VISIBLE);
        } else {
            keyText.setVisibility(View.GONE);
        }
    }

    private void transpose(int semitones) {
        transposition += semitones;
        Transposer.transposeSong(song, semitones);
        displaySong();
        Toast.makeText(this, "Transposed " + Transposer.getTranspositionName(transposition),
            Toast.LENGTH_SHORT).show();
    }

    private void toggleAutoScroll() {
        autoScrolling = !autoScrolling;
        if (autoScrolling) {
            autoScrollBtn.setText("Stop");
            startAutoScroll();
        } else {
            autoScrollBtn.setText("Scroll");
            stopAutoScroll();
        }
    }

    private Runnable scrollRunnable = new Runnable() {
        @Override
        public void run() {
            if (autoScrolling) {
                scrollView.smoothScrollBy(0, 1);
                scrollHandler.postDelayed(this, 1000 / scrollSpeed);
            }
        }
    };

    private void startAutoScroll() {
        scrollHandler.post(scrollRunnable);
    }

    private void stopAutoScroll() {
        scrollHandler.removeCallbacks(scrollRunnable);
    }

    private void changeFontSize(float delta) {
        fontSize = Math.max(12, Math.min(36, fontSize + delta));
        songContent.setTextSize(fontSize);
    }

    private void setupGestures() {
        gestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onDoubleTap(MotionEvent e) {
                toggleAutoScroll();
                return true;
            }
        });

        scrollView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                gestureDetector.onTouchEvent(event);
                // Stop auto-scroll on user interaction
                if (autoScrolling && event.getAction() == MotionEvent.ACTION_DOWN) {
                    toggleAutoScroll();
                }
                return false;
            }
        });
    }

    @Override
    protected void onPause() {
        super.onPause();
        stopAutoScroll();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        stopAutoScroll();
    }
}

package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Typeface;
import android.view.KeyEvent;
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
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;

/**
 * Activity for viewing and interacting with a song.
 */
public class SongViewActivity extends Activity {

    private static final int REQUEST_EDIT = 200;

    private Song song;
    private String songPath;
    private int transposition = 0;
    private boolean autoScrolling = false;
    private int scrollSpeed = 50; // pixels per second
    private float fontSize = 18f;
    private boolean speedBarVisible = true;
    private String pageTurnerMode = "scroll"; // "scroll" or "navigate"

    // Setlist navigation support
    private ArrayList<String> setlistPaths;
    private int currentIndex = -1;

    // Layout views for theme coloring
    private LinearLayout rootLayout;
    private LinearLayout headerLayout;
    private LinearLayout controlBar;
    private LinearLayout speedBar;

    private TextView titleText;
    private TextView artistText;
    private TextView keyText;
    private TextView keyLabel;
    private TextView speedLabel;
    private TextView songContent;
    private ScrollView scrollView;
    private Button transposeUpBtn;
    private Button transposeDownBtn;
    private Button autoScrollBtn;
    private Button editBtn;
    private Button fontUpBtn;
    private Button fontDownBtn;
    private Button scrollBarBtn;
    private Button themeBtn;
    private Button pedalBtn;
    private SeekBar speedSeekBar;

    private Handler scrollHandler = new Handler();
    private GestureDetector gestureDetector;

    private int chordColor;
    private int sectionColor;
    private int keyColor;
    private boolean isDarkMode;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyFullscreenTheme(this);
        setContentView(R.layout.activity_song_view);

        // Restore state from savedInstanceState if available (e.g., after theme toggle)
        if (savedInstanceState != null) {
            setlistPaths = savedInstanceState.getStringArrayList("setlistPaths");
            currentIndex = savedInstanceState.getInt("currentIndex", -1);
            songPath = savedInstanceState.getString("songPath");
            transposition = savedInstanceState.getInt("transposition", 0);
            fontSize = savedInstanceState.getFloat("fontSize", 18f);
            scrollSpeed = savedInstanceState.getInt("scrollSpeed", 50);
        }

        // Restore speed bar visibility from preferences (persists across app exits)
        speedBarVisible = ThemeManager.isSpeedBarVisible(this);

        // Load page turner mode from preferences
        pageTurnerMode = ThemeManager.getPageTurnerMode(this);

        // Keep screen on
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        // Set theme-aware colors
        isDarkMode = ThemeManager.isDarkMode(this);
        if (isDarkMode) {
            chordColor = getResources().getColor(R.color.chord_color_dark);
            sectionColor = getResources().getColor(R.color.section_color_dark);
            keyColor = getResources().getColor(R.color.key_color_dark);
        } else {
            chordColor = getResources().getColor(R.color.chord_color_light);
            sectionColor = getResources().getColor(R.color.section_color_light);
            keyColor = getResources().getColor(R.color.key_color_light);
        }

        initViews();
        applyThemeColors();

        // Apply restored speed bar visibility state
        speedBar.setVisibility(speedBarVisible ? View.VISIBLE : View.GONE);
        scrollBarBtn.setText(speedBarVisible ? "▼" : "▲");

        // Restore scroll speed to seekbar
        if (savedInstanceState != null) {
            speedSeekBar.setProgress((scrollSpeed - 10) / 2);
        }

        loadSong();
        setupGestures();

        // Restore scroll position after view is laid out
        if (savedInstanceState != null) {
            final int scrollPosition = savedInstanceState.getInt("scrollPosition", 0);
            scrollView.post(new Runnable() {
                @Override
                public void run() {
                    scrollView.scrollTo(0, scrollPosition);
                }
            });
        }
    }

    private void initViews() {
        // Layout containers for theme coloring
        rootLayout = (LinearLayout) findViewById(R.id.rootLayout);
        headerLayout = (LinearLayout) findViewById(R.id.headerLayout);
        controlBar = (LinearLayout) findViewById(R.id.controlBar);
        speedBar = (LinearLayout) findViewById(R.id.speedBar);

        titleText = (TextView) findViewById(R.id.titleText);
        artistText = (TextView) findViewById(R.id.artistText);
        keyText = (TextView) findViewById(R.id.keyText);
        keyLabel = (TextView) findViewById(R.id.keyLabel);
        speedLabel = (TextView) findViewById(R.id.speedLabel);
        songContent = (TextView) findViewById(R.id.songContent);
        scrollView = (ScrollView) findViewById(R.id.scrollView);
        transposeUpBtn = (Button) findViewById(R.id.transposeUpBtn);
        transposeDownBtn = (Button) findViewById(R.id.transposeDownBtn);
        autoScrollBtn = (Button) findViewById(R.id.autoScrollBtn);
        editBtn = (Button) findViewById(R.id.editBtn);
        fontUpBtn = (Button) findViewById(R.id.fontUpBtn);
        fontDownBtn = (Button) findViewById(R.id.fontDownBtn);
        scrollBarBtn = (Button) findViewById(R.id.scrollBarBtn);
        themeBtn = (Button) findViewById(R.id.themeBtn);
        pedalBtn = (Button) findViewById(R.id.pedalBtn);
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

        editBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openEditor();
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

        scrollBarBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleSpeedBar();
            }
        });

        themeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleTheme();
            }
        });

        pedalBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showPageTurnerSettings();
            }
        });

        updateThemeButton();

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

    private void applyThemeColors() {
        if (isDarkMode) {
            rootLayout.setBackgroundColor(getResources().getColor(R.color.background_dark));
            headerLayout.setBackgroundColor(getResources().getColor(R.color.header_background_dark));
            controlBar.setBackgroundColor(getResources().getColor(R.color.control_bar_dark));
            speedBar.setBackgroundColor(getResources().getColor(R.color.speed_bar_dark));
            titleText.setTextColor(getResources().getColor(R.color.text_primary_dark));
            artistText.setTextColor(getResources().getColor(R.color.text_secondary_dark));
            keyLabel.setTextColor(getResources().getColor(R.color.text_secondary_dark));
            speedLabel.setTextColor(getResources().getColor(R.color.text_secondary_dark));
            songContent.setTextColor(getResources().getColor(R.color.text_primary_dark));
        } else {
            rootLayout.setBackgroundColor(getResources().getColor(R.color.background_light));
            headerLayout.setBackgroundColor(getResources().getColor(R.color.header_background_light));
            controlBar.setBackgroundColor(getResources().getColor(R.color.control_bar_light));
            speedBar.setBackgroundColor(getResources().getColor(R.color.speed_bar_light));
            titleText.setTextColor(getResources().getColor(R.color.text_primary_light));
            artistText.setTextColor(getResources().getColor(R.color.text_secondary_light));
            keyLabel.setTextColor(getResources().getColor(R.color.text_secondary_light));
            speedLabel.setTextColor(getResources().getColor(R.color.text_secondary_light));
            songContent.setTextColor(getResources().getColor(R.color.text_primary_light));
        }
        keyText.setTextColor(keyColor);
    }

    private void toggleSpeedBar() {
        speedBarVisible = !speedBarVisible;
        ThemeManager.setSpeedBarVisible(this, speedBarVisible);
        if (speedBarVisible) {
            speedBar.setVisibility(View.VISIBLE);
            scrollBarBtn.setText("▼");
        } else {
            speedBar.setVisibility(View.GONE);
            scrollBarBtn.setText("▲");
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

    private void openEditor() {
        Intent intent = new Intent(this, SongEditActivity.class);
        intent.putExtra("songPath", songPath);
        startActivityForResult(intent, REQUEST_EDIT);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_EDIT) {
            if (resultCode == RESULT_OK) {
                // Reload the song after editing
                transposition = 0;
                loadSong();
            } else if (resultCode == SongEditActivity.RESULT_DELETED) {
                // Song was deleted, close viewer and return to list
                setResult(RESULT_OK); // Signal refresh to MainActivity
                finish();
            }
        }
    }

    private void loadSong() {
        // Only read from Intent if not already set (from savedInstanceState)
        if (songPath == null) {
            songPath = getIntent().getStringExtra("songPath");
        }
        if (songPath == null) {
            Toast.makeText(this, "No song path provided", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        // Get setlist navigation info if not already restored
        if (setlistPaths == null) {
            setlistPaths = getIntent().getStringArrayListExtra("setlistPaths");
            currentIndex = getIntent().getIntExtra("currentIndex", -1);
        }

        try {
            song = SongParser.parseFile(new File(songPath));
            // Apply saved transposition if any
            if (transposition != 0) {
                Transposer.transposeSong(song, transposition);
            }
            displaySong();
        } catch (Exception e) {
            Toast.makeText(this, "Error loading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            finish();
        }
    }

    private void loadSongAtIndex(int index) {
        if (setlistPaths == null || index < 0 || index >= setlistPaths.size()) {
            return;
        }

        currentIndex = index;
        songPath = setlistPaths.get(index);
        transposition = 0;

        try {
            song = SongParser.parseFile(new File(songPath));
            displaySong();
            scrollView.scrollTo(0, 0);
        } catch (Exception e) {
            Toast.makeText(this, "Error loading song: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void navigatePrevious() {
        if (setlistPaths != null && currentIndex > 0) {
            loadSongAtIndex(currentIndex - 1);
        }
    }

    private void navigateNext() {
        if (setlistPaths != null && currentIndex < setlistPaths.size() - 1) {
            loadSongAtIndex(currentIndex + 1);
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
                    for (Song.ChordPosition cp : line.getChords()) {
                        int targetPos = cp.getPosition();
                        int currentLen = chordLine.length();

                        if (currentLen < targetPos) {
                            // Pad with spaces to reach target position
                            while (chordLine.length() < targetPos) {
                                chordLine.append(" ");
                            }
                        } else if (currentLen > targetPos) {
                            // Previous chord overlaps - add single space separator
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
            private static final int SWIPE_THRESHOLD = 100;
            private static final int SWIPE_VELOCITY_THRESHOLD = 100;

            @Override
            public boolean onDoubleTap(MotionEvent e) {
                toggleAutoScroll();
                return true;
            }

            @Override
            public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
                // Only handle horizontal swipes for navigation when in setlist mode
                if (setlistPaths == null || e1 == null || e2 == null) {
                    return false;
                }

                float diffX = e2.getX() - e1.getX();
                float diffY = e2.getY() - e1.getY();

                // Check if horizontal swipe (more horizontal than vertical)
                if (Math.abs(diffX) > Math.abs(diffY)) {
                    if (Math.abs(diffX) > SWIPE_THRESHOLD && Math.abs(velocityX) > SWIPE_VELOCITY_THRESHOLD) {
                        if (diffX > 0) {
                            // Swipe right = previous song
                            navigatePrevious();
                        } else {
                            // Swipe left = next song
                            navigateNext();
                        }
                        return true;
                    }
                }
                return false;
            }

            @Override
            public boolean onSingleTapConfirmed(MotionEvent e) {
                // Tap on left/right edge for navigation in setlist mode
                if (setlistPaths == null) {
                    return false;
                }

                int screenWidth = scrollView.getWidth();
                float x = e.getX();

                if (x < screenWidth * 0.15) {
                    // Tap on left 15% = previous
                    navigatePrevious();
                    return true;
                } else if (x > screenWidth * 0.85) {
                    // Tap on right 15% = next
                    navigateNext();
                    return true;
                }
                return false;
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

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        // Persist setlist navigation state
        if (setlistPaths != null) {
            outState.putStringArrayList("setlistPaths", setlistPaths);
            outState.putInt("currentIndex", currentIndex);
        }
        // Persist other view state
        outState.putString("songPath", songPath);
        outState.putInt("transposition", transposition);
        outState.putFloat("fontSize", fontSize);
        outState.putInt("scrollSpeed", scrollSpeed);
        outState.putInt("scrollPosition", scrollView.getScrollY());
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        // Only handle key down events
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = event.getKeyCode();

            switch (keyCode) {
                case KeyEvent.KEYCODE_PAGE_DOWN:
                case KeyEvent.KEYCODE_DPAD_DOWN:
                case KeyEvent.KEYCODE_SPACE:
                case KeyEvent.KEYCODE_ENTER:
                    handlePageTurnerDown();
                    return true;

                case KeyEvent.KEYCODE_PAGE_UP:
                case KeyEvent.KEYCODE_DPAD_UP:
                case KeyEvent.KEYCODE_DEL:
                    handlePageTurnerUp();
                    return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    // CubeTurner sends touch/swipe events instead of key events
    // In landscape mode it uses ABS_X, in portrait mode it uses ABS_Y
    private float cubeTurnerFirstX = -1;
    private float cubeTurnerFirstY = -1;
    private float cubeTurnerLastX = -1;
    private float cubeTurnerLastY = -1;
    private boolean cubeTurnerActive = false;

    // Smart mode: track if we're at the end and waiting for confirmation
    private boolean waitingForNextSong = false;
    private boolean waitingForPrevSong = false;

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        // Check if this is from an external device (like CubeTurner)
        if (event.getSource() != 0) {
            int action = event.getActionMasked();
            float x = event.getX();
            float y = event.getY();

            if (action == MotionEvent.ACTION_DOWN ||
                (action == MotionEvent.ACTION_MOVE && !cubeTurnerActive)) {
                // Start tracking both axes
                cubeTurnerFirstX = x;
                cubeTurnerFirstY = y;
                cubeTurnerActive = true;
            }

            if (action == MotionEvent.ACTION_MOVE) {
                cubeTurnerLastX = x;
                cubeTurnerLastY = y;
            }

            if (action == MotionEvent.ACTION_UP && cubeTurnerActive) {
                float deltaX = cubeTurnerLastX - cubeTurnerFirstX;
                float deltaY = cubeTurnerLastY - cubeTurnerFirstY;

                // Reset
                cubeTurnerActive = false;
                cubeTurnerFirstX = -1;
                cubeTurnerFirstY = -1;
                cubeTurnerLastX = -1;
                cubeTurnerLastY = -1;

                // Use the axis with the larger movement (landscape=X, portrait=Y)
                float delta = (Math.abs(deltaX) > Math.abs(deltaY)) ? deltaX : deltaY;

                if (delta > 50) {
                    // Positive delta = page down / next (right pedal)
                    handlePageTurnerDown();
                    return true;
                } else if (delta < -50) {
                    // Negative delta = page up / previous (left pedal)
                    handlePageTurnerUp();
                    return true;
                }
            }
        }
        return super.dispatchGenericMotionEvent(event);
    }

    private boolean isAtBottom() {
        if (scrollView.getChildAt(0) == null) return false;
        int diff = scrollView.getChildAt(0).getBottom() - (scrollView.getHeight() + scrollView.getScrollY());
        return diff <= 10; // small tolerance
    }

    private boolean isAtTop() {
        return scrollView.getScrollY() <= 10; // small tolerance
    }

    private void handlePageTurnerDown() {
        waitingForPrevSong = false; // Reset opposite direction

        if ("navigate".equals(pageTurnerMode)) {
            // Navigate mode: directly go to next song
            if (setlistPaths != null && currentIndex < setlistPaths.size() - 1) {
                navigateNext();
                Toast.makeText(this, "Nächster Song", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Letzter Song", Toast.LENGTH_SHORT).show();
            }
        } else if ("smart".equals(pageTurnerMode)) {
            // Smart mode: scroll until end, then confirm, then next song
            if (isAtBottom()) {
                if (waitingForNextSong) {
                    // Second press at bottom: go to next song
                    if (setlistPaths != null && currentIndex < setlistPaths.size() - 1) {
                        navigateNext();
                        Toast.makeText(this, "Nächster Song", Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(this, "Letzter Song erreicht", Toast.LENGTH_SHORT).show();
                    }
                    waitingForNextSong = false;
                } else {
                    // First press at bottom: show warning
                    waitingForNextSong = true;
                    Toast.makeText(this, "Ende - nochmal für nächsten Song", Toast.LENGTH_SHORT).show();
                }
            } else {
                // Not at bottom: scroll down
                int scrollAmount = scrollView.getHeight() - 100;
                scrollView.smoothScrollBy(0, scrollAmount);
                waitingForNextSong = false;
                Toast.makeText(this, "Seite runter", Toast.LENGTH_SHORT).show();
            }
        } else {
            // Scroll mode: just scroll down
            int scrollAmount = scrollView.getHeight() - 100;
            scrollView.smoothScrollBy(0, scrollAmount);
            Toast.makeText(this, "Seite runter", Toast.LENGTH_SHORT).show();
        }
    }

    private void handlePageTurnerUp() {
        waitingForNextSong = false; // Reset opposite direction

        if ("navigate".equals(pageTurnerMode)) {
            // Navigate mode: directly go to previous song
            if (setlistPaths != null && currentIndex > 0) {
                navigatePrevious();
                Toast.makeText(this, "Vorheriger Song", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Erster Song", Toast.LENGTH_SHORT).show();
            }
        } else if ("smart".equals(pageTurnerMode)) {
            // Smart mode: scroll until top, then confirm, then previous song
            if (isAtTop()) {
                if (waitingForPrevSong) {
                    // Second press at top: go to previous song
                    if (setlistPaths != null && currentIndex > 0) {
                        navigatePrevious();
                        Toast.makeText(this, "Vorheriger Song", Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(this, "Erster Song erreicht", Toast.LENGTH_SHORT).show();
                    }
                    waitingForPrevSong = false;
                } else {
                    // First press at top: show warning
                    waitingForPrevSong = true;
                    Toast.makeText(this, "Anfang - nochmal für vorherigen Song", Toast.LENGTH_SHORT).show();
                }
            } else {
                // Not at top: scroll up
                int scrollAmount = scrollView.getHeight() - 100;
                scrollView.smoothScrollBy(0, -scrollAmount);
                waitingForPrevSong = false;
                Toast.makeText(this, "Seite hoch", Toast.LENGTH_SHORT).show();
            }
        } else {
            // Scroll mode: just scroll up
            int scrollAmount = scrollView.getHeight() - 100;
            scrollView.smoothScrollBy(0, -scrollAmount);
            Toast.makeText(this, "Seite hoch", Toast.LENGTH_SHORT).show();
        }
    }

    private void showPageTurnerSettings() {
        final String[] options = {"Seite scrollen", "Song wechseln", "Smart (Scroll + Wechsel)"};
        final String[] modes = {"scroll", "navigate", "smart"};

        int currentSelection = 0;
        for (int i = 0; i < modes.length; i++) {
            if (modes[i].equals(pageTurnerMode)) {
                currentSelection = i;
                break;
            }
        }

        new AlertDialog.Builder(this)
            .setTitle("Fußpedal / Page Turner")
            .setSingleChoiceItems(options, currentSelection, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    pageTurnerMode = modes[which];
                    ThemeManager.setPageTurnerMode(SongViewActivity.this, pageTurnerMode);
                    // Reset waiting states when mode changes
                    waitingForNextSong = false;
                    waitingForPrevSong = false;
                    dialog.dismiss();
                    Toast.makeText(SongViewActivity.this,
                        "Pedal: " + options[which],
                        Toast.LENGTH_SHORT).show();
                }
            })
            .setNegativeButton("Abbrechen", null)
            .show();
    }
}

package org.freesong;

import java.util.ArrayList;
import java.util.List;

/**
 * Represents a song with metadata, lyrics and chords.
 */
public class Song {
    private String title = "";
    private String artist = "";
    private String key = "";
    private String tempo = "";
    private String ccli = "";
    private String copyright = "";
    private List<SongSection> sections = new ArrayList<SongSection>();
    private String rawContent = "";

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getArtist() { return artist; }
    public void setArtist(String artist) { this.artist = artist; }

    public String getKey() { return key; }
    public void setKey(String key) { this.key = key; }

    public String getTempo() { return tempo; }
    public void setTempo(String tempo) { this.tempo = tempo; }

    public String getCcli() { return ccli; }
    public void setCcli(String ccli) { this.ccli = ccli; }

    public String getCopyright() { return copyright; }
    public void setCopyright(String copyright) { this.copyright = copyright; }

    public List<SongSection> getSections() { return sections; }
    public void addSection(SongSection section) { sections.add(section); }

    public String getRawContent() { return rawContent; }
    public void setRawContent(String rawContent) { this.rawContent = rawContent; }

    /**
     * Represents a section of a song (Verse, Chorus, Bridge, etc.)
     */
    public static class SongSection {
        private String label = "";
        private List<SongLine> lines = new ArrayList<SongLine>();

        public String getLabel() { return label; }
        public void setLabel(String label) { this.label = label; }

        public List<SongLine> getLines() { return lines; }
        public void addLine(SongLine line) { lines.add(line); }
    }

    /**
     * Represents a line with lyrics and chord positions.
     */
    public static class SongLine {
        private String lyrics = "";
        private List<ChordPosition> chords = new ArrayList<ChordPosition>();

        public String getLyrics() { return lyrics; }
        public void setLyrics(String lyrics) { this.lyrics = lyrics; }

        public List<ChordPosition> getChords() { return chords; }
        public void addChord(ChordPosition chord) { chords.add(chord); }
    }

    /**
     * Represents a chord at a specific position in the lyrics.
     */
    public static class ChordPosition {
        private String chord;
        private int position;

        public ChordPosition(String chord, int position) {
            this.chord = chord;
            this.position = position;
        }

        public String getChord() { return chord; }
        public int getPosition() { return position; }
        public void setChord(String chord) { this.chord = chord; }
    }
}

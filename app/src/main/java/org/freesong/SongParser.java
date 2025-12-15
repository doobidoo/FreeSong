package org.freesong;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parser for OnSong and ChordPro file formats.
 */
public class SongParser {

    // Patterns for parsing
    private static final Pattern CHORD_PATTERN = Pattern.compile("\\[([^\\]]+)\\]");
    private static final Pattern CHORDPRO_TAG = Pattern.compile("\\{([^:}]+)(?::([^}]*))?\\}");
    private static final Pattern SECTION_LABEL = Pattern.compile("^(Verse|Chorus|Bridge|Pre-?Chorus|Intro|Outro|Tag|Interlude|Instrumental|Ending|Coda|Refrain|Strophe|Vamp)\\s*(\\d*):?\\s*$", Pattern.CASE_INSENSITIVE);
    // Pattern for standalone chord (e.g., C, Am, G7, F#m, Bb, Dm/A, Csus4)
    private static final Pattern SINGLE_CHORD = Pattern.compile("^[A-G](#|b)?(m|maj|min|dim|aug|sus|add)?(\\d+)?(/[A-G](#|b)?)?$");

    /**
     * Parse a song file.
     */
    public static Song parseFile(File file) throws IOException {
        StringBuilder content = new StringBuilder();
        BufferedReader reader = new BufferedReader(
            new InputStreamReader(new FileInputStream(file), "UTF-8"));
        String line;
        while ((line = reader.readLine()) != null) {
            content.append(line).append("\n");
        }
        reader.close();
        return parse(content.toString());
    }

    /**
     * Parse song content from string.
     */
    public static Song parse(String content) {
        Song song = new Song();
        song.setRawContent(content);

        String[] lines = content.split("\n");
        boolean firstLine = true;
        boolean secondLine = true;
        Song.SongSection currentSection = new Song.SongSection();
        currentSection.setLabel("");
        String pendingChordLine = null; // For OnSong format: chord line above lyrics

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            String trimmedLine = line.trim();

            // Skip empty lines
            if (trimmedLine.isEmpty()) {
                // If we have a pending chord line with no lyrics, add it
                if (pendingChordLine != null) {
                    Song.SongLine songLine = parseChordOnlyLine(pendingChordLine);
                    currentSection.addLine(songLine);
                    pendingChordLine = null;
                }
                continue;
            }

            // Check for ChordPro tags {tag: value}
            Matcher tagMatcher = CHORDPRO_TAG.matcher(trimmedLine);
            if (tagMatcher.find()) {
                String tag = tagMatcher.group(1).toLowerCase();
                String value = tagMatcher.group(2);
                if (value == null) value = "";

                processTag(song, tag, value.trim());

                // If the whole line is just a tag, skip to next line
                if (tagMatcher.start() == 0 && tagMatcher.end() == trimmedLine.length()) {
                    firstLine = false;
                    secondLine = false;
                    continue;
                }
            }

            // Check for section labels (Verse 1:, Chorus:, etc.)
            Matcher sectionMatcher = SECTION_LABEL.matcher(trimmedLine);
            if (sectionMatcher.matches()) {
                // Flush pending chord line
                if (pendingChordLine != null) {
                    Song.SongLine songLine = parseChordOnlyLine(pendingChordLine);
                    currentSection.addLine(songLine);
                    pendingChordLine = null;
                }
                // Save previous section if it has content
                if (!currentSection.getLines().isEmpty()) {
                    song.addSection(currentSection);
                }
                // Start new section
                currentSection = new Song.SongSection();
                String label = sectionMatcher.group(1);
                String num = sectionMatcher.group(2);
                currentSection.setLabel(label + (num != null && !num.isEmpty() ? " " + num : ""));
                firstLine = false;
                secondLine = false;
                continue;
            }

            // OnSong format: first line is title, second line is artist
            if (firstLine && !trimmedLine.startsWith("{") && !trimmedLine.startsWith("[")) {
                if (song.getTitle().isEmpty()) {
                    song.setTitle(trimmedLine);
                }
                firstLine = false;
                continue;
            }
            if (secondLine && !trimmedLine.startsWith("{") && !trimmedLine.startsWith("[") &&
                !CHORD_PATTERN.matcher(trimmedLine).find() && !isChordOnlyLine(trimmedLine)) {
                if (song.getArtist().isEmpty()) {
                    song.setArtist(trimmedLine);
                }
                secondLine = false;
                continue;
            }

            firstLine = false;
            secondLine = false;

            // Check if this is a chord-only line (OnSong format)
            if (isChordOnlyLine(trimmedLine)) {
                // Flush any existing pending chord line
                if (pendingChordLine != null) {
                    Song.SongLine songLine = parseChordOnlyLine(pendingChordLine);
                    currentSection.addLine(songLine);
                }
                // Store this chord line to combine with next lyrics line
                pendingChordLine = line; // Keep original spacing
                continue;
            }

            // This is a lyrics line (possibly with inline [chords])
            if (pendingChordLine != null) {
                // Combine pending chord line with this lyrics line
                Song.SongLine songLine = parseLineWithChordAbove(pendingChordLine, trimmedLine);
                currentSection.addLine(songLine);
                pendingChordLine = null;
            } else {
                // Parse line with inline chords [chord]
                Song.SongLine songLine = parseLine(trimmedLine);
                currentSection.addLine(songLine);
            }
        }

        // Flush any remaining pending chord line
        if (pendingChordLine != null) {
            Song.SongLine songLine = parseChordOnlyLine(pendingChordLine);
            currentSection.addLine(songLine);
        }

        // Add last section
        if (!currentSection.getLines().isEmpty()) {
            song.addSection(currentSection);
        }

        return song;
    }

    /**
     * Check if a line contains only chord symbols (OnSong format).
     */
    private static boolean isChordOnlyLine(String line) {
        // Split by whitespace and check if all parts are valid chords
        String[] parts = line.trim().split("\\s+");
        if (parts.length == 0) return false;

        int chordCount = 0;
        for (String part : parts) {
            if (part.isEmpty()) continue;
            if (isValidChord(part)) {
                chordCount++;
            } else {
                return false; // Contains non-chord text
            }
        }
        return chordCount > 0;
    }

    /**
     * Check if a string is a valid chord symbol.
     */
    private static boolean isValidChord(String s) {
        // Match chords like: C, Am, G7, F#m, Bb, Dm/A, Csus4, Cmaj7, C7sus4, Cadd9, etc.
        return s.matches("^[A-G](#|b)?(m|maj|min|dim|aug|sus|add|M)?(\\d+)?(sus|add)?(\\d+)?(/[A-G](#|b)?)?$");
    }

    /**
     * Parse a chord-only line into a SongLine (chords with no lyrics).
     */
    private static Song.SongLine parseChordOnlyLine(String chordLine) {
        Song.SongLine songLine = new Song.SongLine();
        songLine.setLyrics("");

        // Find each chord and its position
        int pos = 0;
        StringBuilder chord = new StringBuilder();
        for (int i = 0; i < chordLine.length(); i++) {
            char c = chordLine.charAt(i);
            if (c == ' ' || c == '\t') {
                if (chord.length() > 0) {
                    songLine.addChord(new Song.ChordPosition(chord.toString(), pos));
                    chord = new StringBuilder();
                }
                pos = i + 1;
            } else {
                if (chord.length() == 0) {
                    pos = i;
                }
                chord.append(c);
            }
        }
        if (chord.length() > 0) {
            songLine.addChord(new Song.ChordPosition(chord.toString(), pos));
        }

        return songLine;
    }

    /**
     * Parse a lyrics line with a chord line positioned above it.
     */
    private static Song.SongLine parseLineWithChordAbove(String chordLine, String lyricsLine) {
        Song.SongLine songLine = new Song.SongLine();
        songLine.setLyrics(lyricsLine);

        // Find each chord and its position from the chord line
        int pos = 0;
        StringBuilder chord = new StringBuilder();
        for (int i = 0; i < chordLine.length(); i++) {
            char c = chordLine.charAt(i);
            if (c == ' ' || c == '\t') {
                if (chord.length() > 0) {
                    songLine.addChord(new Song.ChordPosition(chord.toString(), pos));
                    chord = new StringBuilder();
                }
            } else {
                if (chord.length() == 0) {
                    pos = i; // Position where chord starts
                }
                chord.append(c);
            }
        }
        if (chord.length() > 0) {
            songLine.addChord(new Song.ChordPosition(chord.toString(), pos));
        }

        return songLine;
    }

    /**
     * Process a ChordPro tag.
     */
    private static void processTag(Song song, String tag, String value) {
        switch (tag) {
            case "title":
            case "t":
                song.setTitle(value);
                break;
            case "subtitle":
            case "st":
            case "su":
            case "artist":
                song.setArtist(value);
                break;
            case "key":
                song.setKey(value);
                break;
            case "tempo":
                song.setTempo(value);
                break;
            case "ccli":
                song.setCcli(value);
                break;
            case "copyright":
            case "footer":
            case "f":
                song.setCopyright(value);
                break;
        }
    }

    /**
     * Parse a single line, extracting chords and lyrics.
     */
    private static Song.SongLine parseLine(String line) {
        Song.SongLine songLine = new Song.SongLine();
        StringBuilder lyrics = new StringBuilder();
        Matcher matcher = CHORD_PATTERN.matcher(line);

        int lastEnd = 0;
        while (matcher.find()) {
            // Add text before this chord
            String textBefore = line.substring(lastEnd, matcher.start());
            int position = lyrics.length();
            lyrics.append(textBefore);

            // Add chord at current position
            String chord = matcher.group(1);
            songLine.addChord(new Song.ChordPosition(chord, position));

            lastEnd = matcher.end();
        }

        // Add remaining text
        if (lastEnd < line.length()) {
            lyrics.append(line.substring(lastEnd));
        }

        songLine.setLyrics(lyrics.toString());
        return songLine;
    }
}

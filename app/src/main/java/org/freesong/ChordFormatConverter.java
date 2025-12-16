package org.freesong;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Utility class for converting between chord formats:
 * - Inline chords: [G]Amazing [D]grace (ChordPro style)
 * - Chords above lyrics: Chords on separate line above lyrics (OnSong style)
 */
public class ChordFormatConverter {

    private static final Pattern CHORD_PATTERN = Pattern.compile("\\[([^\\]]+)\\]");

    /**
     * Convert inline chords [G]lyrics to chords-above format.
     * Example: "[G]Amazing [D]grace" becomes:
     * "G       D\nAmazing grace"
     */
    public static String inlineToAbove(String content) {
        StringBuilder result = new StringBuilder();
        String[] lines = content.split("\n", -1); // -1 to keep trailing empty lines

        for (String line : lines) {
            if (hasInlineChords(line)) {
                // Extract chord positions and build chord line + lyrics line
                StringBuilder chordLine = new StringBuilder();
                StringBuilder lyricsLine = new StringBuilder();

                Matcher matcher = CHORD_PATTERN.matcher(line);
                int lastEnd = 0;

                while (matcher.find()) {
                    // Add text before this chord to lyrics
                    String textBefore = line.substring(lastEnd, matcher.start());
                    int chordPosition = lyricsLine.length();
                    lyricsLine.append(textBefore);

                    // Position chord above the next character
                    while (chordLine.length() < chordPosition) {
                        chordLine.append(" ");
                    }
                    // Handle overlap - add space if needed
                    if (chordLine.length() > chordPosition) {
                        chordLine.append(" ");
                    }
                    chordLine.append(matcher.group(1)); // The chord without brackets

                    lastEnd = matcher.end();
                }

                // Add remaining text
                if (lastEnd < line.length()) {
                    lyricsLine.append(line.substring(lastEnd));
                }

                // Only add chord line if there were chords
                if (chordLine.length() > 0) {
                    result.append(chordLine.toString()).append("\n");
                }
                result.append(lyricsLine.toString()).append("\n");
            } else {
                result.append(line).append("\n");
            }
        }

        // Remove trailing newline if original didn't have one
        if (result.length() > 0 && !content.endsWith("\n")) {
            result.setLength(result.length() - 1);
        }

        return result.toString();
    }

    /**
     * Convert chords-above format to inline [G]lyrics.
     * Example:
     * "G       D\nAmazing grace" becomes "[G]Amazing [D]grace"
     */
    public static String aboveToInline(String content) {
        StringBuilder result = new StringBuilder();
        String[] lines = content.split("\n", -1);

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];

            // Check if this is a chord-only line followed by a lyrics line
            if (isChordOnlyLine(line) && i + 1 < lines.length && !isChordOnlyLine(lines[i + 1])) {
                String chordLine = line;
                String lyricsLine = lines[i + 1];

                // Merge chord line with lyrics line
                String merged = mergeChordAndLyrics(chordLine, lyricsLine);
                result.append(merged).append("\n");
                i++; // Skip the lyrics line since we merged it
            } else {
                result.append(line).append("\n");
            }
        }

        // Remove trailing newline if original didn't have one
        if (result.length() > 0 && !content.endsWith("\n")) {
            result.setLength(result.length() - 1);
        }

        return result.toString();
    }

    /**
     * Check if a line contains inline chords [chord].
     */
    public static boolean hasInlineChords(String line) {
        return CHORD_PATTERN.matcher(line).find();
    }

    /**
     * Check if a line contains only chord symbols (OnSong format).
     */
    public static boolean isChordOnlyLine(String line) {
        String trimmed = line.trim();
        if (trimmed.isEmpty()) return false;

        // Split by whitespace and check if all non-empty parts are valid chords
        String[] parts = trimmed.split("\\s+");
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
     * Merge a chord line with a lyrics line into inline chord format.
     * Chords are inserted at their character positions.
     */
    private static String mergeChordAndLyrics(String chordLine, String lyricsLine) {
        // Parse chords and their positions from chord line
        List<ChordPos> chords = new ArrayList<ChordPos>();
        int pos = 0;
        StringBuilder chord = new StringBuilder();

        for (int i = 0; i < chordLine.length(); i++) {
            char c = chordLine.charAt(i);
            if (c == ' ' || c == '\t') {
                if (chord.length() > 0) {
                    chords.add(new ChordPos(chord.toString(), pos));
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
            chords.add(new ChordPos(chord.toString(), pos));
        }

        // Insert chords into lyrics at their positions (in reverse order to preserve positions)
        StringBuilder result = new StringBuilder(lyricsLine);
        for (int i = chords.size() - 1; i >= 0; i--) {
            ChordPos cp = chords.get(i);
            int insertPos = Math.min(cp.position, result.length());
            result.insert(insertPos, "[" + cp.chord + "]");
        }

        return result.toString();
    }

    /**
     * Detect if content primarily uses inline chords format.
     */
    public static boolean isInlineFormat(String content) {
        String[] lines = content.split("\n");
        int inlineCount = 0;
        int aboveCount = 0;

        for (int i = 0; i < lines.length; i++) {
            if (hasInlineChords(lines[i])) {
                inlineCount++;
            } else if (isChordOnlyLine(lines[i])) {
                aboveCount++;
            }
        }

        // If more inline chords than chord-only lines, it's inline format
        return inlineCount > aboveCount;
    }

    // Helper class for chord position
    private static class ChordPos {
        String chord;
        int position;

        ChordPos(String chord, int position) {
            this.chord = chord;
            this.position = position;
        }
    }
}

package org.freesong;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Handles chord transposition.
 */
public class Transposer {

    private static final String[] NOTES_SHARP = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
    private static final String[] NOTES_FLAT = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"};

    // Pattern to match chord root note (with optional sharp/flat)
    private static final Pattern CHORD_ROOT_PATTERN = Pattern.compile("^([A-G][#b]?)(.*)$");

    /**
     * Transpose a chord by a number of semitones.
     * @param chord The chord to transpose (e.g., "Am7", "G/B", "F#m")
     * @param semitones Number of semitones to transpose (positive = up, negative = down)
     * @return The transposed chord
     */
    public static String transposeChord(String chord, int semitones) {
        if (chord == null || chord.isEmpty()) {
            return chord;
        }

        // Handle slash chords (e.g., G/B)
        int slashIndex = chord.indexOf('/');
        if (slashIndex > 0) {
            String mainChord = chord.substring(0, slashIndex);
            String bassNote = chord.substring(slashIndex + 1);
            return transposeChord(mainChord, semitones) + "/" + transposeChord(bassNote, semitones);
        }

        Matcher matcher = CHORD_ROOT_PATTERN.matcher(chord);
        if (!matcher.matches()) {
            return chord; // Return unchanged if not a recognized chord
        }

        String root = matcher.group(1);
        String suffix = matcher.group(2);

        int noteIndex = getNoteIndex(root);
        if (noteIndex == -1) {
            return chord; // Unknown note
        }

        // Transpose
        int newIndex = (noteIndex + semitones) % 12;
        if (newIndex < 0) {
            newIndex += 12;
        }

        // Use sharps or flats based on original chord
        String[] notes = root.contains("b") ? NOTES_FLAT : NOTES_SHARP;
        return notes[newIndex] + suffix;
    }

    /**
     * Get the semitone index of a note (0-11).
     */
    private static int getNoteIndex(String note) {
        for (int i = 0; i < NOTES_SHARP.length; i++) {
            if (NOTES_SHARP[i].equalsIgnoreCase(note) || NOTES_FLAT[i].equalsIgnoreCase(note)) {
                return i;
            }
        }
        return -1;
    }

    /**
     * Transpose all chords in a Song.
     */
    public static void transposeSong(Song song, int semitones) {
        for (Song.SongSection section : song.getSections()) {
            for (Song.SongLine line : section.getLines()) {
                for (Song.ChordPosition chordPos : line.getChords()) {
                    String transposed = transposeChord(chordPos.getChord(), semitones);
                    chordPos.setChord(transposed);
                }
            }
        }

        // Update the key if set
        String key = song.getKey();
        if (key != null && !key.isEmpty()) {
            song.setKey(transposeChord(key, semitones));
        }
    }

    /**
     * Get the display name for a transposition.
     */
    public static String getTranspositionName(int semitones) {
        if (semitones == 0) return "Original";
        if (semitones > 0) return "+" + semitones;
        return String.valueOf(semitones);
    }
}

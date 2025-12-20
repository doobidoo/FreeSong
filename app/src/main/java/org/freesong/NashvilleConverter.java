package org.freesong;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Converts between standard chord notation and Nashville Number System.
 *
 * Nashville Number System represents chords relative to the key:
 * - In key of C: C=1, D=2, E=3, F=4, G=5, A=6, B=7
 * - In key of G: G=1, A=2, B=3, C=4, D=5, E=6, F#=7
 *
 * Chord qualities are preserved after the number:
 * - Am in key C → 6m
 * - G7 in key C → 5⁷ or 57
 * - Cmaj7 in key C → 1△7 or 1maj7
 */
public class NashvilleConverter {

    private static final String[] NOTES_SHARP = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
    private static final String[] NOTES_FLAT = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"};

    // Pattern to extract root note from chord
    private static final Pattern CHORD_ROOT_PATTERN = Pattern.compile("^([A-G][#b♯♭]?)(.*)$");

    // Pattern to detect Nashville notation (starts with 1-7, optionally with # or b prefix)
    private static final Pattern NASHVILLE_PATTERN = Pattern.compile("^([#b♯♭]?)([1-7])(.*)$");

    /**
     * Convert a standard chord to Nashville notation.
     *
     * @param chord The chord to convert (e.g., "Am", "G7", "F#m")
     * @param key   The key of the song (e.g., "C", "G", "F#")
     * @return The Nashville notation (e.g., "6m", "5⁷", "#4m")
     */
    public static String toNashville(String chord, String key) {
        if (chord == null || chord.isEmpty() || key == null || key.isEmpty()) {
            return chord;
        }

        // Handle slash chords
        int slashIndex = chord.indexOf('/');
        if (slashIndex > 0) {
            String mainChord = chord.substring(0, slashIndex);
            String bassNote = chord.substring(slashIndex + 1);
            return toNashville(mainChord, key) + "/" + toNashvilleBass(bassNote, key);
        }

        Matcher matcher = CHORD_ROOT_PATTERN.matcher(chord);
        if (!matcher.matches()) {
            return chord; // Not a recognized chord
        }

        String root = matcher.group(1);
        String suffix = matcher.group(2);

        int keyIndex = getNoteIndex(key);
        int chordIndex = getNoteIndex(root);

        if (keyIndex == -1 || chordIndex == -1) {
            return chord; // Unknown key or chord
        }

        // Calculate scale degree (1-7)
        int semitones = (chordIndex - keyIndex + 12) % 12;
        String nashvilleRoot = semitoneToNashville(semitones);

        return nashvilleRoot + suffix;
    }

    /**
     * Convert a Nashville notation back to standard chord.
     *
     * @param nashville The Nashville notation (e.g., "6m", "5⁷")
     * @param key       The key of the song (e.g., "C", "G")
     * @return The standard chord (e.g., "Am", "G7")
     */
    public static String fromNashville(String nashville, String key) {
        if (nashville == null || nashville.isEmpty() || key == null || key.isEmpty()) {
            return nashville;
        }

        // Handle slash chords
        int slashIndex = nashville.indexOf('/');
        if (slashIndex > 0) {
            String mainChord = nashville.substring(0, slashIndex);
            String bassNote = nashville.substring(slashIndex + 1);
            return fromNashville(mainChord, key) + "/" + fromNashvilleBass(bassNote, key);
        }

        Matcher matcher = NASHVILLE_PATTERN.matcher(nashville);
        if (!matcher.matches()) {
            return nashville; // Not Nashville notation
        }

        String accidental = matcher.group(1);
        int degree = Integer.parseInt(matcher.group(2));
        String suffix = matcher.group(3);

        int keyIndex = getNoteIndex(key);
        if (keyIndex == -1) {
            return nashville;
        }

        // Convert scale degree to semitones
        int semitones = nashvilleDegreeToSemitones(degree);

        // Apply accidental
        if ("#".equals(accidental) || "♯".equals(accidental)) {
            semitones = (semitones + 1) % 12;
        } else if ("b".equals(accidental) || "♭".equals(accidental)) {
            semitones = (semitones - 1 + 12) % 12;
        }

        int noteIndex = (keyIndex + semitones) % 12;

        // Use sharps or flats based on key
        boolean keyUsesFlat = key.contains("b") || key.contains("♭") ||
                              key.equals("F") || key.equals("Bb") || key.equals("Eb") ||
                              key.equals("Ab") || key.equals("Db") || key.equals("Gb");
        String[] notes = keyUsesFlat ? NOTES_FLAT : NOTES_SHARP;

        return notes[noteIndex] + suffix;
    }

    /**
     * Convert a bass note to Nashville notation.
     */
    private static String toNashvilleBass(String bassNote, String key) {
        int keyIndex = getNoteIndex(key);
        int bassIndex = getNoteIndex(bassNote);

        if (keyIndex == -1 || bassIndex == -1) {
            return bassNote;
        }

        int semitones = (bassIndex - keyIndex + 12) % 12;
        return semitoneToNashville(semitones);
    }

    /**
     * Convert a Nashville bass note back to standard.
     */
    private static String fromNashvilleBass(String nashvilleBass, String key) {
        // Simple case: just a number
        try {
            int degree = Integer.parseInt(nashvilleBass.replaceAll("[#b♯♭]", ""));
            String accidental = "";
            if (nashvilleBass.startsWith("#") || nashvilleBass.startsWith("♯")) {
                accidental = "#";
            } else if (nashvilleBass.startsWith("b") || nashvilleBass.startsWith("♭")) {
                accidental = "b";
            }

            int keyIndex = getNoteIndex(key);
            if (keyIndex == -1) return nashvilleBass;

            int semitones = nashvilleDegreeToSemitones(degree);
            if ("#".equals(accidental)) semitones = (semitones + 1) % 12;
            else if ("b".equals(accidental)) semitones = (semitones - 1 + 12) % 12;

            int noteIndex = (keyIndex + semitones) % 12;

            boolean keyUsesFlat = key.contains("b") || key.contains("♭");
            return keyUsesFlat ? NOTES_FLAT[noteIndex] : NOTES_SHARP[noteIndex];
        } catch (NumberFormatException e) {
            return nashvilleBass;
        }
    }

    /**
     * Check if a string is in Nashville notation.
     */
    public static boolean isNashville(String chord) {
        if (chord == null || chord.isEmpty()) return false;

        // Remove slash chord bass if present
        String mainPart = chord;
        int slashIndex = chord.indexOf('/');
        if (slashIndex > 0) {
            mainPart = chord.substring(0, slashIndex);
        }

        return NASHVILLE_PATTERN.matcher(mainPart).matches();
    }

    /**
     * Detect the key from song metadata.
     * Returns null if key cannot be determined.
     */
    public static String detectKey(Song song) {
        if (song == null) return null;

        String key = song.getKey();
        if (key != null && !key.isEmpty()) {
            // Normalize key (remove "m" for minor, etc.)
            key = key.trim();
            if (key.length() > 0) {
                // Extract just the root note
                Matcher matcher = CHORD_ROOT_PATTERN.matcher(key);
                if (matcher.matches()) {
                    return matcher.group(1);
                }
            }
        }

        return null; // Key not found in metadata
    }

    /**
     * Convert semitones from key to Nashville number.
     * Major scale: 0=1, 2=2, 4=3, 5=4, 7=5, 9=6, 11=7
     */
    private static String semitoneToNashville(int semitones) {
        switch (semitones) {
            case 0: return "1";
            case 1: return "#1";  // or b2
            case 2: return "2";
            case 3: return "#2";  // or b3
            case 4: return "3";
            case 5: return "4";
            case 6: return "#4";  // or b5
            case 7: return "5";
            case 8: return "#5";  // or b6
            case 9: return "6";
            case 10: return "#6"; // or b7
            case 11: return "7";
            default: return String.valueOf(semitones);
        }
    }

    /**
     * Convert Nashville degree (1-7) to semitones.
     */
    private static int nashvilleDegreeToSemitones(int degree) {
        switch (degree) {
            case 1: return 0;
            case 2: return 2;
            case 3: return 4;
            case 4: return 5;
            case 5: return 7;
            case 6: return 9;
            case 7: return 11;
            default: return 0;
        }
    }

    /**
     * Get the semitone index of a note (0-11).
     */
    private static int getNoteIndex(String note) {
        if (note == null || note.isEmpty()) return -1;

        // Normalize Unicode accidentals
        String normalized = note.replace("♯", "#").replace("♭", "b");

        for (int i = 0; i < NOTES_SHARP.length; i++) {
            if (NOTES_SHARP[i].equalsIgnoreCase(normalized) || NOTES_FLAT[i].equalsIgnoreCase(normalized)) {
                return i;
            }
        }
        return -1;
    }

    /**
     * Get list of all possible keys for key selection dialog.
     */
    public static String[] getAllKeys() {
        return new String[] {
            "C", "C#", "Db", "D", "D#", "Eb", "E", "F",
            "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B"
        };
    }

    /**
     * Get common keys (most frequently used) for quick selection.
     */
    public static String[] getCommonKeys() {
        return new String[] {
            "C", "G", "D", "A", "E", "F", "Bb", "Eb"
        };
    }
}

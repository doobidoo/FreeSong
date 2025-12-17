package org.freesong;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Converts chord accidentals between sharp and flat notation.
 */
public class AccidentalConverter {

    // Enharmonic mappings: sharp -> flat
    private static final String[][] SHARP_TO_FLAT = {
        {"C#", "Db"},
        {"D#", "Eb"},
        {"F#", "Gb"},
        {"G#", "Ab"},
        {"A#", "Bb"}
    };

    /**
     * Convert all sharps to flats in the content.
     * Works on both inline [C#m] and chords-above C#m formats.
     */
    public static String convertToFlats(String content) {
        String result = content;

        // Handle inline chords [C#m] -> [Dbm]
        result = convertInlineChords(result, true);

        // Handle standalone chords (above format)
        result = convertStandaloneChords(result, true);

        return result;
    }

    /**
     * Convert all flats to sharps in the content.
     */
    public static String convertToSharps(String content) {
        String result = content;

        // Handle inline chords [Dbm] -> [C#m]
        result = convertInlineChords(result, false);

        // Handle standalone chords (above format)
        result = convertStandaloneChords(result, false);

        return result;
    }

    private static String convertInlineChords(String content, boolean toFlats) {
        StringBuffer sb = new StringBuffer();
        Matcher matcher = Pattern.compile("\\[([^\\]]+)\\]").matcher(content);

        while (matcher.find()) {
            String chord = matcher.group(1);
            String converted = convertChord(chord, toFlats);
            matcher.appendReplacement(sb, "[" + Matcher.quoteReplacement(converted) + "]");
        }
        matcher.appendTail(sb);
        return sb.toString();
    }

    private static String convertStandaloneChords(String content, boolean toFlats) {
        // Process line by line to only convert chord-only lines
        StringBuilder result = new StringBuilder();
        String[] lines = content.split("\n", -1);

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            if (ChordFormatConverter.isChordOnlyLine(line)) {
                // Convert each chord on this line
                StringBuffer sb = new StringBuffer();
                Matcher matcher = Pattern.compile(
                    "([A-G][#b]?)(m|maj|min|dim|aug|sus|add|M)?(\\d+)?(sus|add)?(\\d+)?(/[A-G][#b]?)?"
                ).matcher(line);

                while (matcher.find()) {
                    String fullChord = matcher.group();
                    String converted = convertChord(fullChord, toFlats);
                    matcher.appendReplacement(sb, Matcher.quoteReplacement(converted));
                }
                matcher.appendTail(sb);
                result.append(sb.toString());
            } else {
                result.append(line);
            }
            if (i < lines.length - 1) {
                result.append("\n");
            }
        }
        return result.toString();
    }

    /**
     * Convert a single chord's accidentals.
     */
    private static String convertChord(String chord, boolean toFlats) {
        if (chord == null || chord.isEmpty()) return chord;

        // Handle slash chords (G/B, C#m/G#)
        int slashIndex = chord.indexOf('/');
        if (slashIndex > 0) {
            String mainPart = chord.substring(0, slashIndex);
            String bassPart = chord.substring(slashIndex + 1);
            return convertChord(mainPart, toFlats) + "/" + convertChord(bassPart, toFlats);
        }

        if (toFlats) {
            // Sharp to flat
            for (String[] pair : SHARP_TO_FLAT) {
                if (chord.startsWith(pair[0])) {
                    return pair[1] + chord.substring(pair[0].length());
                }
            }
        } else {
            // Flat to sharp
            for (String[] pair : SHARP_TO_FLAT) {
                if (chord.startsWith(pair[1])) {
                    return pair[0] + chord.substring(pair[1].length());
                }
            }
        }
        return chord;
    }

    /**
     * Detect if content predominantly uses sharps or flats.
     * @return true if predominantly sharps, false if flats
     */
    public static boolean isSharpsFormat(String content) {
        int sharpCount = 0;
        int flatCount = 0;

        Matcher matcher = Pattern.compile("[A-G]([#b])").matcher(content);
        while (matcher.find()) {
            if (matcher.group(1).equals("#")) {
                sharpCount++;
            } else {
                flatCount++;
            }
        }

        return sharpCount >= flatCount; // Default to sharps if equal or no accidentals
    }
}

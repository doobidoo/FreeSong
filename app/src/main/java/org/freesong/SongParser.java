package org.freesong;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parser for OnSong and ChordPro file formats.
 */
public class SongParser {

    // Patterns for parsing
    private static final Pattern CHORD_PATTERN = Pattern.compile("\\[([^\\]]+)\\]");
    private static final Pattern CHORDPRO_TAG = Pattern.compile("\\{([^:}]+)(?::([^}]*))?\\}");
    private static final Pattern SECTION_LABEL = Pattern.compile("^(Verse|Chorus|Bridge|Pre-Chorus|Intro|Outro|Tag|Interlude|Instrumental)\\s*(\\d*):?\\s*$", Pattern.CASE_INSENSITIVE);

    /**
     * Parse a song file.
     */
    public static Song parseFile(File file) throws IOException {
        StringBuilder content = new StringBuilder();
        BufferedReader reader = new BufferedReader(new FileReader(file));
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

        for (String line : lines) {
            line = line.trim();

            // Skip empty lines
            if (line.isEmpty()) {
                continue;
            }

            // Check for ChordPro tags {tag: value}
            Matcher tagMatcher = CHORDPRO_TAG.matcher(line);
            if (tagMatcher.find()) {
                String tag = tagMatcher.group(1).toLowerCase();
                String value = tagMatcher.group(2);
                if (value == null) value = "";

                processTag(song, tag, value.trim());

                // If the whole line is just a tag, skip to next line
                if (tagMatcher.start() == 0 && tagMatcher.end() == line.length()) {
                    firstLine = false;
                    secondLine = false;
                    continue;
                }
            }

            // Check for section labels (Verse 1:, Chorus:, etc.)
            Matcher sectionMatcher = SECTION_LABEL.matcher(line);
            if (sectionMatcher.matches()) {
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
            if (firstLine && !line.startsWith("{") && !line.startsWith("[")) {
                if (song.getTitle().isEmpty()) {
                    song.setTitle(line);
                }
                firstLine = false;
                continue;
            }
            if (secondLine && !line.startsWith("{") && !line.startsWith("[") && !CHORD_PATTERN.matcher(line).find()) {
                if (song.getArtist().isEmpty()) {
                    song.setArtist(line);
                }
                secondLine = false;
                continue;
            }

            firstLine = false;
            secondLine = false;

            // Parse line with chords
            Song.SongLine songLine = parseLine(line);
            currentSection.addLine(songLine);
        }

        // Add last section
        if (!currentSection.getLines().isEmpty()) {
            song.addSection(currentSection);
        }

        return song;
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

package org.freesong;

import java.util.ArrayList;
import java.util.List;

/**
 * Represents a setlist containing ordered song references.
 */
public class SetList {
    private long id = -1;
    private String name = "";
    private long createdAt = 0;
    private long modifiedAt = 0;
    private List<SetListItem> items = new ArrayList<SetListItem>();

    public SetList() {
        long now = System.currentTimeMillis();
        this.createdAt = now;
        this.modifiedAt = now;
    }

    public SetList(String name) {
        this();
        this.name = name;
    }

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public long getModifiedAt() { return modifiedAt; }
    public void setModifiedAt(long modifiedAt) { this.modifiedAt = modifiedAt; }

    public List<SetListItem> getItems() { return items; }
    public void setItems(List<SetListItem> items) { this.items = items; }

    public void addItem(SetListItem item) {
        items.add(item);
        modifiedAt = System.currentTimeMillis();
    }

    public void removeItem(int index) {
        if (index >= 0 && index < items.size()) {
            items.remove(index);
            modifiedAt = System.currentTimeMillis();
        }
    }

    public void moveItem(int fromIndex, int toIndex) {
        if (fromIndex >= 0 && fromIndex < items.size() &&
            toIndex >= 0 && toIndex < items.size()) {
            SetListItem item = items.remove(fromIndex);
            items.add(toIndex, item);
            modifiedAt = System.currentTimeMillis();
        }
    }

    /**
     * Represents a song entry in a setlist.
     */
    public static class SetListItem {
        private long id = -1;
        private long setListId = -1;
        private String songPath = "";
        private String songTitle = "";
        private String songArtist = "";
        private int position = 0;
        private String notes = "";

        public SetListItem() {}

        public SetListItem(String songPath, String songTitle, String songArtist) {
            this.songPath = songPath;
            this.songTitle = songTitle;
            this.songArtist = songArtist;
        }

        public long getId() { return id; }
        public void setId(long id) { this.id = id; }

        public long getSetListId() { return setListId; }
        public void setSetListId(long setListId) { this.setListId = setListId; }

        public String getSongPath() { return songPath; }
        public void setSongPath(String songPath) { this.songPath = songPath; }

        public String getSongTitle() { return songTitle; }
        public void setSongTitle(String songTitle) { this.songTitle = songTitle; }

        public String getSongArtist() { return songArtist; }
        public void setSongArtist(String songArtist) { this.songArtist = songArtist; }

        public int getPosition() { return position; }
        public void setPosition(int position) { this.position = position; }

        public String getNotes() { return notes; }
        public void setNotes(String notes) { this.notes = notes; }
    }
}

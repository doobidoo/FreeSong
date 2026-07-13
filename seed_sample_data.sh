#!/bin/bash
# Seed 5 ChordPro sample songs into the FreeSong app's Documents/FreeSong directory.
# Usage: ./seed_sample_data.sh <simulator_device_id>
# Example: ./seed_sample_data.sh "iPhone 17 Pro Max"

set -euo pipefail

DEVICE_ID="$1"
BUNDLE_ID="com.freesong.FreeSong"

# Build first
echo "=== Building ==="
xcrun xcodebuild -scheme FreeSong -destination "platform=iOS Simulator,name=$DEVICE_ID" -derivedDataPath .build/xcode build

# Install
echo "=== Installing ==="
xcrun simctl install "$DEVICE_ID" .build/xcode/Build/Products/Debug-iphonesimulator/FreeSong.app

# Get the container directory
CONTAINER_DIR=$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)
DOCS_DIR="${CONTAINER_DIR}/Documents/FreeSong"
echo "=== Container Documents dir: $DOCS_DIR ==="

mkdir -p "$DOCS_DIR"

# Generate 5 ChordPro song files
python3 << PYEOF
import os

songs = [
    {
        "title": "Amazing Grace",
        "artist": "John Newton",
        "key": "G",
        "content": """{title: Amazing Grace}
{artist: John Newton}
{key: G}

Verse 1:
Amazing [G]grace how sweet the [D]sound
That saved a wretch like [G]me
I once was lost but now am [D]found
Was blind but now I [G]see

Verse 2:
'Twas [G]grace that taught my heart to [D]fear
And grace my fears re-[G]lieved
How precious did that grace ap-[D]pear
The hour I first be-[G]lieved
"""
    },
    {
        "title": "How Great Thou Art",
        "artist": "Carl Boberg",
        "key": "C",
        "content": """{title: How Great Thou Art}
{artist: Carl Boberg}
{key: C}

Verse 1:
O [C]Lord my God when I in awesome [F]wonder
Consider [C]all the worlds Thy hands have [G7]made
I see the [C]stars I hear the rolling [F]thunder
Thy power through-[C]out the universe dis-[G7]played
[C]played

Chorus:
Then sings my [F]soul my Savior God to [C]Thee
How great Thou [G7]art how great Thou [C]art
"""
    },
    {
        "title": "Blessed Assurance",
        "artist": "Fanny Crosby",
        "key": "D",
        "content": """{title: Blessed Assurance}
{artist: Fanny Crosby}
{key: D}

Verse 1:
Blessed as-[D]surance Jesus is [A]mine
O what a [D]foretaste of glory di-[A]vine
Heir of sal-[D]vation purchase of [G]God
Born of His [D]Spirit washed in His [A]blood
[D]blood

Chorus:
This is my [G]story this is my [D]song
Praising my [A]Savior all the day [D]long
This is my [G]story this is my [D]song
Praising my [A]Savior all the day [D]long
"""
    },
    {
        "title": "Great Is Thy Faithfulness",
        "artist": "Thomas Chisholm",
        "key": "E",
        "content": """{title: Great Is Thy Faithfulness}
{artist: Thomas Chisholm}
{key: E}

Verse 1:
Great is Thy [E]faithfulness O God my [A]Father
There is no [E]shadow of turning with [B7]Thee
Thou changest [E]not Thy compassions they [A]fail not
As Thou hast [E]been Thou for-[B7]ever wilt [E]be

Chorus:
Great is Thy [A]faithfulness great is Thy [E]faithfulness
Morning by [B7]morning new mercies I [E]see
All I have [A]needed Thy hand hath pro-[E]vided
Great is Thy [B7]faithfulness Lord unto [E]me
"""
    },
    {
        "title": "Amazing Love",
        "artist": "Chris Tomlin",
        "key": "A",
        "content": """{title: Amazing Love}
{artist: Chris Tomlin}
{key: A}

Verse 1:
I'm for-[A]given because You were for-[D]saken
I'm ac-[A]cepted You were con-[E]demned
I'm a-[F#m]live and well Your Spirit is with-[D]in me
Because You [E]died and rose a-[A]gain

Chorus:
Amazing [D]love how can it [A]be
That You my [E]King would die for [F#m]me
Amazing [D]love I know it's [A]true
It's my [E]joy to honor [A]You
"""
    },
]

out_dir = "$DOCS_DIR"
for song in songs:
    filename = song["title"].lower().replace(" ", "-") + ".chordpro"
    filepath = os.path.join(out_dir, filename)
    with open(filepath, "w") as f:
        f.write(song["content"])
    print(f"  Created: {filepath}")

print(f"\n=== {len(songs)} songs written to {out_dir} ===")
PYEOF

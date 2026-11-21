# How this repository was recovered

On 2026-11-21 the original Godot project folder for Deck of Fools could not be found: it was not on GitHub or on this Mac. Everything here was rebuilt from what was deployed on Cloudflare.

## Sources

- **Game**: `index.pck` from the live `deck-of-fools` Worker (Godot 4.7.2 web export, deployed 2026-10-21).
- **Site Worker**: the script downloaded from the Cloudflare API.
- **API Worker**: the deployed script downloaded from the Cloudflare API, with its bindings and variables.
- **Database schema**: `sqlite_master` of the live `deck-of-fools` D1 database (the migration it records is `0001_init.sql`).

## How close the rebuild is

Exporting this project with Godot 4.7.2 and comparing it with the live build:

- **Engine and web page**: `index.html`, `index.js`, the audio worklets, the icons and `index.wasm` are byte-identical to the live files, and `index.wasm.gz` comes out the same size.
- **All 58 compiled scripts are byte-identical** to the live ones.
- **The 2 scenes, 4 shaders, the font and the card text** are byte-identical.
- **Sounds**: 13 of the 37 are byte-identical. 21 are re-encoded within 49–96 dB of the live sound (inaudible). Three noisy sounds (`applause`, `reroll`, `play`) drifted more when re-encoded, so they are imported uncompressed (`compress/mode=0`) and play sample-for-sample the same as the live game. That adds about 240 KB to `index.pck`.
- **Editor caches** inside the pack list the same entries, in a different order. The generated `cards.en.translation` has a new UID (it is loaded by path, so nothing depends on it).

## What came back

- **Scripts**: Godot stores them as a token stream that keeps every identifier, literal, line number and indentation level, so each file was decoded back to source.
- **`project.godot`**: every setting, autoloads in their original order.
- **Scenes** (`ui/main.tscn`, `ui/boot.tscn`), converted by Godot itself from the shipped binary scenes, with their node IDs.
- **The font** (`fonts/PixelifySans.ttf`), byte for byte.
- **The card text** (`i18n/cards.csv`): all 754 rows, in their original order. Godot keeps only hashes of the keys, so each key was found by hashing the IDs used in the code (`<id>.name`, `<id>.text`, `<id>.gloss`, `hand.<type>`) until all 754 matched; the row order comes from where each text sits in the shipped file.
- **Resource UIDs** for scripts, shaders, sounds, the font and the CSV.

## What was lost

- **Comments.** Godot drops them on export. The blank lines in the scripts are where comments used to be; line numbers match the original files.
- **Original formatting details**: number formats (for example `0xFFFFFFFF` comes back as `4294967295`) and spacing inside lines follow one consistent style rather than the original.
- **Original sound files.** The game shipped its sounds in Godot's lossy QOA format. The WAV files here were decoded from that, so they are what players heard, not the higher-quality originals.
- **The API's module layout.** The API source is the single bundled file that was deployed (`api/src/index.js`); the `// src/…` markers show where each original module (util, auth, mail, daily, pages, index) began.
- **Scene UIDs and the export preset**: scenes get new UIDs when the editor first saves them, and the Web export preset was recreated (no threads, compressed binary tokens), which reproduces the live web files exactly.

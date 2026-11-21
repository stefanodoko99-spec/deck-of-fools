# Jester art

Jesters can have an illustration instead of the figure drawn in code. The card uses
`game/art/jesters/<jester_id>.webp` when it exists and falls back to the drawn design
(`game/ui/jester_designs.gd`) when it doesn't, so art can arrive one Jester at a time.

Done so far (22 November 2026): `z_arlecchino`, `z_zanni`. 148 to go.

## Style

Stylised collectible-card illustration: exaggerated, dynamic poses, inked outlines,
painted texture, bold saturated colour, a simple backdrop in the Jester's own colour
with a faint gold pattern. Not photographic. The playing cards stay plain and white; the Jesters are
the loud part of the table.

## Making one in Adobe Firefly

Settings: **Firefly Image 5**, **Portrait 3:4**, **1K** (gives 896×1152).

Prompt template (fill the braces from the Jester's entry in `jester_designs.gd` and its
card text):

> Stylized collectible card game character illustration of {name}, {who they are in one
> phrase}. Exaggerated heroic proportions, {pose}, {face and mask}, {hat}, {costume:
> colours and pattern}, {prop}. Painterly comic-book rendering with clean confident
> shapes, strong ink-like edges and hand-painted texture, dramatic low camera angle,
> punchy {rim colours} rim light. Background: simple deep {backdrop} gradient with faint
> gold {pattern} and a few glowing confetti sparks. Bold saturated palette, high
> contrast, not photographic, not realistic skin. No text, no border, no frame.

Take {backdrop} and {pattern} from the design's first two fields (for example `rust`,
`rays` gives "rust-red gradient with faint gold sunburst rays"), so each Jester keeps
the colour players already know it by. Ask for "full figure with the head in the upper
third of the frame".

The prompt that made Arlecchino:

> Stylized collectible card game character illustration of Arlecchino, the mischievous
> commedia dell'arte jester. Exaggerated heroic proportions, lean acrobatic body caught
> mid-leap, wide cheeky grin under a glossy black half-mask, black bicorne hat tilted,
> skin-tight costume of bold red and emerald green diamond patches, crisp white ruff,
> swinging a wooden slapstick toward the viewer with motion streaks. Painterly
> comic-book rendering with clean confident shapes, strong ink-like edges and
> hand-painted texture, dramatic low camera angle, punchy magenta and gold rim light.
> Background: simple deep plum gradient with a faint gold diamond lattice and a few
> glowing confetti sparks. Bold saturated palette, high contrast, not photographic, not
> realistic skin. No text, no border, no frame.

The prompt that made Zanni:

> Stylized collectible card game character illustration of Zanni, the scrappy,
> always-hungry servant clown of the commedia dell'arte. Exaggerated heroic proportions,
> wiry body in a bold forward-lunging pose, full figure with the head in the upper third
> of the frame, wide toothy grin under a brown leather half-mask with a long hooked nose,
> floppy cream flat cap, loose baggy cream linen shirt and trousers tied with a brown rope
> belt, swinging a bulging brown burlap sack over the shoulder with motion streaks.
> Painterly comic-book rendering with clean confident shapes, strong ink-like edges and
> hand-painted texture, dramatic low camera angle, punchy orange and gold rim light.
> Background: simple deep rust-red gradient with faint gold sunburst rays and a few
> glowing confetti sparks. Bold saturated palette, high contrast, not photographic, not
> realistic skin. No text, no border, no frame.

Composition: keep the head in the upper half. The name plate covers the bottom fifth
of the card, and the cost coin and the effect badge (taken from the design) sit in the top corners.

The free Firefly plan allows only a few generations a day, so the full set needs a paid
plan or many days.

## Adding it to the game

```sh
./art.sh z_arlecchino ~/Downloads/firefly-image.png
```

`art.sh` shrinks the image to at most 640 px wide, saves it as WebP, imports it with
mipmaps (smooth when shrunk onto a small card) and lossy storage (about 80 KB in the
download), and runs `check.sh`. Then look at it in the gallery: `./preview.sh` and
`?screen=big` or `?screen=jesters`.

Both files so far came from screen captures of the Firefly results (634×816, cropped by
3 px, `./art.sh <id> <png> 3`), because the download from Firefly was blocked in the
browser that made them. If you download the original 896×1152 file, run `art.sh`
again with it.

## Rights

Firefly Image 5 is the model Adobe offers as commercially safe. Check Adobe's current
generative AI terms for your plan before the App Store release, and keep the Firefly
history (or the downloaded files with their Content Credentials) as the record of where
each image came from.

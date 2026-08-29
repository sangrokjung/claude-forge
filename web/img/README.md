# Mascot and social assets

Forge, the blacksmith robot, is the character the onboarding page talks through.
Only the web-sized files live here. The 1024px sources and the intermediate cutouts
are archived outside the repository so a clone stays small.

| File | Used by | Size |
|---|---|---|
| `face-idle.png` | chat avatar, steps 1–2 and 4, plus the header mark | 128×128 |
| `face-plead.png` | chat avatar on the star step | 128×128 |
| `face-cheer.png` | chat avatar on the final step | 128×128 |
| `forge-hero.png` | full-body greeting above the first bubble | 420×493 |
| `forge-party.png` | full-body celebration in the done panel | 420×481 |
| `og.jpg` | Open Graph / Twitter card | 1200×630 |

Everything is quantised to a 128–200 colour palette, which is visually identical at
display size and roughly a fifth of the weight. The six files total about 200 KB.

## Regenerating

The character was generated with `gpt-image-2`, then cut out and cropped by the two
scripts here. Two things to know if you redo it:

**The model cannot produce a transparent background.** Ask for one and it paints a
checkerboard *into* the image. `cutout.py` removes it by flood-filling from the edges
over pixels that are both light and neutral, so highlights inside the character
survive. A plain white background works the same way.

```bash
python3 cutout.py raw.png forge-full.png --trim --pad 8
```

**Head position moves between poses**, so the avatar crop is found by locating the
amber eye glow rather than by fixed coordinates.

```bash
python3 facecrop.py forge-full.png face-idle.png 128
```

Keep new expressions consistent by passing an existing render as a reference:

```bash
python3 ~/.claude/commands/generate-image/scripts/generate_image.py \
  "The same small robot blacksmith character, <new pose>, flat vector illustration \
   with bold clean outlines, centered full body, solid plain white background, no text" \
  --ref forge-idle.png -a 1:1 -o raw-new.png
```

`og.jpg` is rendered from `_og.html` at the repo's `web/` root rather than generated,
because image models do not draw reliable text. Serve `web/` and screenshot that page
at 1200×630.

Archived sources: `~/.claude/artifacts/claude-forge-mascot-20260822/`

## Deploying to GitHub Pages

`cutout.py`, `facecrop.py`, and any `__pycache__/` here are build tooling, not site
assets. When publishing `web/` to the `gh-pages` branch, copy only the HTML, `i18n/`,
and image files — exclude `*.py` and `__pycache__/` (the current `gh-pages` branch
already follows this).

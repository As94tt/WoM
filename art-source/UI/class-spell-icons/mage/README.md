# WoM – Mage Spell Icons (28)

This standalone package covers **all 7 base Arcane spells** and their **7 Fire, 7 Frost, and 7 Lightning specialization transformations** from the supplied spell list. The specialization artwork is paired with the underlying base spell, not added as a second action-bar button.

## Ready-to-import assets

- `game/assets/ui/icons/abilities/mage/arcane/` – 7 baseline icons.
- `game/assets/ui/icons/abilities/mage/fire/` – 7 Fire icons.
- `game/assets/ui/icons/abilities/mage/frost/` – 7 Frost icons.
- `game/assets/ui/icons/abilities/mage/lightning/` – 7 Lightning icons.
- All 28 files are **128 × 128 RGBA PNG** with embedded **sRGB** ICC profile, lower-case English filenames, no text, no standalone gold slot frame. These are full square icons with a simple dark background (opaque alpha), not transparent-background cutouts.
- `docs/spell_icon_manifest.json` and `.csv`: German display names, spell family, level and effects quoted from the user's list, plus English asset paths.
- `previews/mage_icons_all_28.png`: visual inventory with German labels.
- `previews/game_size_48px.png`: display-size test for typical action-bar slots.
- `previews/mage_spell_atlas_4x7.png`: optional atlas, column order arcane/fire/frost/lightning and row order missile/touch/impact/shield/step/nova/bind.

## Godot implementation notes for Claude

1. Copy the folder `game/assets/ui/icons/abilities/mage` into the game's corresponding `game/assets/ui/icons/abilities/` location. Do not overwrite or modify the original class or ability IDs in the gameplay data.
2. Reference the correct `icon_path` from the manifest for each existing spell ID. The **specialization replaces the image for the same base-spell slot**. Do not display both at the same time unless the actual game logic calls for it.
3. Display icons inside the already approved slim stone/gold `SlotButton` graphics; **do not put a second frame around them**. Keep the bottom-right area usable for shortcut/cooldown overlays.
4. Import with mipmaps for 48px and 40px displays. Review the 48px preview to decide filtering (usually linear + mipmaps for these painterly images).
5. The names in `english_id` are filenames, NOT authoritative Godot Resource or CSV IDs. Bind them to the existing game data explicitly.
6. Do not infer additional damage values or new mechanics from icon artwork. The descriptions in the manifest only summarize the original supplied specification.

## Visual and source limitations

The assets are **cropped and enlarged from newly generated art**, not 28 independently layered original artworks. They have no editable SVG/vector source, and source illustration resolution within each crop is lower than the exported 128px size. They are suitable as first-pass game assets, particularly at 40–48px, but should be visually verified inside Godot. The `art_reference` image contains the generated comparison layout; it is included strictly as visual reference, **not** for direct in-game import.

### Spell systems

- Fire: **Brand** stacks up to 5, lasts 10s, reapplication refreshes duration; some spells detonate all stacks in an area.
- Frost: non-stacking movement slow, stronger versions override weaker slows; frost areas persist.
- Lightning: **Ladung** stacks up to 5, lasts 8s, raises lightning damage; Donnerschlag spends stacks and chains once as described in user spec.

## Quality checks

Run a test scene displaying the whole icon atlas at both 128px and 48px. In particular inspect the edges of the lightning icons for stray highlights and verify the spell-specific mechanics against the actual current data before deployment.

# WoM – Warrior Ability Icons (32 files)

The package contains **all 8 Warrior base abilities**, plus their **8 Bulwark, 8 Berserker and 8 Battle Master mappings**, from the German specification supplied in chat. Each specialization replaces the matching icon in the **same action slot**. They are not additional abilities or slots.

## Folder map

- `game/assets/ui/icons/abilities/warrior/base/` – 8 basic physical Warrior icons.
- `game/assets/ui/icons/abilities/warrior/bulwark/` – 8 tank variants.
- `game/assets/ui/icons/abilities/warrior/berserker/` – 8 fast-damage variants.
- `game/assets/ui/icons/abilities/warrior/battle_master/` – 8 heavy-damage variants.
- `docs/ability_icon_manifest.json` + `.csv` – source German names, English suggested filenames, level, specialization, user-specified effects, icon path, equipment restrictions and proc flags.
- `docs/warrior_mechanics_reference.json` – extra mechanics from the user's specification; not authoritative game code.
- `previews/warrior_icons_all_32.png` – contact sheet with German names.
- `previews/warrior_icons_48px.png` – realistic actionbar resolution test.
- `previews/warrior_ability_atlas_4x8.png` – optional atlas, rows are abilities, columns are base / bulwark / berserker / battle_master.
- `art_reference/` – AI-generated source artwork used for preparing the PNG crops; **not for direct in-game import**.

## Technical specification

- All files: **128 × 128 RGBA PNG, embedded sRGB ICC profile**; opaque subdued dark backdrops; no overlaid text or separate gold slot frame.
- Suitable for rendering at 48 × 48 in the compact stone-and-gold actionbar. Use the slot border provided by the UI assets separately.
- **32 game paths, 29 unique artworks**. `bulwark/shield_bash.png`, `berserker/last_stand.png`, and `battle_master/last_stand.png` are intentionally byte-identical copies of their original base icons because those artworks do not change.
- The 8 base icons were scaled from a generated eight-icon sheet. The other variant icons are crops from a generated reference overview. They are not independently drawn at 128 px or provided as vector/SVG. Visual inspection in Godot at 48 px is required.

## Important for Claude / Godot implementation

1. Copy only `game/assets/ui/icons/abilities/warrior/` to the corresponding location in the game. Do **not** import the preview, reference images or metadata as live game icons.
2. Bind the `icon_path` field to each existing game's ability ID **using the game's actual data**. Filenames are proposed **English** names and not replacement Godot Resource IDs.
3. The Warrior has the rage resource `Wut`. This pack does not supply resource bar UI; use the already approved resource UI.
4. There are **8 base action slots**, not 32 extra slots. On specialization, replace a slot's icon and active spell data with its mapping from the manifest.
5. **Shield Bash / Schildschlag:** in `base` and `bulwark` it **requires an equipped shield**. Without shield, show a gray/disabled icon and the error `Benötigt einen Schild`. `berserker/rage_strike` and `battle_master/mortal_strike` explicitly **do not require a shield**.
6. **Bulwark retaliation / Vergeltung:** only available for 5 seconds after `Rache` triggers on dodge/parry/block. Reuse the existing `SlotProcGlow` effect. It consumes no rage. Successful block generates 5 rage.
7. **Berserker Frenzy / Raserei:** up to 5 stacks, 10 seconds; each 30 rage spent awards 1 stack, +3% haste each. At 5 stacks, `Blutrausch` lasts 8 seconds, abilities cost no rage, after which all stacks expire.
8. **Battle Master Deep Wound / Tiefe Wunde:** bleed up to 3 stacks, 12 seconds. `execute / Hinrichten` only available when target HP <20%, optionally spends up to 40 extra rage for bonus damage.
9. **Last Stand / Letztes Gefecht** in Berserker and Battle Master should remain the same ability and artwork as base, while Bulwark changes it to Shield Wall.
10. Keep full gameplay rules, cooldowns, requirements and effect magnitudes in the game data as the source of truth. The icon pack only maps visuals; the data does not replace actual gameplay configuration.
11. In Godot import at intended sizes with mipmaps. Test at 48px in both actionbar and talent/spellbook UI. Pay attention to source-crop sharpness and any residual ornamental details from the generated reference sheets.

## Naming / license

Original image-generation content only, no direct third-party game assets or copyrighted WoW motifs. `art_reference/` is included solely for traceability. No font licenses are relevant. Do not treat the reference-sheet labels as gameplay assets.

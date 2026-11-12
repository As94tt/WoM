# Animationen – Quelle und Lizenz

## UAL1_Standard.glb

- **Werk:** Universal Animation Library (Standard-Fassung), Datei `Unreal-Godot/UAL1_Standard.glb` (ohne Root Motion)
- **Urheber:** Quaternius – https://quaternius.itch.io/universal-animation-library
- **Lizenz:** CC0 1.0 Universal (Public Domain Dedication), siehe `UAL1_License.txt`
- **Übernommen:** unverändert für Ticket #59 (Grundanimationen der Spielfigur)

## Import (reproduzierbar ohne Editor-Klicks)

`UAL1_Standard.glb.import` importiert die Datei als **AnimationLibrary** und bildet
das Unreal-Skelett (`pelvis`, `spine_01`, `thigh_l` …) per BoneMap
`res://assets/rig/ual_bone_map.tres` auf `SkeletonProfileHumanoid` ab
(Knochen umbenannt, Skelett eindeutig als `%GeneralSkeleton`, Ruhepose per
„Fix Silhouette“ angeglichen). Dadurch passen die Spuren auf jedes Modell, das
mit einer Profil-BoneMap importiert ist (z. B. `res://assets/rig/humanoid_profile_bone_map.tres`
für Skelette, deren Knochen schon die Profilnamen tragen).

Welche Clips das Spiel nutzt und wie schnell sie laufen, steht in
`res://data/animations/grundanimationen.tres`.

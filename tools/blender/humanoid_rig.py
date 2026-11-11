"""Humanoid-Deform-Skelett für Godot 4 (SkeletonProfileHumanoid).

Baut aus einem Charakter-Mesh in T-Pose ein Skelett, dessen Knochennamen
exakt Godots SkeletonProfileHumanoid entsprechen, und bindet das Mesh daran.
Die Gelenkpositionen werden aus den Vertices des Körper-Meshes gemessen,
damit dasselbe Skript für alle Völker funktioniert (Normal, Kompakt, Massiv,
Groß und gebeugt).

Voraussetzungen am Mesh:
- T-Pose, Arme waagerecht entlang X, Blick nach -Y (Blender-Standard)
- symmetrisch zu X = 0; +X ist die linke Seite des Charakters
- Körper-Mesh ist ein eigenes Objekt (Rüstung o. Ä. dürfen getrennt sein)

Verwendung in Blender (Scripting-Tab oder per MCP):

    import runpy
    rig = runpy.run_path(r"C:\\Users\\alexs\\WoM\\tools\\blender\\humanoid_rig.py")
    rig["run"](body="Human_Body", parts=["Human_Body"], target_height=1.78)

Schritte einzeln: prepare() -> measure() -> build_armature() -> bind().
Gemessene Werte lassen sich vor dem Bauen über `overrides` korrigieren.

Noch nicht enthalten: Finger, Augen, Kiefer (gehören zum Godot-Profil,
kommen später) und die Befestigungspunkte aus dem GDD (Zusatzknochen).
"""

import bpy
from mathutils import Matrix, Vector

# Knochen: (Name, Eltern, mit Eltern verbunden?)
# Rechte Seite wird aus der linken gespiegelt.
CENTER_BONES = [
    ("Root", None, False),
    ("Hips", "Root", False),
    ("Spine", "Hips", True),
    ("Chest", "Spine", True),
    ("UpperChest", "Chest", True),
    ("Neck", "UpperChest", True),
    ("Head", "Neck", True),
]
SIDE_BONES = [
    ("Shoulder", "UpperChest", False),
    ("UpperArm", "Shoulder", True),
    ("LowerArm", "UpperArm", True),
    ("Hand", "LowerArm", True),
    ("UpperLeg", "Hips", False),
    ("LowerLeg", "UpperLeg", True),
    ("Foot", "LowerLeg", True),
    ("Toes", "Foot", True),
]

# Bone Roll: Richtung, in die die lokale Z-Achse des Knochens zeigt
FORWARD = Vector((0, -1, 0))
UP = Vector((0, 0, 1))
ROLL_UP = {"Shoulder", "UpperArm", "LowerArm", "Hand", "Foot", "Toes"}

# Godot verlangt den Root-Knochen, er bekommt aber keine Gewichte
NON_DEFORM = {"Root"}


# ---------------------------------------------------------------------------
# Vorbereitung
# ---------------------------------------------------------------------------

def _world_points(ob):
    mw = ob.matrix_world
    return [mw @ v.co for v in ob.data.vertices]


def prepare(body, parts, target_height):
    """Skaliert alle Teile gemeinsam auf target_height (Meter), stellt die
    Füße auf z = 0, zentriert auf X/Y = 0 und übernimmt die Transformation."""
    body_ob = bpy.data.objects[body]
    pts = _world_points(body_ob)
    zmin = min(p.z for p in pts)
    zmax = max(p.z for p in pts)
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    # Y-Mitte aus der Rumpfmitte (nur nahe X = 0), nicht aus Füßen, Armen oder Bauch
    H = zmax - zmin
    hz = zmin + 0.55 * H
    band = [p for p in pts if abs(p.z - hz) < 0.03 * H and abs(p.x - cx) < 0.07 * H]
    cy = (min(p.y for p in band) + max(p.y for p in band)) / 2
    s = target_height / (zmax - zmin)
    t = Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -zmin))

    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    for name in parts:
        ob = bpy.data.objects[name]
        ob.matrix_world = t @ ob.matrix_world
        ob.select_set(True)
    bpy.context.view_layer.objects.active = body_ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return {"scale": s, "height_before": zmax - zmin}


# ---------------------------------------------------------------------------
# Messung
# ---------------------------------------------------------------------------

def _bbox_center(ps, axis):
    vs = [getattr(p, axis) for p in ps]
    return (min(vs) + max(vs)) / 2


def _extent(ps, axis):
    vs = [getattr(p, axis) for p in ps]
    return max(vs) - min(vs)


def _need(ps, what, n=3):
    if len(ps) < n:
        raise RuntimeError(f"Messung fehlgeschlagen: zu wenige Punkte für {what}")
    return ps


def measure(body, overrides=None):
    """Misst die Gelenke der linken Seite und der Mitte aus dem Körper-Mesh.
    Erwartet ein vorbereitetes Mesh (Füße auf z = 0). Gibt {Knochen: (Kopf, Ende)}
    zurück. `overrides` ersetzt einzelne Gelenkpunkte, z. B. {"knee": (x, y, z)}."""
    pts = _world_points(bpy.data.objects[body])
    H = max(p.z for p in pts)
    xmax = max(p.x for p in pts)

    def zslice(z, h, pred=lambda p: True):
        return [p for p in pts if abs(p.z - z) < h and pred(p)]

    def xslice(x, h):
        return [p for p in pts if abs(p.x - x) < h]

    is_leg = lambda p: p.x > 0.015 * H

    # --- Beine ------------------------------------------------------------
    # Schritt: unterste Höhe, ab der die Mitte zwischen den Beinen gefüllt ist
    crotch = None
    z = 0.05 * H
    while z < 0.7 * H:
        if any(abs(p.x) < 0.02 * H for p in zslice(z, 0.0025 * H)):
            crotch = z
            break
        z += 0.005 * H
    if crotch is None:
        raise RuntimeError("Messung fehlgeschlagen: Schritt nicht gefunden")

    hip_z = crotch + 0.025 * H
    thigh = _need(zslice(crotch - 0.04 * H, 0.01 * H, is_leg), "Oberschenkel")
    hip = Vector((_bbox_center(thigh, "x"), 0.0, hip_z))

    # Fuß: Länge aus den untersten Punkten; Knöchel = erste Höhe, ab der
    # das Bein deutlich schmaler (in Y) ist als der Fuß lang
    sole = _need([p for p in pts if p.z < 0.04 * H and is_leg(p)], "Fuß")
    toe_y = min(p.y for p in sole)
    heel_y = max(p.y for p in sole)
    foot_len = heel_y - toe_y
    ankle = None
    z = 0.04 * H
    while z < 0.2 * H:
        s = zslice(z, 0.005 * H, is_leg)
        if len(s) >= 5 and _extent(s, "y") < 0.45 * foot_len:
            ankle = Vector((_bbox_center(s, "x"), _bbox_center(s, "y"), z))
            break
        z += 0.005 * H
    if ankle is None:
        raise RuntimeError("Messung fehlgeschlagen: Knöchel nicht gefunden")

    # Knie: dünnste Stelle im mittleren Bereich zwischen Knöchel und Hüfte
    best = None
    lo, hi = ankle.z + 0.35 * (hip_z - ankle.z), ankle.z + 0.65 * (hip_z - ankle.z)
    z = lo
    while z < hi:
        s = zslice(z, 0.005 * H, is_leg)
        if len(s) >= 8:
            area = _extent(s, "x") * _extent(s, "y")
            if best is None or area < best[0]:
                best = (area, s, z)
        z += 0.005 * H
    _need(best[1] if best else [], "Knie")
    # leicht nach vorne, damit die Knickrichtung eindeutig ist
    knee = Vector((_bbox_center(best[1], "x"), _bbox_center(best[1], "y") - 0.01 * H, best[2]))

    ball = Vector((ankle.x, toe_y + 0.26 * foot_len, 0.017 * H))
    toe_tip = Vector((ankle.x, toe_y, 0.01 * H))

    # --- Arme -------------------------------------------------------------
    outer = _need([p for p in pts if p.x > 0.6 * xmax], "Unterarm/Hand")
    arm_z = _bbox_center(outer, "z")
    # Achsel: erste X-Position, ab der der Querschnitt nicht mehr in den Rumpf reicht
    armpit_x = None
    x = 0.05 * H
    while x < xmax:
        s = xslice(x, 0.005 * H)
        if s and min(p.z for p in s) > arm_z - 0.08 * H:
            armpit_x = x
            break
        x += 0.005 * H
    if armpit_x is None:
        raise RuntimeError("Messung fehlgeschlagen: Achsel nicht gefunden")

    def thinnest(x0, x1, what):
        best = None
        x = x0
        while x < x1:
            s = xslice(x, 0.005 * H)
            if len(s) >= 8:
                area = _extent(s, "z") * _extent(s, "y")
                if best is None or area < best[0]:
                    best = (area, s, x)
            x += 0.005 * H
        _need(best[1] if best else [], what)
        return Vector((best[2], _bbox_center(best[1], "y"), _bbox_center(best[1], "z")))

    wrist = thinnest(armpit_x + 0.55 * (xmax - armpit_x), armpit_x + 0.85 * (xmax - armpit_x), "Handgelenk")
    elbow = thinnest(armpit_x + 0.25 * (wrist.x - armpit_x), armpit_x + 0.75 * (wrist.x - armpit_x), "Ellbogen")
    sa = _need(xslice(armpit_x + 0.01 * H, 0.005 * H), "Schulter")
    shoulder_joint = Vector((0.89 * armpit_x, _bbox_center(sa, "y"), _bbox_center(sa, "z")))
    hand_end = wrist.lerp(Vector((xmax, wrist.y, wrist.z)), 0.62)

    # --- Rumpf, Hals, Kopf ------------------------------------------------
    def torso_y(z, w):
        return _bbox_center(_need(zslice(z, 0.01 * H, lambda p: abs(p.x) < w), f"Rumpf bei z={z:.2f}"), "y")

    # Hals: schmalste Stelle der Mittelsäule oberhalb der Schultern
    best = None
    z = arm_z + 0.05 * H
    while z < 0.95 * H:
        s = zslice(z, 0.005 * H, lambda p: abs(p.x) < 0.12 * H)
        if len(s) >= 5:
            w = _extent(s, "x")
            if best is None or w < best[0]:
                best = (w, z)
        z += 0.005 * H
    head_z = best[1]
    neck_z = arm_z + 0.067 * H

    def spine_at(f):
        return hip_z + f * (neck_z - hip_z)

    spine = {name: Vector((0, torso_y(z, 0.07 * H), z)) for name, z in (
        ("Hips", hip_z), ("Spine", spine_at(0.207)), ("Chest", spine_at(0.448)),
        ("UpperChest", spine_at(0.672)), ("Neck", neck_z))}
    # In Hüfthöhe fehlt vorne Geometrie (Lücke zwischen den Beinen), der Schnitt
    # läge zu weit hinten; Hüfte bekommt deshalb die Tiefe des Spine-Knochens
    spine["Hips"].y = spine["Spine"].y
    hip.y = spine["Hips"].y
    head_y = (spine["Neck"].y + torso_y(0.967 * H, 0.06 * H)) / 2
    spine["Head"] = Vector((0, head_y, head_z))
    head_top = Vector((0, head_y, H))
    clavicle = Vector((0.032 * H, spine["UpperChest"].y - 0.014 * H, arm_z + 0.038 * H))

    joints = {
        "hip": hip, "knee": knee, "ankle": ankle, "ball": ball, "toe_tip": toe_tip,
        "clavicle": clavicle, "shoulder": shoulder_joint, "elbow": elbow, "wrist": wrist,
        "hand_end": hand_end, "head_top": head_top,
    }
    joints.update({k.lower(): v for k, v in spine.items()})
    for k, v in (overrides or {}).items():
        joints[k] = Vector(v)
    j = joints

    return {
        "Root": (Vector((0, 0, 0)), Vector((0, 0, 0.06 * H))),
        "Hips": (j["hips"], j["spine"]),
        "Spine": (j["spine"], j["chest"]),
        "Chest": (j["chest"], j["upperchest"]),
        "UpperChest": (j["upperchest"], j["neck"]),
        "Neck": (j["neck"], j["head"]),
        "Head": (j["head"], j["head_top"]),
        "Shoulder": (j["clavicle"], j["shoulder"]),
        "UpperArm": (j["shoulder"], j["elbow"]),
        "LowerArm": (j["elbow"], j["wrist"]),
        "Hand": (j["wrist"], j["hand_end"]),
        "UpperLeg": (j["hip"], j["knee"]),
        "LowerLeg": (j["knee"], j["ankle"]),
        "Foot": (j["ankle"], j["ball"]),
        "Toes": (j["ball"], j["toe_tip"]),
    }


# ---------------------------------------------------------------------------
# Skelett
# ---------------------------------------------------------------------------

def _mirror(v):
    return Vector((-v.x, v.y, v.z))


def build_armature(bones, name="Armature", collection=None):
    """Erzeugt das Armature-Objekt aus measure()-Ergebnis. Rechte Seite gespiegelt."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    data = bpy.data.armatures.new(name)
    data.display_type = "OCTAHEDRAL"
    arm = bpy.data.objects.new(name, data)
    (collection or bpy.context.scene.collection).objects.link(arm)
    arm.show_in_front = True
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones

    plan = [(n, p, c, bones[n][0], bones[n][1], n) for n, p, c in CENTER_BONES]
    for side, flip in (("Left", False), ("Right", True)):
        for n, p, c in SIDE_BONES:
            head, tail = bones[n]
            if flip:
                head, tail = _mirror(head), _mirror(tail)
            parent = p if p in dict((b[0], 1) for b in CENTER_BONES) else side + p
            plan.append((side + n, parent, c, head, tail, n))

    for full, parent, connect, head, tail, base in plan:
        b = eb.new(full)
        b.head, b.tail = head, tail
        b.use_deform = full not in NON_DEFORM
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        b.align_roll(UP if base in ROLL_UP else FORWARD)

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind(arm, meshes):
    """Bindet die Meshes mit automatischen Gewichten. Der Armature-Modifier
    kommt an erste Stelle, damit er vor Subdivision u. Ä. wirkt."""
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    for name in meshes:
        bpy.data.objects[name].select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    report = {}
    for name in meshes:
        ob = bpy.data.objects[name]
        mod = next(m for m in ob.modifiers if m.type == "ARMATURE")
        with bpy.context.temp_override(object=ob):
            bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        filled = fill_unweighted(arm, ob)
        report[name] = {"vertices": len(ob.data.vertices), "nachgetragen": filled}
    return report


def _islands(me, indices):
    """Zerlegt die Punkte `indices` in zusammenhängende Teile (über Kanten)."""
    nbr = {i: [] for i in indices}
    for e in me.edges:
        a, b = e.vertices
        if a in nbr and b in nbr:
            nbr[a].append(b)
            nbr[b].append(a)
    seen, out = set(), []
    for i in indices:
        if i in seen:
            continue
        stack, isl = [i], []
        seen.add(i)
        while stack:
            k = stack.pop()
            isl.append(k)
            for o in nbr[k]:
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
        out.append(isl)
    return out


def fill_unweighted(arm, ob):
    """Punkte ohne Knochengewicht (z. B. eingeschlossene Augäpfel, an denen die
    automatische Gewichtung scheitert) bekommen je zusammenhängendem Teil die
    Gewichte des nächstgelegenen gewichteten Punkts. Das Teil bewegt sich
    dadurch starr mit der umgebenden Haut. Gibt die Anzahl Punkte zurück."""
    bones = {b.name for b in arm.data.bones if b.use_deform}
    gname = {g.index: g.name for g in ob.vertex_groups}
    me = ob.data

    def bone_weights(v):
        return {gname[g.group]: g.weight for g in v.groups if gname[g.group] in bones and g.weight > 0}

    missing = [v.index for v in me.vertices if not bone_weights(v)]
    if not missing:
        return 0
    donors = [v for v in me.vertices if bone_weights(v)]
    count = 0
    for isl in _islands(me, missing):
        center = sum((me.vertices[i].co for i in isl), Vector()) / len(isl)
        if donors:
            src = bone_weights(min(donors, key=lambda v: (v.co - center).length))
        else:
            # Objekt ganz ohne Gewichte: nächster Knochen
            mw = ob.matrix_world
            p = mw @ center
            src = {min((b for b in arm.data.bones if b.use_deform),
                       key=lambda b: ((arm.matrix_world @ b.center) - p).length).name: 1.0}
        for bone, w in src.items():
            group = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
            group.add(isl, w, "REPLACE")
        count += len(isl)
    return count


def run(body, parts, target_height, name="Armature", overrides=None, collection=None):
    """Alles in einem: vorbereiten, messen, bauen, binden."""
    prep = prepare(body, parts, target_height)
    bones = measure(body, overrides)
    arm = build_armature(bones, name, collection)
    weights = bind(arm, parts)
    return {"prepare": prep, "bones": {k: [list(map(lambda c: round(c, 3), v)) for v in hv] for k, hv in bones.items()},
            "weights": weights, "armature": arm.name}

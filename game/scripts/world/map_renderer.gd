class_name MapRenderer
extends Node
## Rendert beim Start einmal ein Bild der Welt von oben (Ticket #15) für das
## Kartenfenster: orthografische Kamera in einem SubViewport, der dieselbe
## 3D-Welt zeigt. Die Kamera sieht nur die Sichtbarkeitsebene „Welt“;
## Platzhalter und Grenzanzeigen (Ebene „Entwicklung“) fehlen im Bild.
## Spielfiguren blendet GameWorld während des Renderns aus.
## Jede Instanz rendert ihre Karte selbst; nichts wird übertragen.
## Ohne Grafikausgabe (--headless) gibt es kein Bild (null).

## Fertig gerendert; texture ist null, wenn kein Bild möglich war.
signal map_rendered(texture: Texture2D)

## Kantenlänge des Bilds in Pixeln.
@export var resolution: int = 1024
## Sichtbarkeitsebenen, die im Kartenbild erscheinen (Bitmaske; 1 = „Welt“).
@export_flags_3d_render var cull_mask: int = 1

var texture: Texture2D = null


## Rendert den Ausschnitt rect (Welt-XZ, quadratisch) von oben.
func render(rect: Rect2) -> void:
	if DisplayServer.get_name() == "headless":
		map_rendered.emit.call_deferred(null)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(resolution, resolution)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_4X
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(rect.size.x, rect.size.y)
	camera.cull_mask = cull_mask
	camera.near = 1.0
	camera.far = 1000.0
	# Blick senkrecht nach unten; oben im Bild ist Norden (-Z).
	var center := rect.get_center()
	camera.transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)),
			Vector3(center.x, 500.0, center.y))
	viewport.add_child(camera)
	add_child(viewport)
	camera.make_current()
	# UPDATE_ONCE rendert im nächsten Bild; danach ist das Bild abholbereit.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image != null and not image.is_empty():
		texture = ImageTexture.create_from_image(image)
	map_rendered.emit(texture)

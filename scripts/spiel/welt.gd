extends Node2D

## **Ein Teil des Spielfelds im Pixelpuffer.**
##
## Die Figuren werden nicht mehr vom Wurzelknoten gezeichnet, sondern in
## einem Unterbild mit einem Drittel der Aufloesung (siehe `gefecht.tscn`).
## Drei Teile, in dieser Reihenfolge: was hinter dem Helden steht, das Loch
## um ihn (eigenes Material, `loch.gdshader`), und er selbst mit allem davor.
## Der Teil fragt den Lauf, was er zeichnen soll - die Wahrheit bleibt dort.

@export var teil := 0
var lauf: Node


func _draw() -> void:
    if lauf != null:
        lauf.zeichne_teil(teil, get_canvas_item())

## Kopfzeile mit Guthaben, Ertrag und Protokollen.
##
## Bewusst schlank gehalten: die vollstaendige Bedienoberflaeche entsteht in
## Phase 3. Hier zaehlt nur, dass die Zahlen waehrend des Spielens sichtbar sind.
class_name Hud
extends Control


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Anker allein genuegen nicht: ein Control unmittelbar unter einem
    # CanvasLayer behaelt damit die Groesse (0, 0), und alles, was von der
    # Breite abhaengt, landet ausserhalb des Bildes. Offsets mitsetzen und
    # der Fenstergroesse folgen.
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _passe_groesse_an()
    get_viewport().size_changed.connect(_passe_groesse_an)
    Spielstand.plasma_geaendert.connect(func(_w): queue_redraw())
    Spielstand.protokolle_geaendert.connect(func(_w): queue_redraw())
    set_process(true)


func _passe_groesse_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


func _process(_delta: float) -> void:
    # Der Ertrag pro Sekunde aendert sich laufend; einmal je Bild neu zeichnen
    # ist billiger als ein Signal pro Tick.
    queue_redraw()


func _draw() -> void:
    var schrift := ThemeDB.fallback_font
    var breite := size.x

    draw_rect(Rect2(0.0, 0.0, breite, 104.0), Color(0.04, 0.05, 0.07, 0.88))
    draw_line(Vector2(0.0, 104.0), Vector2(breite, 104.0), Color(0.16, 0.20, 0.26), 2.0)

    draw_string(schrift, Vector2(22.0, 46.0), Waehrung.plasma(Spielstand.plasma),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.95, 0.97, 1.0))

    draw_string(schrift, Vector2(24.0, 76.0), Waehrung.plasma_rate(Spielstand.rate()),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.45, 0.85, 0.60))

    # Ein laufender Schub muss sichtbar sein - sonst wundert sich der Spieler
    # ueber die eingebrochene Foerderung, wenn er ablaeuft.
    if Spielstand.boost_aktiv():
        var text := "SCHUB x%d  %s" % [int(Spielstand.boost_faktor),
            Zahl.zeit(Spielstand.boost_rest())]
        var mitte := breite * 0.5
        draw_string(schrift, Vector2(mitte - 130.0, 76.0), text,
            HORIZONTAL_ALIGNMENT_CENTER, 260.0, 17, Color(1.0, 0.78, 0.36))

    if Spielstand.protokolle > 0:
        draw_string(schrift, Vector2(breite - 202.0, 46.0),
            "%d %s" % [Spielstand.protokolle, Waehrung.PROTOKOLLE],
            HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 20, Color(0.72, 0.62, 0.96))
        draw_string(schrift, Vector2(breite - 202.0, 74.0),
            "x%.2f" % Oekonomie.prestige_mult(Spielstand.protokolle),
            HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 16, Color(0.55, 0.50, 0.70))

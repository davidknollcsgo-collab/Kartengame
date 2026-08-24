## Ausbauten in zwei Reitern: Quanten und Protokolle.
##
## Zwei Reiter statt zweier Bildschirme, weil beide dieselbe Frage stellen -
## wofür gebe ich meine Sonderwährung aus? Und ein vierter Knopf in der
## Bedienleiste hätte die Trefferflächen wieder unter das gedrückt, was ein
## Daumen zuverlässig trifft.
class_name AusbauSchirm
extends Control

const ZEILE := 112.0

enum Reiter { QUANTEN, PROTOKOLLE }

signal geschlossen

var reiter := Reiter.QUANTEN

var _feld := Rect2()
var _schliessen := Rect2()
var _reiter_flaechen: Array[Rect2] = []
var _zeilen: Array[Rect2] = []
var _kennungen: PackedStringArray = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    Spielstand.quanten_geaendert.connect(func(_w): queue_redraw())
    Spielstand.protokolle_geaendert.connect(func(_w): queue_redraw())
    Spielstand.ausbau_geaendert.connect(queue_redraw)


func _passe_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


func _process(_delta: float) -> void:
    # Die Restlaufzeit des Schubs läuft weiter, während der Schirm offen ist.
    if visible and reiter == Reiter.QUANTEN and Spielstand.boost_aktiv():
        queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if not visible or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return

    for i in _reiter_flaechen.size():
        if _reiter_flaechen[i].has_point(m.position):
            reiter = i as Reiter
            queue_redraw()
            accept_event()
            return

    if _schliessen.has_point(m.position):
        visible = false
        geschlossen.emit()
        accept_event()
        return

    for i in _zeilen.size():
        if _zeilen[i].has_point(m.position):
            _kaufe(i)
            queue_redraw()
            accept_event()
            return
    accept_event()


func _kaufe(i: int) -> void:
    if reiter == Reiter.QUANTEN:
        match i:
            0: Spielstand.kaufe_schub()
            1: Spielstand.kaufe_speicher()
            2: Spielstand.kaufe_verstaerker()
    elif i < _kennungen.size():
        Spielstand.kaufe_protokoll_ausbau(_kennungen[i])


## Die Angebote des aktiven Reiters als Anzeigedaten. An einer Stelle
## beschrieben, damit Zeichnen und Kaufabwicklung nicht auseinanderlaufen.
func _angebote() -> Array[Dictionary]:
    var s := Spielstand
    _kennungen = PackedStringArray()
    if reiter == Reiter.QUANTEN:
        return [
            {"name": "Schub",
             "text": "x%d Förderung für %s" % [int(Ausbau.SCHUB_FAKTOR),
                Zahl.zeit(Ausbau.SCHUB_DAUER)],
             "preis": Ausbau.SCHUB_KOSTEN,
             "moeglich": s.quanten >= Ausbau.SCHUB_KOSTEN,
             "stand": "läuft noch %s" % Zahl.zeit(s.boost_rest()) if s.boost_aktiv() else ""},
            {"name": "Langzeitspeicher",
             "text": "Abwesenheit zählt bis %s" % Zahl.zeit(s.offline_grenze()),
             "preis": Ausbau.speicher_preis(s.speicher_stufe),
             "moeglich": not Ausbau.speicher_voll(s.speicher_stufe) \
                and s.quanten >= Ausbau.speicher_preis(s.speicher_stufe),
             "stand": "Stufe %d von %d" % [s.speicher_stufe, Ausbau.SPEICHER_MAX]},
            {"name": "Orbital-Verstärker",
             "text": "Dauerhaft x%d auf alles" % int(Ausbau.VERSTAERKER_FAKTOR),
             "preis": Ausbau.VERSTAERKER_KOSTEN,
             "moeglich": not s.verstaerker and s.quanten >= Ausbau.VERSTAERKER_KOSTEN,
             "stand": "in Betrieb" if s.verstaerker else ""},
        ]

    var liste: Array[Dictionary] = []
    for e in ProtokollAusbau.TABELLE:
        var id := String(e["id"])
        _kennungen.append(id)
        var stufe := s.stufe_von(id)
        var max_stufe := ProtokollAusbau.max_stufe(id)
        var preis := ProtokollAusbau.kosten(id, stufe)
        liste.append({
            "name": e["name"],
            "text": e["text"],
            "preis": preis,
            "moeglich": preis > 0 and s.protokolle >= preis,
            "stand": "Stufe %d von %d" % [stufe, max_stufe],
        })
    return liste


func _draw() -> void:
    var titel := Schrift.titel()
    var text := Schrift.text()
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.80))

    var angebote := _angebote()
    # Kopf mit Kreuz und Reitern plus Zeilen plus Fuss.
    var hoehe := 142.0 + float(angebote.size()) * ZEILE
    _feld = Masse.fenster(size, hoehe)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.08, 0.10, 0.14, 0.98))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), Color(0.42, 0.62, 0.86), 2.0, true)

    _zeichne_kreuz()
    _zeichne_reiter(titel)

    _zeilen.clear()
    var y := _feld.position.y + 118.0
    for eintrag in angebote:
        _zeichne_zeile(Rect2(_feld.position.x + 22.0, y, _feld.size.x - 44.0,
            ZEILE - 12.0), eintrag, titel, text)
        y += ZEILE


func _zeichne_reiter(titel: Font) -> void:
    _reiter_flaechen.clear()
    var b := (_feld.size.x - 68.0) * 0.5
    var y := _feld.position.y + 52.0
    var daten := [
        ["QUANTEN", Waehrung.Art.QUANTEN, Spielstand.quanten],
        ["PROTOKOLLE", Waehrung.Art.PROTOKOLL, Spielstand.protokolle],
    ]
    for i in 2:
        var r := Rect2(_feld.position.x + 22.0 + float(i) * (b + 24.0), y, b, 50.0)
        _reiter_flaechen.append(r)
        var aktiv := int(reiter) == i
        var ton := Color(0.46, 0.80, 0.98) if aktiv else Color(0.34, 0.38, 0.46)
        draw_colored_polygon(Formen.kante(r, 10.0),
            Color(ton.r, ton.g, ton.b, 0.20 if aktiv else 0.06))
        draw_polyline(Formen.kante_umriss(r, 10.0), ton, 2.0, true)
        # Name links, Guthaben rechts - beide Zahlen sollen beim Wechseln
        # sichtbar bleiben, sonst tippt man blind auf den anderen Reiter.
        draw_string(titel, Vector2(r.position.x + 14.0, r.get_center().y + 6.0),
            daten[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
            Color(0.95, 0.97, 1.0) if aktiv else Color(0.58, 0.62, 0.70))
        Waehrung.zeichne(self, titel, Vector2(r.end.x - 14.0, r.get_center().y + 6.0),
            str(daten[i][2]), daten[i][1], 15,
            Color(0.70, 0.90, 1.0) if aktiv else Color(0.50, 0.54, 0.62),
            Waehrung.Lage.RECHTS)


func _zeichne_zeile(r: Rect2, eintrag: Dictionary, titel: Font, text: Font) -> void:
    var moeglich: bool = eintrag["moeglich"]
    var preis: int = eintrag["preis"]
    var ton := Color(0.42, 0.78, 0.96) if moeglich else Color(0.32, 0.35, 0.42)

    draw_colored_polygon(Formen.kante(r, 12.0), Color(0.12, 0.14, 0.19, 0.9))
    draw_polyline(Formen.kante_umriss(r, 12.0), ton, 2.0, true)
    _zeilen.append(r)

    draw_string(titel, Vector2(r.position.x + 20.0, r.position.y + 32.0),
        eintrag["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, 19,
        Color(0.94, 0.96, 1.0) if moeglich else Color(0.60, 0.64, 0.70))
    draw_string(text, Vector2(r.position.x + 20.0, r.position.y + 58.0),
        eintrag["text"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, 16,
        Color(0.60, 0.66, 0.74))

    var stand: String = eintrag["stand"]
    if not stand.is_empty():
        draw_string(text, Vector2(r.position.x + 20.0, r.position.y + 82.0),
            stand, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.48, 0.72, 0.60))

    var farbe := Color(0.62, 0.90, 0.72) if moeglich else Color(0.45, 0.48, 0.55)
    var art := Waehrung.Art.QUANTEN if reiter == Reiter.QUANTEN else Waehrung.Art.PROTOKOLL
    if preis <= 0:
        # Erschöpfte Angebote zeigen einen Strich statt einer Zahl, die man
        # ohnehin nicht mehr bezahlen kann.
        draw_string(titel, Vector2(r.position.x, r.get_center().y + 8.0), "—",
            HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0, 22, farbe)
    else:
        Waehrung.zeichne(self, titel, Vector2(r.end.x - 20.0, r.get_center().y + 8.0),
            str(preis), art, 22, farbe, Waehrung.Lage.RECHTS)


func _zeichne_kreuz() -> void:
    _schliessen = Rect2(_feld.end.x - Masse.TIPPFLAECHE - 14.0,
        _feld.position.y + 8.0, Masse.TIPPFLAECHE, Masse.TIPPFLAECHE)
    var m := _schliessen.get_center()
    var a := 11.0
    var f := Color(0.72, 0.78, 0.86)
    draw_line(m + Vector2(-a, -a), m + Vector2(a, a), f, 2.5, true)
    draw_line(m + Vector2(a, -a), m + Vector2(-a, a), f, 2.5, true)

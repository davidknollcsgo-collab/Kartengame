## Zugriff auf die beiden Projektschriften.
##
## Orbitron für Zahlen, Titel und Knopfbeschriftungen: geometrisch und
## technisch, aber breit - für längere deutsche Wörter untauglich.
## Rajdhani für Fließtext: schmal und auch bei 14 Punkten noch lesbar.
##
## Beide stehen unter der SIL Open Font License, die das Einbetten in
## kommerzielle Anwendungen ausdrücklich erlaubt. Herkunft und Lizenz stehen
## in ASSETS.md, die Lizenztexte liegen neben den Dateien.
class_name Schrift
extends RefCounted

const ORBITRON := "res://schriften/orbitron/Orbitron.ttf"
const RAJDHANI := "res://schriften/rajdhani/Rajdhani-Medium.ttf"

static var _titel: Font
static var _text: Font


## Für Zahlen, Titel und Knöpfe.
static func titel() -> Font:
    if _titel == null:
        _titel = _mit_rueckfall(ORBITRON)
    return _titel


## Für Beschreibungen und Listen.
static func text() -> Font:
    if _text == null:
        _text = _mit_rueckfall(RAJDHANI)
    return _text


## Lädt eine Schrift und hängt Godots eingebaute Schrift als Rückfall an.
##
## Beide Projektschriften enthalten die Währungszeichen ◆ und ✦ nicht. Ohne
## Rückfall zeichnet Godot dafür Ersatzkästchen - im Browserlauf stand
## überall "15 ▨" statt "15 ◆". Auf dem Entwicklungsrechner fiel das nicht
## auf, weil dort vorher die eingebaute Schrift verwendet wurde.
static func _mit_rueckfall(pfad: String) -> Font:
    var f: FontFile = load(pfad)
    if f != null and f.fallbacks.is_empty():
        f.fallbacks = [ThemeDB.fallback_font]
    return f

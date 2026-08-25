## Zugriff auf die beiden Projektschriften.
##
## Bricolage Grotesque für Überschriften und Zahlen: eigenwillig genug, dass
## das Spiel nicht nach Standardvorlage aussieht. Rajdhani für Fließtext, weil
## es schmal ist und auch bei vierzehn Punkten noch lesbar bleibt.
##
## Beide stehen unter der SIL Open Font License, die das Einbetten in
## kommerzielle Anwendungen ausdrücklich erlaubt. Herkunft und Lizenz stehen in
## ASSETS.md, die Lizenztexte liegen neben den Dateien.
class_name Schrift
extends RefCounted

const DISPLAY := "res://schriften/bricolage/BricolageGrotesque.ttf"
const TEXT := "res://schriften/rajdhani/Rajdhani-Medium.ttf"

static var _display: Font
static var _text: Font


static func display() -> Font:
    if _display == null:
        _display = _mit_rueckfall(DISPLAY)
    return _display


static func text() -> Font:
    if _text == null:
        _text = _mit_rueckfall(TEXT)
    return _text


## Lädt eine Schrift und hängt Godots eingebaute als Rückfall an.
##
## Fehlende Zeichen zeichnet Godot sonst als leere Kästchen. Auf dem
## Entwicklungsrechner springt oft eine Systemschrift ein - die es auf einem
## Handy oder im Web-Export nicht gibt.
static func _mit_rueckfall(pfad: String) -> Font:
    var f: FontFile = load(pfad)
    if f != null and f.fallbacks.is_empty():
        f.fallbacks = [ThemeDB.fallback_font]
    return f

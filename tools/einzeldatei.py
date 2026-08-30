"""Packt den Godot-Web-Export in eine einzige HTML-Datei.

Die Dateien werden gzip-komprimiert und base64 eingebettet; der Browser
entpackt sie beim Start über DecompressionStream und reicht sie als
Blob-Adressen an Godots Lader weiter. Ohne das Komprimieren waeren es
50 MB base64 - mit knapp 13 MB.
"""
import base64, gzip, pathlib, re, sys

quelle = pathlib.Path("docs")
ziel = pathlib.Path(sys.argv[1])


def projektname(voreinstellung="Spiel"):
    """Liest den Namen aus project.godot.

    Vorher stand er hier fest im Quelltext - und zeigte nach zwei
    Projektwechseln immer noch den Namen des vorletzten Spiels im
    Ladebildschirm. Ein Name, der an zwei Stellen gepflegt werden muss, wird
    an einer davon vergessen.
    """
    p = pathlib.Path("project.godot")
    if not p.exists():
        return voreinstellung
    treffer = re.search(r'^config/name="([^"]*)"', p.read_text(encoding="utf-8"),
                        re.MULTILINE)
    return treffer.group(1) if treffer else voreinstellung


NAME = projektname()

DATEIEN = {
    "index.js":                      "text/javascript",
    "index.wasm":                    "application/wasm",
    "index.pck":                     "application/octet-stream",
    "index.audio.worklet.js":        "text/javascript",
    "index.audio.position.worklet.js": "text/javascript",
}

bloecke = []
gesamt = 0
for name, typ in DATEIEN.items():
    p = quelle / name
    if not p.exists():
        print("fehlt, wird uebersprungen:", name)
        continue
    roh = gzip.compress(p.read_bytes(), 9)
    b64 = base64.b64encode(roh).decode("ascii")
    gesamt += len(b64)
    bloecke.append(
        '<script type="application/gzip-base64" '
        'data-name="%s" data-typ="%s">%s</script>' % (name, typ, b64)
    )
    print("%-34s %8.1f KB komprimiert" % (name, len(roh) / 1024))

# Der Ladebildschirm nimmt die Farben des Spiels vorweg: Grabenschwarz mit
# einem Blaugruen-Stich, das kalte Biolumineszenzblau als einzige Farbe. Ein
# neutrales Grau haette hier einen sichtbaren Bruch zum ersten Bild ergeben.
kopf = '''<title>%(name)s</title>
<style>
  :root {
    color-scheme: dark;
    --grund: #03060b;
    --tiefer: #071119;
    --schrift: #cfe4ea;
    --leise: #6d8890;
    --licht: #3ddcf5;
    --warnung: #f08a78;
  }
  html, body { margin: 0; padding: 0; height: 100%%; overflow: hidden;
    background: var(--grund); }
  #canvas { display: block; width: 100%%; height: 100%%; border: 0; outline: none;
    touch-action: none; }
  #canvas:focus { outline: none; }
  #laden {
    position: fixed; inset: 0; display: flex; flex-direction: column;
    align-items: center; justify-content: center; gap: 20px;
    /* Der Schein von unten - dieselbe Geste wie im Spiel, wo die Kolonie
       unten leuchtet und die Dunkelheit oben liegt. */
    background: radial-gradient(120%% 62%% at 50%% 118%%,
      #0d2b31 0%%, var(--tiefer) 46%%, var(--grund) 100%%);
    color: var(--schrift); z-index: 10;
    font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
  }
  #laden h1 { margin: 0; font-size: 24px; font-weight: 600; letter-spacing: .34em;
    text-indent: .34em; color: var(--schrift); }
  #laden h1 span { color: var(--licht); }
  #balken { width: min(260px, 62vw); height: 3px; border-radius: 2px;
    background: #10242b; overflow: hidden; }
  #fuellung { height: 100%%; width: 0%%; background: var(--licht);
    box-shadow: 0 0 12px var(--licht); transition: width .25s; }
  #stand { font-size: 13px; color: var(--leise); min-height: 1.2em;
    letter-spacing: .04em; }
  #fehler { color: var(--warnung); font-size: 13px; max-width: 80vw;
    text-align: center; }
  @media (prefers-reduced-motion: reduce) { #fuellung { transition: none; } }
</style>

<canvas id="canvas">Your browser does not support canvas.</canvas>

<div id="laden">
  <h1>%(kopfname)s</h1>
  <div id="balken"><div id="fuellung"></div></div>
  <div id="stand">preparing …</div>
  <div id="fehler"></div>
</div>
''' % {
    "name": NAME,
    # Der erste Buchstabe im Leuchtblau - ein Zeichen statt eines Logos.
    "kopfname": "<span>%s</span>%s" % (NAME[:1].upper(), NAME[1:].upper()),
}

fuss = r'''
<script>
(function () {
  var stand = document.getElementById("stand");
  var fuellung = document.getElementById("fuellung");
  var fehlerfeld = document.getElementById("fehler");
  var laden = document.getElementById("laden");

  function melde(text, anteil) {
    stand.textContent = text;
    if (anteil != null) fuellung.style.width = (anteil * 100) + "%";
  }
  function scheitere(text) {
    melde("", null);
    fehlerfeld.textContent = text;
  }

  if (typeof DecompressionStream === "undefined") {
    scheitere("Dieser Browser kann das Paket nicht entpacken. "
      + "Bitte einen aktuellen Chrome, Safari oder Firefox verwenden.");
    return;
  }

  // Base64 von Hand dekodieren statt ueber fetch("data:...").
  //
  // Die Seite laeuft unter einer strengen Inhaltsrichtlinie, die Anfragen an
  // data:- und blob:-Adressen abweist - der erste Versuch scheiterte genau
  // daran mit "Failed to fetch". atob mit einer einfachen Schleife braucht
  // keine Anfrage und ist bei zwoelf Megabyte trotzdem schnell genug;
  // entscheidend ist die Schleife statt Uint8Array.from mit Rueckruf, das
  // waere um Groessenordnungen langsamer.
  function ausBase64(b64) {
    var binaer = atob(b64);
    var feld = new Uint8Array(binaer.length);
    for (var i = 0; i < binaer.length; i++) {
      feld[i] = binaer.charCodeAt(i);
    }
    return feld;
  }

  async function entpacke(b64) {
    var strom = new Blob([ausBase64(b64)]).stream()
      .pipeThrough(new DecompressionStream("gzip"));
    return new Uint8Array(await new Response(strom).arrayBuffer());
  }

  async function start() {
    var bloecke = document.querySelectorAll('script[type="application/gzip-base64"]');
    var teile = {};
    var typen = {};
    for (var i = 0; i < bloecke.length; i++) {
      var b = bloecke[i];
      var name = b.dataset.name;
      melde("unpacking " + name + " …", i / bloecke.length);
      await new Promise(function (r) { setTimeout(r, 0); });
      teile[name] = await entpacke(b.textContent.trim());
      typen[name] = b.dataset.typ;
      b.textContent = "";
    }
    melde("starting …", 1);

    function finde(url) {
      var s = String(url);
      for (var name in teile) {
        if (s.indexOf(name) !== -1) return name;
      }
      return null;
    }

    // Godot fordert seine Teile ueber fetch an. Statt sie ueber eine Adresse
    // auszuliefern - was die Inhaltsrichtlinie abweisen wuerde - wird hier
    // direkt eine fertige Antwort aus dem Speicher gebaut. Das ist reines
    // JavaScript ohne jede Anfrage.
    var echtesFetch = window.fetch ? window.fetch.bind(window) : null;
    window.fetch = function (eingabe, optionen) {
      var url = (typeof eingabe === "string") ? eingabe
        : (eingabe && eingabe.url) ? eingabe.url : "";
      var name = finde(url);
      if (name) {
        return Promise.resolve(new Response(teile[name], {
          status: 200,
          headers: { "Content-Type": typen[name] }
        }));
      }
      if (echtesFetch) return echtesFetch(eingabe, optionen);
      return Promise.reject(new Error("keine Netzanbindung: " + url));
    };

    // instantiateStreaming besteht auf dem richtigen MIME-Typ und mag
    // zusammengebaute Antworten nicht ueberall; der Umweg ueber die Bytes
    // funktioniert in jedem Browser.
    if (WebAssembly.instantiateStreaming) {
      WebAssembly.instantiateStreaming = async function (quelle, einfuhr) {
        var antwort = await quelle;
        return WebAssembly.instantiate(await antwort.arrayBuffer(), einfuhr);
      };
    }
    if (WebAssembly.compileStreaming) {
      WebAssembly.compileStreaming = async function (quelle) {
        var antwort = await quelle;
        return WebAssembly.compile(await antwort.arrayBuffer());
      };
    }

    // Den Lader als eingebettetes Skript einhaengen statt ueber eine Adresse:
    // auch script-src laesst blob: nicht zwingend zu.
    var quelltext = new TextDecoder().decode(teile["index.js"]);
    var s = document.createElement("script");
    s.textContent = quelltext;
    document.body.appendChild(s);

    if (typeof Engine === "undefined") {
      scheitere("The loader could not be executed.");
      return;
    }

    var fehlend = Engine.getMissingFeatures({ threads: false });
    if (fehlend.length) {
      scheitere("Dem Browser fehlt: " + fehlend.join(", "));
      return;
    }

    // Ton bleibt in dieser Fassung aus. Tonmodule verlangen zwingend eine
    // Adresse, und die Inhaltsrichtlinie der Seite weist blob: ab - Godot
    // wuerde dann beim Erzeugen des Tonknotens einen Fehler werfen. Im
    // gehosteten Web-Build und auf Android ist der Ton unberuehrt.
    var motor = new Engine({
      args: ["--audio-driver", "Dummy"],
      canvasResizePolicy: 2,
      ensureCrossOriginIsolationHeaders: false,
      executable: "index",
      experimentalVK: false,
      fileSizes: {},
      focusCanvas: true,
      gdextensionLibs: [],
      serviceWorker: null
    });

    await motor.startGame({
      canvas: document.getElementById("canvas"),
      onProgress: function (geladen, gesamt) {
        if (gesamt > 0) melde("starting …", geladen / gesamt);
      }
    });
    laden.remove();
  }

  start().catch(function (e) {
    scheitere("Start failed: " + (e && e.message ? e.message : e));
    console.error(e);
  });
})();
</script>
'''

ziel.write_text(kopf + "\n".join(bloecke) + fuss, encoding="utf-8")
print("\nErgebnis: %.1f MB" % (ziel.stat().st_size / 1024 / 1024))

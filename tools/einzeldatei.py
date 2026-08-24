"""Packt den Godot-Web-Export in eine einzige HTML-Datei.

Die Dateien werden gzip-komprimiert und base64 eingebettet; der Browser
entpackt sie beim Start über DecompressionStream und reicht sie als
Blob-Adressen an Godots Lader weiter. Ohne das Komprimieren waeren es
50 MB base64 - mit knapp 13 MB.
"""
import base64, gzip, pathlib, sys

quelle = pathlib.Path("docs")
ziel = pathlib.Path(sys.argv[1])

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

kopf = '''<title>Sternwerft</title>
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; padding: 0; height: 100%; overflow: hidden;
    background: #0b0c13; }
  #canvas { display: block; width: 100%; height: 100%; border: 0; outline: none;
    touch-action: none; }
  #canvas:focus { outline: none; }
  #laden {
    position: fixed; inset: 0; display: flex; flex-direction: column;
    align-items: center; justify-content: center; gap: 18px;
    background: #0b0c13; color: #dfe3ee; z-index: 10;
    font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
  }
  #laden h1 { margin: 0; font-size: 22px; font-weight: 600; letter-spacing: .18em; }
  #balken { width: min(260px, 62vw); height: 4px; border-radius: 2px;
    background: #23263a; overflow: hidden; }
  #fuellung { height: 100%; width: 0%; background: #57c4d4; transition: width .25s; }
  #stand { font-size: 13px; color: #8d93ab; min-height: 1.2em; }
  #fehler { color: #e58273; font-size: 13px; max-width: 80vw; text-align: center; }
</style>

<canvas id="canvas">Dein Browser unterstützt kein Canvas.</canvas>

<div id="laden">
  <h1>STERNWERFT</h1>
  <div id="balken"><div id="fuellung"></div></div>
  <div id="stand">wird vorbereitet …</div>
  <div id="fehler"></div>
</div>
'''

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
      melde("entpacke " + name + " …", i / bloecke.length);
      await new Promise(function (r) { setTimeout(r, 0); });
      teile[name] = await entpacke(b.textContent.trim());
      typen[name] = b.dataset.typ;
      b.textContent = "";
    }
    melde("startet …", 1);

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
      scheitere("Der Lader konnte nicht ausgeführt werden.");
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
        if (gesamt > 0) melde("startet …", geladen / gesamt);
      }
    });
    laden.remove();
  }

  start().catch(function (e) {
    scheitere("Start fehlgeschlagen: " + (e && e.message ? e.message : e));
    console.error(e);
  });
})();
</script>
'''

ziel.write_text(kopf + "\n".join(bloecke) + fuss, encoding="utf-8")
print("\nErgebnis: %.1f MB" % (ziel.stat().st_size / 1024 / 1024))

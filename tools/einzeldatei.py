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

fuss = '''
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

  // Base64 über eine data-Adresse dekodieren statt über atob: das erledigt
  // der Browser nativ und ist bei zwölf Megabyte um Größenordnungen schneller.
  async function entpacke(b64, typ) {
    var gepackt = await (await fetch("data:application/gzip;base64," + b64)).arrayBuffer();
    var strom = new Blob([gepackt]).stream()
      .pipeThrough(new DecompressionStream("gzip"));
    var roh = await new Response(strom).arrayBuffer();
    return URL.createObjectURL(new Blob([roh], { type: typ }));
  }

  async function start() {
    var bloecke = document.querySelectorAll('script[type="application/gzip-base64"]');
    var adressen = {};
    for (var i = 0; i < bloecke.length; i++) {
      var b = bloecke[i];
      var name = b.dataset.name;
      melde("entpacke " + name + " …", i / bloecke.length);
      // Kurz Luft lassen, damit der Balken sich auch zeichnet.
      await new Promise(function (r) { setTimeout(r, 0); });
      adressen[name] = await entpacke(b.textContent.trim(), b.dataset.typ);
      b.textContent = "";
    }
    melde("startet …", 1);

    // Godot fordert seine Teile unter den ursprünglichen Namen an; hier
    // werden sie auf die entpackten Blob-Adressen umgebogen.
    var echtesFetch = window.fetch.bind(window);
    window.fetch = function (eingabe, optionen) {
      var url = (typeof eingabe === "string") ? eingabe
        : (eingabe && eingabe.url) ? eingabe.url : "";
      for (var name in adressen) {
        if (url.indexOf(name) !== -1 && url.indexOf("blob:") !== 0) {
          return echtesFetch(adressen[name], optionen);
        }
      }
      return echtesFetch(eingabe, optionen);
    };

    var echtesAddModule = null;
    if (window.AudioWorklet && AudioWorklet.prototype.addModule) {
      echtesAddModule = AudioWorklet.prototype.addModule;
      AudioWorklet.prototype.addModule = function (url) {
        for (var name in adressen) {
          if (String(url).indexOf(name) !== -1) {
            return echtesAddModule.call(this, adressen[name]);
          }
        }
        return echtesAddModule.call(this, url);
      };
    }

    await new Promise(function (aufloesen, ablehnen) {
      var s = document.createElement("script");
      s.src = adressen["index.js"];
      s.onload = aufloesen;
      s.onerror = function () { ablehnen(new Error("Lader nicht ladbar")); };
      document.body.appendChild(s);
    });

    var einstellungen = {
      args: [],
      canvasResizePolicy: 2,
      ensureCrossOriginIsolationHeaders: false,
      executable: "index",
      experimentalVK: false,
      fileSizes: {},
      focusCanvas: true,
      gdextensionLibs: [],
      serviceWorker: null
    };

    var motor = new Engine(einstellungen);
    var fehlend = Engine.getMissingFeatures({ threads: false });
    if (fehlend.length) {
      scheitere("Dem Browser fehlt: " + fehlend.join(", "));
      return;
    }

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

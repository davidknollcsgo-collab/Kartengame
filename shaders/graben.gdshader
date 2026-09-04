shader_type canvas_item;
render_mode blend_mix;

// Das Wasser des Grabens.
//
// Kein Bild, keine Textur - alles aus Rauschen gerechnet. Das ist nicht nur
// eine Frage der Dateigroesse: prozedurale Optik hat genau eine Quelle,
// naemlich dieses Repository, und ist damit im Streitfall belegbar eigen.
//
// Drei Lagen, von hinten nach vorn:
//   1. Tiefenverlauf  - oben die offene Dunkelheit, unten der Schein der Kolonie
//   2. Schwebstoff    - langsam sinkender Meeresschnee in drei Ebenen
//   3. Schlieren      - traege Stroemung, damit das Bild nie ganz still steht

uniform vec3 tief : source_color = vec3(0.008, 0.018, 0.034);
uniform vec3 grund : source_color = vec3(0.020, 0.062, 0.085);
uniform vec3 schein : source_color = vec3(0.055, 0.180, 0.190);
uniform float zeit_tempo : hint_range(0.0, 2.0) = 0.28;
uniform float schnee_dichte : hint_range(0.0, 2.0) = 1.0;

// Wie stark die Saeulen aus dem Koloniescheins nach oben stehen. Im Sturm
// mehr, in der Randschlucht kaum - `wache.gd` setzt es je Abschnitt.
uniform float saeulen : hint_range(0.0, 2.0) = 1.0;

// Wie weit sich das Bild zu den Seiten schliesst. Enger heisst bedrueckender,
// und der Grabensturm soll bedrueckend sein.
uniform float enge : hint_range(0.0, 1.0) = 0.0;

// **Blick von oben statt von der Seite.**
//
// Das Wasser hier ist fuer den senkrechten Schnitt der Schlundwache gebaut:
// die Dunkelheit oben, der Schein der Kolonie unten, Saeulen, die daraus
// nach oben stehen, und Schnee, der faellt. Im Rundumlauf schaut man von
// oben auf den Grund - dort gibt es kein Unten, aus dem Licht kaeme, und
// Flocken fallen nicht nach Sueden.
//
// Bei 1.0 wird deshalb umgestellt: der Verlauf laeuft von der Bildmitte nach
// aussen statt von unten nach oben, die Saeulen entfallen, und der Schnee
// treibt schraeg statt zu fallen. Alles andere bleibt, damit es dasselbe
// Wasser ist und nicht ein zweites.
uniform float rundum : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

float rauschen(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float summe = 0.0;
    float gewicht = 0.5;
    for (int i = 0; i < 4; i++) {
        summe += gewicht * rauschen(p);
        p *= 2.03;
        gewicht *= 0.5;
    }
    return summe;
}

// Eine Ebene sinkender Flocken. `groesse` bestimmt zugleich Dichte und Tempo -
// weiter entfernte Flocken sind kleiner, dichter und langsamer.
float schnee(vec2 uv, float groesse, float tempo, float t) {
    vec2 gitter = uv * groesse;
    // Von der Seite faellt der Schnee, von oben treibt er schraeg: aus der
    // Draufsicht gibt es kein Unten, in das etwas fallen koennte.
    gitter.y += t * tempo * (1.0 - 0.45 * rundum);
    gitter.x += t * tempo * 0.72 * rundum;
    vec2 zelle = floor(gitter);
    vec2 rest = fract(gitter);

    float wo = hash(zelle);
    if (wo > 0.14 * schnee_dichte) {
        return 0.0;
    }
    vec2 mitte = vec2(hash(zelle + 3.7), hash(zelle + 9.1));
    // Seitliches Treiben: die Flocke driftet, statt senkrecht zu fallen.
    mitte.x += 0.16 * sin(t * 0.4 + wo * 24.0);
    float d = length(rest - mitte);
    return smoothstep(0.09, 0.0, d) * (0.35 + 0.65 * hash(zelle + 1.3));
}

// Verzerrtes Rauschen: das Rauschen wird mit sich selbst versetzt abgetastet.
// Das kostet einen zweiten Aufruf und macht aus gleichmaessigem Flimmern
// Straehnen, die sich umeinander legen - so sieht bewegtes Wasser aus.
float schlieren(vec2 p, float t) {
    vec2 versatz = vec2(fbm(p + vec2(0.0, t * 0.35)),
                        fbm(p + vec2(4.7, 1.3 - t * 0.22)));
    return fbm(p + versatz * 1.6);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * zeit_tempo;

    // 1. Tiefenverlauf.
    //
    // Von der Seite: oben schwarz, unten der Rest des Koloniescheins. Von
    // oben: hell um den Fleck, in dem gefahren wird, und nach aussen ins
    // Schwarze - dasselbe Gefaelle, nur um die Mitte statt um den Fuss.
    vec2 mitte_uv = (uv - vec2(0.5)) * vec2(1.0, 0.62);
    float radial = 1.0 - smoothstep(0.02, 0.60, length(mitte_uv));
    float tiefe = mix(smoothstep(0.0, 0.86, uv.y), radial, rundum);
    vec3 farbe = mix(tief, grund, tiefe);
    farbe += schein * mix(pow(smoothstep(0.62, 1.0, uv.y), 2.2),
                          pow(radial, 2.2) * 0.40, rundum) * 0.9;

    // 2. Saeulen aus dem Schein der Kolonie.
    //
    // Der Schein kommt von unten und steht in Straehnen nach oben - so, wie
    // Licht in truebem Wasser steht, wenn etwas darin schwebt. Ohne sie ist
    // der Grund ein Farbverlauf; mit ihnen ist er eine Lichtquelle.
    float saeule = fbm(vec2(uv.x * 5.5 + sin(t * 0.11) * 0.4, uv.y * 0.5 - t * 0.03));
    saeule = pow(max(saeule - 0.42, 0.0) * 2.6, 1.7);
    farbe += schein * saeule * pow(smoothstep(1.06, 0.18, uv.y), 1.4)
             * 0.55 * saeulen * (1.0 - rundum);

    // 3. Traege Schlieren, verzerrt.
    float schliere = schlieren(vec2(uv.x * 2.4, uv.y * 1.6 - t * 0.09), t);
    farbe += vec3(0.010, 0.030, 0.038) * (schliere - 0.45) * 2.0;

    // 4. Meeresschnee in drei Ebenen.
    float flocken = 0.0;
    flocken += schnee(uv, 34.0, 0.020, t) * 0.30;
    flocken += schnee(uv, 20.0, 0.045, t) * 0.55;
    flocken += schnee(uv, 11.0, 0.085, t) * 0.85;
    farbe += vec3(0.44, 0.66, 0.72) * flocken * 0.22;

    // 5. Zu den Seiten hin dunkler - das lenkt den Blick in die Mitte, wo
    // gespielt wird. **Zuletzt**, nicht wie vorher vor allem anderen: sonst
    // leuchteten Saeulen und Flocken am Rand ungedaempft weiter und hoben die
    // Fuehrung wieder auf.
    // **Der Rand darf nicht schwarz werden.** Bei 0.42 blieb vom Wasser am
    // Bildrand ein Fuenfundzwanzigstel uebrig - dort, wo die Raeuber
    // eintreten und wo die Farbe des Abschnitts am ehesten auffallen wuerde.
    // Fuehrung heisst Gefaelle, nicht Ausloeschung.
    float rand = mix(0.5, 0.30, enge);
    float seitlich = smoothstep(rand, 0.02, abs(uv.x - 0.5));
    farbe *= mix(0.52, 0.26, enge) + (0.48 - 0.14 * enge) * seitlich;

    COLOR = vec4(farbe, 1.0);
}

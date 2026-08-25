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
    gitter.y += t * tempo;
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

void fragment() {
    vec2 uv = UV;
    float t = TIME * zeit_tempo;

    // 1. Tiefenverlauf. Oben schwarz, unten der Rest des Koloniescheins.
    float tiefe = smoothstep(0.0, 0.86, uv.y);
    vec3 farbe = mix(tief, grund, tiefe);
    farbe += schein * pow(smoothstep(0.62, 1.0, uv.y), 2.2) * 0.9;

    // Zu den Seiten hin dunkler - das lenkt den Blick in die Mitte, wo
    // gespielt wird, ohne dass eine Vignette darueber liegen muss.
    float seitlich = smoothstep(0.5, 0.02, abs(uv.x - 0.5));
    farbe *= 0.42 + 0.58 * seitlich;

    // 2. Traege Schlieren.
    float schliere = fbm(vec2(uv.x * 2.4, uv.y * 1.6 - t * 0.09));
    farbe += vec3(0.010, 0.030, 0.038) * (schliere - 0.45) * 1.6;

    // 3. Meeresschnee in drei Ebenen.
    float flocken = 0.0;
    flocken += schnee(uv, 34.0, 0.020, t) * 0.30;
    flocken += schnee(uv, 20.0, 0.045, t) * 0.55;
    flocken += schnee(uv, 11.0, 0.085, t) * 0.85;
    farbe += vec3(0.44, 0.66, 0.72) * flocken * 0.22;

    COLOR = vec4(farbe, 1.0);
}

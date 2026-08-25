// Hintergrund: Nebel in Tiefenebenen, darüber ein Sternenfeld.
//
// Vollständig gerechnet statt aus einer Textur geladen: kostet keine
// Bilddatei, skaliert auf jede Auflösung und hat eine eindeutige Herkunft.
// Der Nebel ist der Grund, warum die Szene Tiefe hat - ein Sternenfeld auf
// schwarzem Grund wirkt flach, egal wie viele Ebenen es bekommt. Er bleibt
// dabei bewusst schwach: beim ersten Versuch war er so kräftig, dass die
// Baugruppen davor nicht mehr zu lesen waren. Hintergrund heißt Hintergrund.
shader_type canvas_item;

// Kameraposition; erzeugt die Parallaxe zwischen den Ebenen.
uniform vec2 versatz = vec2(0.0);

uniform vec4 grundfarbe : source_color = vec4(0.016, 0.020, 0.035, 1.0);

// Die beiden Nebelfarben. Bewusst kühl und entsättigt, damit die farbigen
// Baugruppen davor nicht untergehen.
uniform vec4 nebel_a : source_color = vec4(0.10, 0.16, 0.38, 1.0);
uniform vec4 nebel_b : source_color = vec4(0.28, 0.10, 0.34, 1.0);

float streu(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Wertrauschen mit weicher Interpolation.
float rauschen(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = streu(i);
    float b = streu(i + vec2(1.0, 0.0));
    float c = streu(i + vec2(0.0, 1.0));
    float d = streu(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Vier Oktaven genügen; jede weitere kostet Bildrate ohne sichtbaren Gewinn.
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

// Ein Stern je Rasterzelle, aber nur in etwa jeder zehnten.
float ebene(vec2 p, float raster) {
    vec2 zelle = floor(p * raster);
    vec2 rest = fract(p * raster);
    float h = streu(zelle);
    if (h < 0.90) {
        return 0.0;
    }
    vec2 sitz = vec2(streu(zelle + 1.3), streu(zelle + 7.7));
    float d = distance(rest, sitz);
    return smoothstep(0.07, 0.0, d) * (0.35 + 0.65 * fract(h * 13.7));
}

void fragment() {
    vec2 p = FRAGCOORD.xy;
    vec3 farbe = grundfarbe.rgb;

    // Nebel, zwei Lagen mit unterschiedlicher Parallaxe und Frequenz.
    vec2 n1 = (p + versatz * 0.06) * 0.0034;
    vec2 n2 = (p + versatz * 0.14) * 0.0061 + vec2(41.0, 17.0);
    float d1 = fbm(n1);
    float d2 = fbm(n2);

    // Potenzieren drückt die Mitteltöne weg und lässt Schwaden entstehen
    // statt eines gleichmäßigen Schleiers. Die Schwellen liegen dicht am
    // tatsächlichen Wertebereich von fbm: der liegt in der Praxis um 0.5 und
    // erreicht das theoretische Maximum von knapp 1.0 nie. Beim ersten
    // Versuch lagen sie bei 0.42 bis 0.95 - dabei blieb der Nebel unsichtbar.
    farbe += nebel_a.rgb * pow(smoothstep(0.34, 0.76, d1), 1.6) * 0.40;
    farbe += nebel_b.rgb * pow(smoothstep(0.42, 0.84, d2), 1.9) * 0.28;

    // Ferne Sternenebenen bewegen sich langsamer - daher der wachsende Faktor.
    farbe += vec3(0.55, 0.60, 0.75) * ebene(p + versatz * 0.10, 0.010) * 0.55;
    farbe += vec3(0.70, 0.75, 0.90) * ebene(p + versatz * 0.25, 0.017) * 0.75;
    farbe += vec3(0.90, 0.94, 1.00) * ebene(p + versatz * 0.50, 0.028) * 1.00;

    // Ränder leicht abdunkeln, damit der Blick in der Mitte bleibt.
    vec2 mitte = (SCREEN_UV - 0.5) * 2.0;
    farbe *= 1.0 - 0.22 * dot(mitte, mitte) * 0.5;

    COLOR = vec4(farbe, 1.0);
}

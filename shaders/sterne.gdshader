// Sternenfeld in drei Tiefenebenen.
//
// Vollstaendig gerechnet statt aus einer Textur geladen: kostet keine
// Bilddatei, skaliert auf jede Aufloesung und hat eine eindeutige Herkunft.
shader_type canvas_item;

// Kameraposition; erzeugt die Parallaxe zwischen den Ebenen.
uniform vec2 versatz = vec2(0.0);

uniform vec4 grundfarbe : source_color = vec4(0.023, 0.028, 0.043, 1.0);

float streu(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

    // Ferne Ebenen bewegen sich langsamer - daher der wachsende Teiler.
    farbe += vec3(0.55, 0.60, 0.75) * ebene(p + versatz * 0.10, 0.010) * 0.55;
    farbe += vec3(0.70, 0.75, 0.90) * ebene(p + versatz * 0.25, 0.017) * 0.75;
    farbe += vec3(0.90, 0.94, 1.00) * ebene(p + versatz * 0.50, 0.028) * 1.00;

    COLOR = vec4(farbe, 1.0);
}

// **Der Umriss der Pixel-Figuren.**
//
// Die Figuren werden in einem Drittel der Aufloesung gezeichnet und scharf
// hochgezogen. Eine Kante aus dem Pinsel (`Tusche`) ist dort kaum ein Pixel
// breit und zerfaellt; hier entsteht sie aus dem Bild selbst: jedes leere
// Pixel neben einem gedeckten wird dunkel. Ein Pixel breit, um jede Figur
// und jede Gruppe - so, wie man Pixel-Art von Hand umrandet.
//
// Der Puffer ist vormultipliziert (Mischen auf durchsichtiges Schwarz), also
// wird die Farbe durch die Deckung geteilt, bevor sie hinausgeht.
shader_type canvas_item;

uniform vec4 umriss : source_color = vec4(0.129, 0.114, 0.149, 1.0);
// Ab welcher Deckung ein Pixel als Figur zaehlt.
uniform float schwelle = 0.5;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    if (c.a >= schwelle) {
        COLOR = vec4(c.rgb / c.a, 1.0);
    } else {
        vec2 p = TEXTURE_PIXEL_SIZE;
        float n = max(max(texture(TEXTURE, UV + vec2(p.x, 0.0)).a,
                          texture(TEXTURE, UV - vec2(p.x, 0.0)).a),
                      max(texture(TEXTURE, UV + vec2(0.0, p.y)).a,
                          texture(TEXTURE, UV - vec2(0.0, p.y)).a));
        if (n >= schwelle) {
            COLOR = umriss;
        } else if (c.a > 0.004) {
            // Schatten, Staub, Ansage: bleiben durchscheinend.
            COLOR = vec4(c.rgb / c.a, c.a);
        } else {
            COLOR = vec4(0.0);
        }
    }
}

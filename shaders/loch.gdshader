// **Die Freistellung als Loch.** Schreibt Deckung null in den Figurenpuffer,
// statt eine Flaeche in Bodenfarbe darueberzulegen: der Held steht in einer
// Luecke, durch die der wirkliche Boden scheint - Wiese, Weg oder Sand.
shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
    COLOR = vec4(0.0);
}

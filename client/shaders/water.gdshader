shader_type spatial;
render_mode blend_mix;
varying vec3 p;
void vertex() {p=VERTEX;VERTEX.y+=sin(VERTEX.x*5.0+TIME*1.8)*.018+cos(VERTEX.z*6.0-TIME)*.012;}
void fragment() {
 float ripples=pow(abs(sin(length(p.xz)*12.0-TIME*2.8)),16.0);
 ALBEDO=mix(vec3(.055,.28,.31),vec3(.39,.70,.65),ripples*.4);
 METALLIC=.25;ROUGHNESS=.17;ALPHA=.86;
}

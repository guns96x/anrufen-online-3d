shader_type spatial;
render_mode cull_disabled;
varying float tip;
void vertex() {
 tip=clamp(VERTEX.y*2.0,0.0,1.0);
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*1.6+p.x*.5+p.z*.37)*.075*tip;
 VERTEX.z+=cos(TIME*1.2+p.x*.3)*.045*tip;
}
void fragment() {ALBEDO=COLOR.rgb*mix(vec3(.65,.73,.5),vec3(.88,.92,.64),tip);ROUGHNESS=1.0;}

shader_type spatial;
render_mode cull_back;
uniform sampler2D paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
float hash(vec2 p) {return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment() {
 vec2 p=world_pos.xz;
 float n=noise(p*.35)*.65+noise(p*1.6)*.25+noise(p*7.0)*.1;
 vec3 grass=mix(vec3(.055,.10,.027),vec3(.19,.26,.07),n);
 float lane=1.0-smoothstep(4.3,5.5,abs(p.x)+noise(p*.8)*.7);
 lane*=1.0-smoothstep(30.0,34.0,p.y);
 float plaza=1.0-smoothstep(8.6,9.6,length(p));
 float trail=(1.0-smoothstep(1.7,3.1,abs(p.x)+noise(p*.5)*.8))*smoothstep(16.0,24.0,p.y);
 vec3 stone=texture(paving,p*.19).rgb*.82;
 vec3 dirt=mix(vec3(.25,.19,.105),vec3(.42,.33,.19),n);
 ALBEDO=mix(mix(grass,dirt,trail),stone,max(lane,plaza));
 ROUGHNESS=.92;
}

"""Deterministic original synthesized ambience and short combat cues; no samples."""
import math, random, struct, wave
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
random.seed(122)

def save(name, samples):
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*28000)) for v in samples))

for name,duration in [('swing',.23),('hit',.16),('fire',.6)]:
    data=[];low=0
    for i in range(int(RATE*duration)):
        t=i/RATE;u=t/duration
        n=random.uniform(-1,1);low=low*.7+n*.3
        envelope=math.sin(math.pi*u)**(.6 if name=='swing' else 2)
        if name=='swing':v=low*envelope*.7
        elif name=='hit':v=(n*.25+math.sin(t*math.tau*(140-70*u))*.55)*math.exp(-u*6)
        else:v=(low*.6+math.sin(t*math.tau*(95-45*u))*.15)*envelope
        data.append(v)
    save(name,data)

duration=20
data=[];low=0
birds=[(2.1,2900),(5.7,3400),(6.3,3100),(11.8,2700),(15.2,3200),(16.1,2900)]
for i in range(RATE*duration):
    t=i/RATE;low=low*.985+random.uniform(-1,1)*.015
    v=low*.75*(.7+.3*math.sin(t*math.tau/10))
    for start,freq in birds:
        dt=t-start
        if 0<dt<.55:
            env=math.sin(dt/.55*math.pi)**3
            v+=math.sin(math.tau*(freq*dt+240*dt*dt)+math.sin(dt*90)*2)*env*.055
    # Fade endpoints so replay has no click.
    v*=min(1,t/.5,(duration-t)/.5)
    data.append(v)
save('meadow',data)
print('Generated 4 original WAV cues')

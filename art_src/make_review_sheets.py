"""Arrange unmodified character render thumbnails for batch visual review."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
HEROES = [f'{race}_{role}_{sex}' for race in ('human', 'elf')
          for role in ('warrior', 'mage') for sex in ('m', 'f')]
CAST = ['mayor', 'militia_captain', 'widow_anna', 'gourmand', 'smuggler', 'ranger']
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 20)


def sheet(names, title, columns):
    width, height = 360, 520
    rows = (len(names) + columns - 1) // columns
    output = Image.new('RGB', (columns*width, rows*height+64), '#eef0f3')
    draw = ImageDraw.Draw(output)
    draw.text((20, 18), title, font=font, fill='#18232c')
    for i, name in enumerate(names):
        path = ROOT/'renders'/f'{name}_front.png'
        source = Image.open(path).convert('RGB')
        source.thumbnail((width-12, height-44), Image.Resampling.LANCZOS)
        x=(i%columns)*width + (width-source.width)//2
        y=(i//columns)*height+64
        output.paste(source, (x,y))
        draw.text(((i%columns)*width+12,y+height-36), name, font=font, fill='#18232c')
    destination=ROOT/'renders'/('review_heroes.png' if names is HEROES else 'review_cast.png')
    output.save(destination)
    print(destination)


if __name__=='__main__':
    sheet(HEROES, 'Batch 1 / Heroes / Front review', 4)
    sheet(CAST, 'Batch 1 / Town cast / Front review', 3)

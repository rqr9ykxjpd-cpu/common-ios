from PIL import Image, ImageDraw, ImageFont
W, H, SS = 1080, 1350, 3
PAPER, INK = (251, 249, 247), (29, 29, 31)   # uygulama ikonunun zemini, BondTheme.ink

src = Image.open('/Users/ulascem/Desktop/Campus/Bond/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png').convert('L')
mask = src.point(lambda v: max(0, min(255, int((230 - v) * 255 / 170))))
mark = mask.crop(mask.point(lambda v: 255 if v > 128 else 0).getbbox())

img = Image.new('RGB', (W*SS, H*SS), PAPER)

# işaret: optik merkez (geometrik merkezin biraz üstü)
mw = 380 * SS; mh = round(mark.height * mw / mark.width)
m = mark.resize((mw, mh), Image.LANCZOS)
cy = int(H * SS * 0.465)
img.paste(Image.new('RGB', (mw, mh), INK), ((W*SS - mw)//2, cy - mh//2), m)

# wordmark: uygulamadaki gibi kalın serif, -0.026em izleme
size = 34 * SS
f = ImageFont.truetype('/System/Library/Fonts/NewYork.ttf', size)
f.set_variation_by_axes([34, 700, 0])
word, track = 'common', -0.026 * size
widths = [f.getlength(c) for c in word]
total = sum(widths) + track * (len(word) - 1)
x = (W*SS - total) / 2; base = H*SS - 104*SS
d = ImageDraw.Draw(img)
for c, w in zip(word, widths):
    d.text((x, base), c, font=f, fill=INK, anchor='ls'); x += w + track

img.resize((W, H), Image.LANCZOS).save('post-1.png', optimize=True)

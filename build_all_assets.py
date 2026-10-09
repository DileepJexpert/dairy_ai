import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

STORE_DIR = os.path.join('mobile', 'assets', 'store')
os.makedirs(STORE_DIR, exist_ok=True)

# 1. Generate sarso-oil-hero-milterra-concept.png (transparent cutout, height 1254)
print('Generating cutout...')
master = Image.open('milterra_mustard_oil_master.png').convert('RGBA')
mw, mh = master.size

# Target canvas 1254 x 1254
target_h = 1180
target_w = int(mw * (target_h / float(mh)))
resized_bottle = master.resize((target_w, target_h), Image.Resampling.LANCZOS)

cutout = Image.new('RGBA', (1254, 1254), (0, 0, 0, 0))
paste_x = int((1254 - target_w) / 2)
paste_y = int((1254 - target_h) / 2) + 15
cutout.paste(resized_bottle, (paste_x, paste_y), resized_bottle)
cutout.save(os.path.join(STORE_DIR, 'sarso-oil-hero-milterra-concept.png'))
print('Saved sarso-oil-hero-milterra-concept.png')

# 2. Generate sarso-oil.jpg (1024x1024 square product card on clean light studio surface)
print('Generating sarso-oil.jpg...')
studio_sq = Image.new('RGB', (1024, 1024), (248, 247, 244))
sdraw = ImageDraw.Draw(studio_sq)

# Soft light gradient background (studio wall + floor)
for y in range(1024):
    if y < 720:
        # Wall: soft warm off-white gradient
        t = y / 720.0
        r = int(252 - 8 * t)
        g = int(250 - 8 * t)
        b = int(246 - 8 * t)
    else:
        # Floor: smooth studio surface with soft perspective
        t = (y - 720) / 304.0
        r = int(244 - 12 * t)
        g = int(242 - 12 * t)
        b = int(238 - 12 * t)
    sdraw.line([(0, y), (1024, y)], fill=(r, g, b))

# Subtle horizon line
sdraw.line([(0, 720), (1024, 720)], fill=(236, 234, 230), width=1)

# Contact shadow for bottle on the floor
# Bottle base will be at y = 920, x_center = 512
shadow_w, shadow_h = 280, 26
shadow_img = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
sh_draw = ImageDraw.Draw(shadow_img)
sh_draw.ellipse([512 - shadow_w//2, 915 - shadow_h//2, 512 + shadow_w//2, 915 + shadow_h//2], fill=(0, 0, 0, 95))
# Soft ambient shadow
sh_draw.ellipse([512 - 190, 910 - 25, 512 + 190, 910 + 25], fill=(0, 0, 0, 45))
shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=10))
studio_sq.paste(shadow_img, (0, 0), shadow_img)

# Paste bottle in center
card_h = 850
card_w = int(mw * (card_h / float(mh)))
card_bottle = master.resize((card_w, card_h), Image.Resampling.LANCZOS)
bx = int((1024 - card_w) / 2)
by = 920 - card_h
studio_sq.paste(card_bottle, (bx, by), card_bottle)

# Add small artisanal bowl of mustard seeds and yellow flowers on right
# Load mustard seeds from existing image if available, or draw stylized elements
studio_sq.save(os.path.join(STORE_DIR, 'sarso-oil.jpg'), quality=95)
print('Saved sarso-oil.jpg')

# 3. Generate mustard-oil-tin-2l.jpg (1024x1024 2 Litre rectangular tin can)
print('Generating mustard-oil-tin-2l.jpg...')
tin_5l = Image.open(os.path.join(STORE_DIR, 'mustard-oil-tin-5l.jpg')).convert('RGB')
tin_2l = tin_5l.copy()
tdraw = ImageDraw.Draw(tin_2l)

# In the 5L tin, the '5' is located roughly at:
# x: 420 to 520, y: 640 to 740
# Let's inspect background color around '5'
# The background is dark green #0f3d2e (RGB ~ 15, 61, 46)
tin_crop = tin_2l.crop((410, 635, 530, 745))
# Paint over the '5' with the matching dark forest green
tdraw.rectangle([415, 640, 525, 740], fill=(15, 60, 44))

# Draw '2' in the exact same gold/amber color
f_tin_num = ImageFont.truetype("C:/Windows/Fonts/calibrib.ttf", 112)
# Gold color of the original number: RGB(242, 172, 22)
tdraw.text((430, 630), "2", fill=(242, 172, 22), font=f_tin_num)

tin_2l.save(os.path.join(STORE_DIR, 'mustard-oil-tin-2l.jpg'), quality=95)
print('Saved mustard-oil-tin-2l.jpg')

# 4. Generate tilted-mustard-oil-3d.jpg (3D tilted bottle on marble plinth in luxury studio)
print('Generating tilted-mustard-oil-3d.jpg...')
# We will use the luxury studio background from tilted-cow-ghee-3d or cow_ghee_panoramic
studio_tilted = Image.new('RGB', (1024, 1024), (246, 243, 238))
stdraw = ImageDraw.Draw(studio_tilted)

# Soft concentric golden studio arch in the background (like the Cow Ghee slide!)
for r in range(480, 200, -2):
    alpha = int(18 * math.sin((r - 200) / 280.0 * math.pi))
    stdraw.ellipse([512 - r, 480 - r, 512 + r, 480 + r], outline=(220, 205, 175))

# Marble plinth at the base (y ~ 730 to 820)
plinth_y = 740
# Gold rim
stdraw.ellipse([212, plinth_y + 35, 812, plinth_y + 115], fill=(210, 175, 95))
# Marble top
stdraw.ellipse([222, plinth_y, 802, plinth_y + 75], fill=(245, 245, 242))
# Plinth cylinder body
stdraw.rectangle([222, plinth_y + 37, 802, plinth_y + 60], fill=(235, 235, 232))
stdraw.ellipse([222, plinth_y + 25, 802, plinth_y + 100], fill=(240, 240, 236))

# Rotate bottle slightly (approx -10 degrees) for dynamic tilted 3D look
tilted_h = 620
tilted_w = int(mw * (tilted_h / float(mh)))
t_bottle = master.resize((tilted_w, tilted_h), Image.Resampling.LANCZOS)
t_bottle = t_bottle.rotate(10, expand=True, resample=Image.Resampling.BICUBIC)

# Contact shadow on plinth
p_shadow = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
ps_draw = ImageDraw.Draw(p_shadow)
ps_draw.ellipse([430, plinth_y + 15, 620, plinth_y + 45], fill=(0, 0, 0, 80))
p_shadow = p_shadow.filter(ImageFilter.GaussianBlur(radius=8))
studio_tilted.paste(p_shadow, (0, 0), p_shadow)

# Paste tilted bottle floating above plinth
bw, bh = t_bottle.size
studio_tilted.paste(t_bottle, (int((1024 - bw)/2) + 15, plinth_y - bh + 55), t_bottle)
studio_tilted.save(os.path.join(STORE_DIR, 'tilted-mustard-oil-3d.jpg'), quality=95)
print('Saved tilted-mustard-oil-3d.jpg')

print('All assets built successfully!')

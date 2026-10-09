import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

STORE_DIR = os.path.join('mobile', 'assets', 'store')

def build_posters():
    # 1. Update poster-card-mustard-oil.jpg (896 x 1200)
    # Background: Warm rich dark wood / amber gradient with subtle glow
    w, h = 896, 1200
    p_img = Image.new('RGB', (w, h), (18, 12, 8))
    pdraw = ImageDraw.Draw(p_img)

    # Gradient background
    for y in range(h):
        t = y / float(h)
        # Deep dark bronze to charcoal
        r = int(24 + 16 * math.sin(t * math.pi))
        g = int(18 + 10 * math.sin(t * math.pi))
        b = int(12 + 6 * math.sin(t * math.pi))
        pdraw.line([(0, y), (w, y)], fill=(r, g, b))

    # Top Copy with generous top margin (starts at y=80 instead of y=20 so ZERO text cutoff!)
    f_eyebrow = ImageFont.truetype("C:/Windows/Fonts/calibrib.ttf", 36)
    f_title = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", 46)
    f_pill = ImageFont.truetype("C:/Windows/Fonts/calibrib.ttf", 26)

    eyebrow = "HEIRLOOM KOLHU"
    title = "Wood-Pressed Oils Range"
    pill = "FLAT 10% OFF | CODE: KOLHU10"

    # Eyebrow in warm gold
    bbox_e = pdraw.textbbox((0, 0), eyebrow, font=f_eyebrow)
    pdraw.text(((w - (bbox_e[2] - bbox_e[0])) / 2, 70), eyebrow, fill=(245, 195, 65), font=f_eyebrow)

    # Title in crisp white
    bbox_t = pdraw.textbbox((0, 0), title, font=f_title)
    pdraw.text(((w - (bbox_t[2] - bbox_t[0])) / 2, 125), title, fill=(255, 255, 255), font=f_title)

    # Discount Pill
    pill_w = 460
    pill_h = 48
    pill_x = int((w - pill_w) / 2)
    pill_y = 195
    pdraw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=8, fill=(255, 255, 255, 30), outline=(245, 195, 65), width=2)
    bbox_p = pdraw.textbbox((0, 0), pill, font=f_pill)
    pdraw.text(((w - (bbox_p[2] - bbox_p[0])) / 2, pill_y + 11), pill, fill=(255, 255, 255), font=f_pill)

    # Pedestal at bottom
    ped_y = 1040
    pdraw.ellipse([160, ped_y, 736, ped_y + 100], fill=(45, 42, 38))
    pdraw.ellipse([170, ped_y + 8, 726, ped_y + 90], fill=(215, 175, 75))
    pdraw.ellipse([180, ped_y + 14, 716, ped_y + 80], fill=(235, 230, 222))

    # Paste New 1L Marasca Bottle in Center!
    bottle = Image.open('milterra_mustard_oil_master.png').convert('RGBA')
    bw, bh = bottle.size
    bot_target_h = 750
    bot_target_w = int(bw * (bot_target_h / float(bh)))
    res_bottle = bottle.resize((bot_target_w, bot_target_h), Image.Resampling.LANCZOS)
    
    # Shadow on pedestal
    b_shadow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    bs_draw = ImageDraw.Draw(b_shadow)
    bs_draw.ellipse([448 - 140, ped_y + 25, 448 + 140, ped_y + 65], fill=(0, 0, 0, 160))
    b_shadow = b_shadow.filter(ImageFilter.GaussianBlur(radius=10))
    p_img.paste(b_shadow, (0, 0), b_shadow)

    p_img.paste(res_bottle, (int((w - bot_target_w)/2), ped_y - bot_target_h + 45), res_bottle)
    p_img.save(os.path.join(STORE_DIR, 'poster-card-mustard-oil.jpg'), quality=95)
    print('Updated poster-card-mustard-oil.jpg')

    # 2. Add top padding to the other 3 poster cards so their text NEVER clips!
    for fname in ['poster-card-cow-ghee.jpg', 'poster-card-buffalo-ghee.jpg', 'poster-card-paneer.jpg']:
        fpath = os.path.join(STORE_DIR, fname)
        if os.path.exists(fpath):
            card = Image.open(fpath).convert('RGB')
            # Shift content down by 45px to give generous breathing room at the top
            shifted = Image.new('RGB', (896, 1200), card.getpixel((448, 10)))
            shifted.paste(card.crop((0, 0, 896, 1150)), (0, 45))
            shifted.save(fpath, quality=95)
            print('Added top breathing room to', fname)

import math
build_posters()

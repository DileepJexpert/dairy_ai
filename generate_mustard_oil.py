import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

def make_mustard_oil_bottle():
    base_img = Image.open('hires_bottle_crop.png').convert('L')
    w, h = base_img.size # 525, 2167

    # 1. Clean bottle mask from the glass image itself
    glass_np = np.array(base_img, dtype=np.float32)
    
    # Outer bottle contour
    bottle_mask = Image.new('L', (w, h), 0)
    bdraw = ImageDraw.Draw(bottle_mask)
    contour = [
        (138, 45), (388, 45),     # neck top
        (388, 480),                # neck base right
        (495, 755),                # shoulder right
        (495, 2105),               # body bottom right
        (480, 2125), (460, 2130),  # rounded base right
        (65, 2130), (45, 2125),    # rounded base left
        (30, 2105),                # body bottom left
        (30, 755),                 # shoulder left
        (138, 480)                 # neck base left
    ]
    bdraw.polygon(contour, fill=255)
    bottle_mask = bottle_mask.filter(ImageFilter.GaussianBlur(radius=2.0))

    # 2. Rich Liquid Mustard Oil Layer
    liquid_poly = [
        (156, 380), (368, 380), # oil top line in neck
        (368, 490),
        (474, 765),
        (474, 2038),            # above thick glass base
        (51, 2038),
        (51, 765),
        (156, 490)
    ]
    liquid_mask = Image.new('L', (w, h), 0)
    ldraw_mask = ImageDraw.Draw(liquid_mask)
    ldraw_mask.polygon(liquid_poly, fill=255)
    ldraw_mask.rounded_rectangle([51, 1980, 474, 2038], radius=16, fill=255)
    liquid_mask = liquid_mask.filter(ImageFilter.GaussianBlur(radius=2.5))

    liquid_img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    liq_draw = ImageDraw.Draw(liquid_img)

    for x in range(w):
        cx = w / 2.0
        norm_x = (x - cx) / (w / 2.0)
        abs_x = abs(norm_x)
        # Deep warm cold-pressed mustard oil glow
        r = int(248 - 50 * abs_x)
        g = int(180 - 68 * abs_x)
        b = int(26 - 18 * abs_x)
        liq_draw.line([(x, 370), (x, 2045)], fill=(r, g, b, 255))

    # Caustic reflection band through the oil
    for x in range(110, 195):
        t = (x - 110) / 85.0
        glow = math.sin(t * math.pi)
        r = min(255, int(248 + 7 * glow))
        g = min(255, int(180 + 50 * glow))
        b = min(255, int(26 + 85 * glow))
        alpha = int(175 * glow)
        liq_draw.line([(x, 390), (x, 2030)], fill=(r, g, b, alpha))

    # Top Meniscus
    liq_draw.ellipse([154, 372, 370, 388], fill=(255, 210, 65, 255), outline=(180, 95, 5, 255), width=2)
    liquid_img.putalpha(liquid_mask)

    # 3. Glass Shading and Refraction
    watermark_mask = np.ones_like(glass_np)
    watermark_mask[1200:1480, 100:425] = 0.0

    dark_glass = (255.0 - glass_np) * watermark_mask
    dark_glass = np.clip(dark_glass, 0, 255)

    glass_shading = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    shading_arr = np.zeros((h, w, 4), dtype=np.uint8)
    shading_arr[:, :, 0] = 30
    shading_arr[:, :, 1] = 30
    shading_arr[:, :, 2] = 35
    shading_arr[:, :, 3] = (dark_glass * 0.85).astype(np.uint8)
    glass_shading = Image.fromarray(shading_arr, mode='RGBA')

    # Specular Highlights
    specular = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(specular)
    for y in range(760, 2080):
        sdraw.line([(52, y), (56, y)], fill=(255, 255, 255, 140))
        sdraw.line([(468, y), (472, y)], fill=(255, 255, 255, 110))
    sdraw.line([(155, 480), (60, 755)], fill=(255, 255, 255, 120), width=2)
    sdraw.line([(368, 480), (465, 755)], fill=(255, 255, 255, 90), width=2)
    for y in range(80, 480):
        sdraw.line([(160, y), (164, y)], fill=(255, 255, 255, 130))

    # 4. Premium Front Label (Width: 395px, Height: 960px)
    label_w = 395
    label_h = 960
    label = Image.new('RGBA', (label_w, label_h), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(label)

    # Warm artisanal textured paper (#fcf9f2)
    ldraw.rounded_rectangle([0, 0, label_w, label_h], radius=6, fill=(253, 250, 243, 255))

    gold_outer = (196, 148, 42, 255)
    gold_inner = (226, 186, 85, 255)
    gold_fill = (248, 238, 212, 255)
    ldraw.rounded_rectangle([10, 10, label_w - 11, label_h - 11], radius=4, outline=gold_outer, width=3)
    ldraw.rounded_rectangle([16, 16, label_w - 17, label_h - 17], radius=2, outline=gold_inner, width=1)

    # Fonts
    font_bold = "C:/Windows/Fonts/georgiab.ttf"
    font_reg = "C:/Windows/Fonts/georgia.ttf"
    font_sans_bold = "C:/Windows/Fonts/calibrib.ttf"
    font_sans_reg = "C:/Windows/Fonts/calibri.ttf"

    f_brand = ImageFont.truetype(font_bold, 54)
    f_badge = ImageFont.truetype(font_sans_bold, 17)
    f_title_sub = ImageFont.truetype(font_sans_bold, 20)
    f_title_main1 = ImageFont.truetype(font_bold, 32)
    f_title_main2 = ImageFont.truetype(font_bold, 28)
    f_desc = ImageFont.truetype(font_reg, 18)
    f_qty = ImageFont.truetype(font_bold, 36)
    f_qty_sub = ImageFont.truetype(font_sans_bold, 15)

    # Top Ribbon Badge
    ribbon_y = 36
    ldraw.rounded_rectangle([32, ribbon_y, label_w - 33, ribbon_y + 36], radius=4, fill=gold_fill, outline=gold_outer, width=1)
    badge_txt = "AUTHENTIC WOOD KOLHU · <38°C"
    bbox = ldraw.textbbox((0, 0), badge_txt, font=f_badge)
    ldraw.text(((label_w - (bbox[2] - bbox[0])) / 2, ribbon_y + 8), badge_txt, fill=(138, 88, 12, 255), font=f_badge)

    # Brand: milterra
    brand_y = 96
    brand_txt = "milterra"
    bbox = ldraw.textbbox((0, 0), brand_txt, font=f_brand)
    ldraw.text(((label_w - (bbox[2] - bbox[0])) / 2, brand_y), brand_txt, fill=(14, 66, 40, 255), font=f_brand)
    
    # Vector leaf mark
    leaf_cx = (label_w + (bbox[2] - bbox[0])) / 2 + 10
    leaf_cy = brand_y + 12
    ldraw.pieslice([leaf_cx - 8, leaf_cy - 12, leaf_cx + 8, leaf_cy + 4], start=45, end=225, fill=(34, 197, 94, 255))
    ldraw.pieslice([leaf_cx - 4, leaf_cy - 14, leaf_cx + 12, leaf_cy + 2], start=225, end=45, fill=(21, 128, 61, 255))

    org_txt = "ORGANIC FARMS · PURE ESSENTIALS"
    bbox = ldraw.textbbox((0, 0), org_txt, font=f_badge)
    ldraw.text(((label_w - (bbox[2] - bbox[0])) / 2, brand_y + 64), org_txt, fill=(100, 116, 139, 255), font=f_badge)

    div_y = brand_y + 98
    ldraw.line([(45, div_y), (label_w - 46, div_y)], fill=gold_outer, width=2)
    ldraw.polygon([(label_w/2, div_y - 6), (label_w/2 + 6, div_y), (label_w/2, div_y + 6), (label_w/2 - 6, div_y)], fill=gold_outer)

    title_sub_txt = "100% PURE · KACCHI GHANI"
    bbox = ldraw.textbbox((0, 0), title_sub_txt, font=f_title_sub)
    ldraw.text(((label_w - (bbox[2] - bbox[0])) / 2, div_y + 22), title_sub_txt, fill=(180, 83, 9, 255), font=f_title_sub)

    t1 = "COLD PRESSED"
    t2 = "BLACK MUSTARD OIL"
    bbox1 = ldraw.textbbox((0, 0), t1, font=f_title_main1)
    bbox2 = ldraw.textbbox((0, 0), t2, font=f_title_main2)
    ldraw.text(((label_w - (bbox1[2] - bbox1[0])) / 2, div_y + 54), t1, fill=(24, 24, 27, 255), font=f_title_main1)
    ldraw.text(((label_w - (bbox2[2] - bbox2[0])) / 2, div_y + 96), t2, fill=(24, 24, 27, 255), font=f_title_main2)

    # Vector Botanical Mustard Branch & Kolhu Emblem
    emblem_y = div_y + 154
    emblem_r = 44
    ldraw.ellipse([(label_w/2 - emblem_r, emblem_y), (label_w/2 + emblem_r, emblem_y + emblem_r*2)], fill=(244, 247, 238, 255), outline=gold_outer, width=2)
    ldraw.ellipse([(label_w/2 - emblem_r + 4, emblem_y + 4), (label_w/2 + emblem_r - 4, emblem_y + emblem_r*2 - 4)], outline=gold_inner, width=1)
    
    cx, cy = label_w/2, emblem_y + emblem_r
    ldraw.line([(cx, cy + 28), (cx, cy - 20)], fill=(74, 114, 55, 255), width=3)
    flower_color = (234, 179, 8, 255)
    flower_center = (202, 138, 4, 255)
    for fx, fy in [(cx - 10, cy - 14), (cx + 10, cy - 14), (cx, cy - 24), (cx - 12, cy - 2), (cx + 12, cy - 2)]:
        ldraw.ellipse([fx - 5, fy - 5, fx + 5, fy + 5], fill=flower_color)
        ldraw.ellipse([fx - 2, fy - 2, fx + 2, fy + 2], fill=flower_center)
    ldraw.pieslice([cx - 16, cy + 4, cx - 2, cy + 16], start=90, end=270, fill=(74, 114, 55, 255))
    ldraw.pieslice([cx + 2, cy + 8, cx + 16, cy + 20], start=270, end=90, fill=(74, 114, 55, 255))

    claims_y = emblem_y + emblem_r*2 + 20
    claims = [
        "• Single-Origin Heirloom Rajasthan Seeds",
        "• Slow Crushed in Wooden Kolhu (<38°C)",
        "• Natural Allyl Isothiocyanate Pungency",
        "• Zero Chemical Hexane · Unrefined"
    ]
    for i, line in enumerate(claims):
        bbox = ldraw.textbbox((0, 0), line, font=f_desc)
        ldraw.text(((label_w - (bbox[2] - bbox[0])) / 2, claims_y + i * 30), line, fill=(55, 65, 81, 255), font=f_desc)

    div2_y = claims_y + 138
    ldraw.line([(35, div2_y), (label_w - 36, div2_y)], fill=gold_outer, width=2)
    ldraw.polygon([(label_w/2, div2_y - 5), (label_w/2 + 5, div2_y), (label_w/2, div2_y + 5), (label_w/2 - 5, div2_y)], fill=gold_outer)

    bot_y = div2_y + 18
    veg_x = 42
    veg_y = bot_y + 14
    ldraw.rectangle([veg_x, veg_y, veg_x + 36, veg_y + 36], outline=(34, 197, 94, 255), width=2)
    ldraw.ellipse([veg_x + 9, veg_y + 9, veg_x + 27, veg_y + 27], fill=(34, 197, 94, 255))

    vol_txt = "1 LITRE"
    bbox = ldraw.textbbox((0, 0), vol_txt, font=f_qty)
    ldraw.text(((label_w - (bbox[2] - bbox[0])) / 2, bot_y + 4), vol_txt, fill=(14, 66, 40, 255), font=f_qty)
    net_txt = "NET VOLUME"
    bbox_n = ldraw.textbbox((0, 0), net_txt, font=f_qty_sub)
    ldraw.text(((label_w - (bbox_n[2] - bbox_n[0])) / 2, bot_y + 44), net_txt, fill=(100, 116, 139, 255), font=f_qty_sub)

    stamp_x = label_w - 78
    ldraw.rectangle([stamp_x, veg_y, stamp_x + 36, veg_y + 36], outline=gold_outer, width=2)
    f_micro = ImageFont.truetype(font_sans_bold, 11)
    ldraw.text((stamp_x + 4, veg_y + 6), "NABL", fill=gold_outer, font=f_micro)
    ldraw.text((stamp_x + 4, veg_y + 20), "TEST", fill=gold_outer, font=f_micro)

    # 5. Cap
    cap_img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    cap_draw = ImageDraw.Draw(cap_img)
    cap_l, cap_r = 138, 386
    cap_t, cap_b = 40, 265

    for x in range(cap_l, cap_r):
        nx = (x - cap_l) / float(cap_r - cap_l)
        b_val = 26 + int(48 * math.sin(nx * math.pi))
        if 0.28 < nx < 0.42:
            b_val += int(52 * math.sin((nx - 0.28) / 0.14 * math.pi))
        if (x % 11) < 4:
            b_val = max(14, b_val - 16)
        cap_draw.line([(x, cap_t + 8), (x, cap_b - 10)], fill=(b_val, b_val, b_val + 3, 255))

    cap_draw.ellipse([cap_l, cap_t, cap_r, cap_t + 20], fill=(45, 45, 48, 255))
    cap_draw.arc([cap_l + 6, cap_t + 2, cap_r - 6, cap_t + 18], start=180, end=360, fill=(110, 110, 115, 255), width=2)
    cap_draw.rectangle([cap_l + 2, cap_b - 18, cap_r - 2, cap_b], fill=(24, 24, 26, 255))
    cap_draw.line([(cap_l + 3, cap_b - 16), (cap_r - 3, cap_b - 16)], fill=gold_outer, width=2)

    # 6. Composite
    comp = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    comp.paste(liquid_img, (0, 0), liquid_img)
    comp.paste(glass_shading, (0, 0), glass_shading)

    label_x = int((w - label_w) / 2)
    label_y = 860
    l_shadow = Image.new('RGBA', (label_w + 20, label_h + 20), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(l_shadow)
    s_draw.rounded_rectangle([10, 10, label_w + 10, label_h + 10], radius=8, fill=(0, 0, 0, 70))
    l_shadow = l_shadow.filter(ImageFilter.GaussianBlur(radius=6))
    comp.paste(l_shadow, (label_x - 10, label_y - 10), l_shadow)
    comp.paste(label, (label_x, label_y), label)

    front_sheen = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    f_draw = ImageDraw.Draw(front_sheen)
    for x in range(60, 125):
        alpha = int(45 * math.sin((x - 60) / 65.0 * math.pi))
        f_draw.line([(x, 760), (x, 2030)], fill=(255, 255, 255, alpha))
    comp.paste(front_sheen, (0, 0), front_sheen)

    comp.paste(specular, (0, 0), specular)
    comp.paste(cap_img, (0, 0), cap_img)
    comp.putalpha(bottle_mask)

    comp.save('milterra_mustard_oil_master.png')
    print('Master bottle updated!')

make_mustard_oil_bottle()

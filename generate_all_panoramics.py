import os
from PIL import Image, ImageFilter
import numpy as np

STORE_DIR = os.path.join('mobile', 'assets', 'store')

def make_seamless_panoramic(src_path, out_filename, target_w=1920, target_h=340):
    im = Image.open(src_path).convert('RGB')
    iw, ih = im.size
    
    # Scale center scene so height matches target_h (with 20px breathing margin)
    scene_h = target_h - 20
    scene_w = int(iw * (scene_h / float(ih)))
    scaled = im.resize((scene_w, scene_h), Image.Resampling.LANCZOS)
    
    # Create canvas
    canvas = Image.new('RGB', (target_w, target_h))
    
    # Sample background color from scene top and floor bottom
    arr = np.array(scaled)
    # Background wall color (top 35% of left/right edges)
    wall_color = arr[:int(scene_h*0.35), :15, :].mean(axis=(0,1))
    floor_color = arr[int(scene_h*0.7):, :15, :].mean(axis=(0,1))
    
    # Fill canvas with vertical gradient matching wall to floor
    cdraw = np.zeros((target_h, target_w, 3), dtype=np.uint8)
    for y in range(target_h):
        t = y / float(target_h)
        col = (1.0 - t) * wall_color + t * floor_color
        cdraw[y, :, :] = col.astype(np.uint8)
    canvas = Image.fromarray(cdraw)
    
    # Paste center scene with feathered soft alpha mask on left and right edges
    mask = Image.new('L', (scene_w, scene_h), 255)
    marr = np.ones((scene_h, scene_w), dtype=np.float32)
    feather_px = 75
    for x in range(feather_px):
        marr[:, x] = x / float(feather_px)
        marr[:, scene_w - 1 - x] = x / float(feather_px)
    mask = Image.fromarray((marr * 255).astype(np.uint8))
    
    center_x = int((target_w - scene_w) / 2)
    center_y = 10
    
    canvas.paste(scaled, (center_x, center_y), mask)
    out_path = os.path.join(STORE_DIR, out_filename)
    canvas.save(out_path, quality=95)
    print('Generated seamless panoramic:', out_filename)

# 1. Cow Ghee
make_seamless_panoramic(
    r'C:\Users\dileepkm\.gemini\antigravity\brain\456f7dff-368e-4312-90a2-afb3d61495d3\tilted_cow_ghee_hero_1791516848159.jpg',
    'panoramic-cow-ghee-hero.jpg'
)

# 2. Mustard Oil (using test_tilted_mustard_oil.jpg which has our new Marasca bottle on plinth!)
make_seamless_panoramic(
    'test_tilted_mustard_oil.jpg',
    'panoramic-mustard-oil-hero.jpg'
)

# 3. Buffalo Ghee
make_seamless_panoramic(
    r'C:\Users\dileepkm\.gemini\antigravity\brain\456f7dff-368e-4312-90a2-afb3d61495d3\tilted_buffalo_ghee_hero_1791516900979.jpg',
    'panoramic-buffalo-ghee-hero.jpg'
)

# 4. Malai Paneer
make_seamless_panoramic(
    r'C:\Users\dileepkm\.gemini\antigravity\brain\456f7dff-368e-4312-90a2-afb3d61495d3\tilted_paneer_hero_1791516923736.jpg',
    'panoramic-paneer-hero.jpg'
)

print('All 4 panoramic banners generated successfully!')

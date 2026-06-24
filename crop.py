import os
from PIL import Image

def crop_center_to_18_9(img_path):
    try:
        img = Image.open(img_path)
        w, h = img.size
        # We want width:height = 9:18 = 1:2
        target_w = w
        target_h = h
        
        # If the image is currently 1024x1024 (1:1)
        # To get 1:2, we can either crop the width or crop the height.
        # Since we want a vertical wallpaper, we should crop the width.
        # target_w = h / 2 = 1024 / 2 = 512
        if w > h / 2:
            target_w = h // 2
        elif h > w * 2:
            target_h = w * 2

        left = (w - target_w) / 2
        top = (h - target_h) / 2
        right = (w + target_w) / 2
        bottom = (h + target_h) / 2

        img_cropped = img.crop((left, top, right, bottom))
        # Ensure the image is saved properly
        img_cropped.save(img_path)
        print(f"Successfully cropped {img_path} to {img_cropped.size}")
    except Exception as e:
        print(f"Error processing {img_path}: {e}")

images = [
    'assets/wallpapers/landscape_1.png',
    'assets/wallpapers/landscape_2.png',
    'assets/wallpapers/plant_1.png',
    'assets/wallpapers/plant_2.png'
]

for img in images:
    if os.path.exists(img):
        crop_center_to_18_9(img)
    else:
        print(f"File not found: {img}")

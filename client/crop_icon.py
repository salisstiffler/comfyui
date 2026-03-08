from PIL import Image, ImageDraw

def create_squircle(size, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask

def main():
    img_path = 'assets/images/app_icon.png'
    img = Image.open(img_path).convert('RGBA')
    size = img.size[0]
    
    # 22.5% of size is a standard squircle-ish radius for app icons
    radius = int(size * 0.225)
    
    mask = create_squircle(size, radius)
    
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    output.paste(img, (0, 0), mask)
    
    output.save(img_path)
    print(f"Icon successfully cropped and saved to {img_path}")

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"Error: {e}")

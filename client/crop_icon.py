from PIL import Image, ImageDraw, ImageOps, ImageStat

def main():
    source_path = 'assets/images/app_icon_src.png' 
    output_path = 'assets/images/app_icon.png'
    
    try:
        img = Image.open(source_path).convert('RGBA')
        
        # Ensure it's square and centered
        width, height = img.size
        size = min(width, height)
        left = (width - size) // 2
        top = (height - size) // 2
        img = img.crop((left, top, left + size, top + size))
        
        # --- FIXED: Extract Alpha from Black Background ---
        # Convert to grayscale to get luminosity
        luminosity = img.convert('L')
        
        # Amplify luminosity to create a punchy alpha mask
        # Pure black (0) becomes 0, anything else gets brighter quickly
        alpha_mask = luminosity.point(lambda x: min(255, x * 3))
        
        # Keep original colors but with our new alpha
        r, g, b, _ = img.split()
        img = Image.merge('RGBA', (r, g, b, alpha_mask))
        
        # --- Padding and Squircle Mask ---
        inner_size = int(size * 0.85)
        img_resized = img.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        offset = (size - inner_size) // 2
        
        # Use img_resized itself as the mask for the paste operation to respect its transparency
        canvas.paste(img_resized, (offset, offset), img_resized)
        
        # Squircle mask for the outer bounds
        mask = Image.new('L', (size, size), 0)
        draw = ImageDraw.Draw(mask)
        radius = int(size * 0.25)
        draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
        
        final_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        final_img.paste(canvas, (0, 0), mask)
        
        final_img.save(output_path)
        print(f"Icon successfully processed with Luminosity Alpha and Squircle Mask: {output_path}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()

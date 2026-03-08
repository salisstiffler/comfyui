from PIL import Image, ImageDraw, ImageOps

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
        
        # Add internal padding so the icon doesn't look "cramped" in the squircle
        # Scale down the original a bit (e.g. 85%) and paste on transparent canvas
        inner_size = int(size * 0.85)
        img_resized = img.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        offset = (size - inner_size) // 2
        canvas.paste(img_resized, (offset, offset))
        
        # Create a squircle mask (Apple-style smoothness)
        mask = Image.new('L', (size, size), 0)
        draw = ImageDraw.Draw(mask)
        # Using a higher radius for a smoother squircle feel
        radius = int(size * 0.25)
        draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
        
        # Apply the mask to the clean canvas
        final_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        final_img.paste(canvas, (0, 0), mask)
        
        final_img.save(output_path)
        print(f"Icon successfully redesigned and cropped: {output_path}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()

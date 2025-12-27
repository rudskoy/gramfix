#!/usr/bin/env python3
"""
Generate proper app icon with gradient background from .icon format
Composes the gradient background + foreground layer into a complete icon
"""

import os
import subprocess
import sys
import json

# Ensure Pillow is available
try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow not found, please run from .venv")
    sys.exit(1)

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(PROJECT_DIR, "AppIcon.icon")
SCRIPTS_DIR = os.path.join(PROJECT_DIR, "scripts")
OUTPUT_SIZE = 1024

def parse_color(color_str):
    """Parse color from icon.json format like 'srgb:1.00000,0.54098,0.84731,1.00000'"""
    parts = color_str.split(":")
    if len(parts) == 2:
        values = [float(x) for x in parts[1].split(",")]
        return tuple(int(v * 255) for v in values[:3])
    return (128, 128, 128)

def create_rounded_rect_mask(size, radius):
    """Create a rounded rectangle mask for macOS app icon shape"""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    
    # macOS icons use a specific rounded rect with ~22.37% corner radius
    # For 1024px icon, that's about 229px radius
    actual_radius = int(size * 0.2237)
    
    draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)],
        radius=actual_radius,
        fill=255
    )
    return mask

def create_gradient_background(size, color1, color2, start_y=0.0, end_y=0.7):
    """Create vertical gradient background"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    start_px = int(size * start_y)
    end_px = int(size * end_y)
    
    for y in range(size):
        if y < start_px:
            color = color1
        elif y > end_px:
            color = color2
        else:
            # Linear interpolation
            t = (y - start_px) / max(1, (end_px - start_px))
            color = tuple(int(color1[i] + (color2[i] - color1[i]) * t) for i in range(3))
        
        draw.line([(0, y), (size - 1, y)], fill=(*color, 255))
    
    return img

def main():
    # Read icon.json for gradient colors
    icon_json_path = os.path.join(ICON_DIR, "icon.json")
    with open(icon_json_path, 'r') as f:
        icon_data = json.load(f)
    
    # Extract gradient colors
    gradient = icon_data.get("fill", {}).get("linear-gradient", [])
    if len(gradient) >= 2:
        color1 = parse_color(gradient[0])  # Pink: (255, 138, 216)
        color2 = parse_color(gradient[1])  # Blue: (84, 175, 255)
    else:
        color1 = (255, 138, 216)
        color2 = (84, 175, 255)
    
    print(f"Gradient colors: {color1} → {color2}")
    
    # Get gradient orientation
    orientation = icon_data.get("fill", {}).get("orientation", {})
    start_y = orientation.get("start", {}).get("y", 0.0)
    end_y = orientation.get("stop", {}).get("y", 0.7)
    
    # Create gradient background
    print("Creating gradient background...")
    background = create_gradient_background(OUTPUT_SIZE, color1, color2, start_y, end_y)
    
    # Load foreground layer
    assets_dir = os.path.join(ICON_DIR, "Assets")
    fg_files = [f for f in os.listdir(assets_dir) if f.endswith('.png')]
    if not fg_files:
        print("Error: No foreground PNG found in Assets folder")
        sys.exit(1)
    
    fg_path = os.path.join(assets_dir, fg_files[0])
    print(f"Loading foreground: {fg_files[0]}")
    foreground = Image.open(fg_path).convert('RGBA')
    
    # Get layer position/scale from icon.json
    groups = icon_data.get("groups", [])
    scale = 1.0
    if groups and groups[0].get("layers"):
        layer = groups[0]["layers"][0]
        scale = layer.get("position", {}).get("scale", 1.0)
    
    print(f"Foreground scale: {scale}")
    
    # Resize foreground if needed
    if foreground.size[0] != OUTPUT_SIZE:
        foreground = foreground.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    
    # Scale the foreground
    if scale != 1.0:
        new_size = int(OUTPUT_SIZE * scale)
        foreground_scaled = foreground.resize((new_size, new_size), Image.Resampling.LANCZOS)
        # Center it
        offset = (OUTPUT_SIZE - new_size) // 2
        foreground_final = Image.new('RGBA', (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
        foreground_final.paste(foreground_scaled, (offset, offset))
        foreground = foreground_final
    
    # Composite foreground over background
    print("Compositing layers...")
    result = Image.alpha_composite(background, foreground)
    
    # Apply rounded rectangle mask for macOS icon shape
    mask = create_rounded_rect_mask(OUTPUT_SIZE, int(OUTPUT_SIZE * 0.2237))
    
    # Create final image with transparency outside the rounded rect
    final = Image.new('RGBA', (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    final.paste(result, (0, 0), mask)
    
    # Save the composed icon
    output_path = os.path.join(SCRIPTS_DIR, "AppIcon-composed.png")
    final.save(output_path, 'PNG')
    print(f"✓ Composed icon saved: {output_path}")
    
    # Now create iconset and icns
    iconset_dir = os.path.join(SCRIPTS_DIR, "Gramfix.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    
    print("Generating icon sizes...")
    for size, filename in sizes:
        resized = final.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename), 'PNG')
    
    # Convert to icns
    icns_path = os.path.join(SCRIPTS_DIR, "Gramfix.icns")
    print("Converting to icns...")
    subprocess.run(['iconutil', '-c', 'icns', iconset_dir, '-o', icns_path], check=True)
    
    print(f"✓ App icon created: {icns_path}")
    print(f"  Size: {os.path.getsize(icns_path) / 1024:.1f} KB")

if __name__ == "__main__":
    main()







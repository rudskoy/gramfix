#!/usr/bin/env python3
"""
Generate a beautiful DMG background for Gramfix
Matches the app's pink-to-blue gradient aesthetic with arrow and instructions
"""

import os
import sys
import math

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Error: Pillow not installed. Run: source .venv/bin/activate")
    sys.exit(1)

# DMG window dimensions (2x for Retina)
WIDTH = 540 * 2
HEIGHT = 380 * 2

# Icon positions (2x for Retina) - centered vertically
APP_X = 130 * 2
APP_Y = 190 * 2
APPS_X = 410 * 2
APPS_Y = 190 * 2

# Colors from Gramfix's gradient (pink to blue)
PINK = (255, 138, 216)
BLUE = (84, 175, 255)
DARK_BG = (30, 30, 34)
DARKER_BG = (20, 20, 24)

def lerp_color(c1, c2, t):
    """Linear interpolation between two colors"""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def create_gradient_background(draw, width, height):
    """Create a dark gradient background"""
    for y in range(height):
        t = y / height
        base = lerp_color(DARKER_BG, DARK_BG, t * 0.5)
        draw.line([(0, y), (width, y)], fill=base)

def draw_glow(img, center_x, center_y, radius, color, intensity=0.15):
    """Draw a soft glow effect"""
    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    for r in range(radius, 0, -3):
        alpha = int(255 * intensity * (r / radius) ** 2)
        glow_color = (*color, alpha)
        glow_draw.ellipse([
            center_x - r, center_y - r,
            center_x + r, center_y + r
        ], fill=glow_color)
    
    return Image.alpha_composite(img.convert('RGBA'), glow)

def draw_curved_arrow(draw, start, end, color, thickness=6):
    """Draw a beautiful curved arrow between two points"""
    x1, y1 = start
    x2, y2 = end
    
    # Control point for bezier curve (arc upward)
    mid_x = (x1 + x2) / 2
    mid_y = min(y1, y2) - 80 * 2  # Arc above the icons
    
    # Calculate bezier curve points
    points = []
    steps = 60
    for i in range(steps + 1):
        t = i / steps
        # Quadratic bezier curve
        x = (1-t)**2 * x1 + 2*(1-t)*t * mid_x + t**2 * x2
        y = (1-t)**2 * y1 + 2*(1-t)*t * mid_y + t**2 * y2
        points.append((x, y))
    
    # Draw the curve with anti-aliased lines
    for i in range(len(points) - 1):
        # Create gradient along the arrow (pink to blue)
        t = i / len(points)
        segment_color = lerp_color(PINK, BLUE, t)
        draw.line([points[i], points[i + 1]], fill=(*segment_color, 255), width=thickness)
    
    # Draw arrowhead at the end
    arrow_size = 25 * 2
    # Get direction at end point
    dx = points[-1][0] - points[-5][0]
    dy = points[-1][1] - points[-5][1]
    length = math.sqrt(dx*dx + dy*dy)
    if length > 0:
        dx, dy = dx/length, dy/length
    
    end_x, end_y = points[-1]
    angle = math.atan2(dy, dx)
    
    # Arrow head points
    arrow_points = [
        (end_x + 5, end_y),  # Tip slightly extended
        (end_x - arrow_size * math.cos(angle - 0.5), 
         end_y - arrow_size * math.sin(angle - 0.5)),
        (end_x - arrow_size * 0.6 * math.cos(angle), 
         end_y - arrow_size * 0.6 * math.sin(angle)),
        (end_x - arrow_size * math.cos(angle + 0.5), 
         end_y - arrow_size * math.sin(angle + 0.5)),
    ]
    draw.polygon(arrow_points, fill=(*BLUE, 255))

def get_font(size):
    """Get a nice font, with fallbacks"""
    font_paths = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
    ]
    for path in font_paths:
        try:
            return ImageFont.truetype(path, size)
        except:
            continue
    return ImageFont.load_default()

def main():
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    scripts_dir = os.path.join(project_dir, "scripts")
    
    # Create base image
    img = Image.new('RGB', (WIDTH, HEIGHT), DARK_BG)
    draw = ImageDraw.Draw(img)
    
    # Draw gradient background
    create_gradient_background(draw, WIDTH, HEIGHT)
    
    # Convert to RGBA for transparency effects
    img = img.convert('RGBA')
    
    # Add subtle colored glows under icon positions
    img = draw_glow(img, APP_X, APP_Y, 200 * 2, PINK, 0.12)
    img = draw_glow(img, APPS_X, APPS_Y, 200 * 2, BLUE, 0.12)
    
    # Get fresh draw object
    draw = ImageDraw.Draw(img)
    
    # Draw curved arrow from app to Applications
    # Start from right side of app icon, end at left side of Applications
    arrow_start = (APP_X + 70 * 2, APP_Y - 50 * 2)
    arrow_end = (APPS_X - 70 * 2, APPS_Y - 50 * 2)
    draw_curved_arrow(draw, arrow_start, arrow_end, PINK, thickness=8)
    
    # Add instruction text
    font_large = get_font(32 * 2)
    font_small = get_font(18 * 2)
    
    # Main instruction
    text_main = "Drag to Install"
    bbox = draw.textbbox((0, 0), text_main, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_x = (WIDTH - text_width) / 2
    text_y = HEIGHT - 70 * 2
    
    # Draw text with gradient-like color (mix of pink and blue)
    text_color = lerp_color(PINK, BLUE, 0.4)
    draw.text((text_x, text_y), text_main, fill=(*text_color, 255), font=font_large)
    
    # Subtitle
    text_sub = "Drop Gramfix onto the Applications folder"
    bbox_sub = draw.textbbox((0, 0), text_sub, font=font_small)
    text_sub_width = bbox_sub[2] - bbox_sub[0]
    text_sub_x = (WIDTH - text_sub_width) / 2
    text_sub_y = text_y + 50 * 2
    
    # Subtle gray for subtitle
    draw.text((text_sub_x, text_sub_y), text_sub, fill=(150, 150, 160, 200), font=font_small)
    
    # Save the background
    output_path = os.path.join(scripts_dir, "dmg-background.png")
    
    # Convert to RGB for saving (remove alpha for DMG compatibility)
    final = Image.new('RGB', img.size, DARK_BG)
    final.paste(img, (0, 0), img.split()[3] if img.mode == 'RGBA' else None)
    
    final.save(output_path, "PNG")
    print(f"✓ DMG background created: {output_path}")
    print(f"  Size: {WIDTH}x{HEIGHT} (Retina-ready)")

if __name__ == "__main__":
    main()

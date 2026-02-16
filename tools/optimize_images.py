#!/usr/bin/env python3
"""
Script to compress and optimize images for Doctor Store
Converts images to WebP format and resizes them for web use
"""

import os
import sys
from pathlib import Path
from PIL import Image
import argparse

# Configuration for different image variants
VARIANTS = {
    'product_card': {'width': 300, 'height': 300, 'quality': 60, 'resize': 'cover'},
    'thumbnail': {'width': 300, 'height': 300, 'quality': 60, 'resize': 'cover'},
    'mattress_card': {'width': 420, 'height': 320, 'quality': 75, 'resize': 'contain'},
    'hero_banner': {'width': 800, 'height': 450, 'quality': 70, 'resize': 'contain'},
    'home_banner': {'width': 800, 'height': 400, 'quality': 70, 'resize': 'contain'},
    'full_screen': {'width': 800, 'height': 800, 'quality': 75, 'resize': 'contain'},
}

def optimize_image(input_path, output_path, width, height, quality, resize_mode='cover'):
    """
    Optimize a single image by resizing and converting to WebP
    """
    with Image.open(input_path) as img:
        # Convert to RGB if necessary (for PNG with transparency)
        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')
        
        # Calculate dimensions
        orig_width, orig_height = img.size
        aspect_ratio = orig_width / orig_height
        
        if resize_mode == 'cover':
            # Fill the dimensions, may crop
            new_width = width
            new_height = int(new_width / aspect_ratio)
            if new_height < height:
                new_height = height
                new_width = int(new_height * aspect_ratio)
        else:  # contain
            # Fit within dimensions, no cropping
            new_width = width
            new_height = int(new_width / aspect_ratio)
            if new_height > height:
                new_height = height
                new_width = int(new_height * aspect_ratio)
        
        # Resize with high quality
        img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Save as WebP with specified quality
        img.save(output_path, 'WEBP', quality=quality, method=6)
        
        # Calculate compression ratio
        original_size = os.path.getsize(input_path) / 1024  # KB
        compressed_size = os.path.getsize(output_path) / 1024  # KB
        ratio = ((original_size - compressed_size) / original_size) * 100
        
        return {
            'original_size': original_size,
            'compressed_size': compressed_size,
            'ratio': ratio,
            'dimensions': (new_width, new_height)
        }

def process_directory(input_dir, output_dir, variant='product_card'):
    """
    Process all images in a directory
    """
    config = VARIANTS[variant]
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    results = []
    
    # Supported image formats
    extensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff'}
    
    for ext in extensions:
        for img_file in input_path.glob(f'*{ext}'):
            output_file = output_path / f"{img_file.stem}.webp"
            
            try:
                result = optimize_image(
                    img_file, 
                    output_file,
                    config['width'],
                    config['height'],
                    config['quality'],
                    config['resize']
                )
                result['filename'] = img_file.name
                results.append(result)
                
                print(f"✓ {img_file.name}: {result['original_size']:.1f}KB → {result['compressed_size']:.1f}KB ({result['ratio']:.1f}% reduction)")
            except Exception as e:
                print(f"✗ {img_file.name}: {str(e)}")
    
    return results

def print_summary(results):
    """
    Print summary of compression results
    """
    if not results:
        print("\nNo images processed.")
        return
    
    total_original = sum(r['original_size'] for r in results)
    total_compressed = sum(r['compressed_size'] for r in results)
    avg_ratio = ((total_original - total_compressed) / total_original) * 100
    
    print("\n" + "="*60)
    print("COMPRESSION SUMMARY")
    print("="*60)
    print(f"Images processed: {len(results)}")
    print(f"Total original size: {total_original/1024:.2f} MB")
    print(f"Total compressed size: {total_compressed/1024:.2f} MB")
    print(f"Space saved: {avg_ratio:.1f}%")
    print("="*60)

def main():
    parser = argparse.ArgumentParser(description='Optimize images for Doctor Store')
    parser.add_argument('input_dir', help='Directory containing original images')
    parser.add_argument('output_dir', help='Directory for optimized images')
    parser.add_argument('--variant', choices=VARIANTS.keys(), default='product_card',
                       help='Image variant to optimize for')
    
    args = parser.parse_args()
    
    print(f"\nOptimizing images from: {args.input_dir}")
    print(f"Output directory: {args.output_dir}")
    print(f"Variant: {args.variant}")
    print("-" * 60)
    
    results = process_directory(args.input_dir, args.output_dir, args.variant)
    print_summary(results)

if __name__ == '__main__':
    main()

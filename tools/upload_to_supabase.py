#!/usr/bin/env python3
"""
Upload optimized images to Supabase Storage
"""

import os
import sys
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Supabase credentials (set these in .env file)
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_KEY')  # Use service role key for uploads

def get_supabase_client():
    """Create Supabase client"""
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("Error: Set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env file")
        sys.exit(1)
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def upload_image(supabase: Client, local_path: Path, bucket: str, remote_path: str):
    """Upload a single image to Supabase Storage"""
    try:
        with open(local_path, 'rb') as f:
            response = supabase.storage.from_(bucket).upload(
                remote_path,
                f,
                file_options={'content-type': 'image/webp'}
            )
        return True, response
    except Exception as e:
        return False, str(e)

def upload_directory(supabase: Client, local_dir: str, bucket: str, remote_prefix: str = ''):
    """Upload all images from a directory"""
    local_path = Path(local_dir)
    
    webp_files = list(local_path.glob('*.webp'))
    
    if not webp_files:
        print(f"No .webp files found in {local_dir}")
        return
    
    print(f"\nUploading {len(webp_files)} images to Supabase...")
    print("-" * 60)
    
    success_count = 0
    failed_files = []
    
    for img_file in webp_files:
        remote_path = f"{remote_prefix}/{img_file.name}" if remote_prefix else img_file.name
        
        success, result = upload_image(supabase, img_file, bucket, remote_path)
        
        if success:
            success_count += 1
            print(f"✓ {img_file.name}")
        else:
            failed_files.append((img_file.name, result))
            print(f"✗ {img_file.name}: {result}")
    
    print("-" * 60)
    print(f"\nUploaded: {success_count}/{len(webp_files)}")
    
    if failed_files:
        print(f"\nFailed uploads:")
        for name, error in failed_files:
            print(f"  - {name}: {error}")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Upload images to Supabase Storage')
    parser.add_argument('local_dir', help='Directory containing optimized images')
    parser.add_argument('--bucket', default='products', help='Supabase storage bucket name')
    parser.add_argument('--prefix', default='', help='Remote path prefix')
    
    args = parser.parse_args()
    
    print(f"Connecting to Supabase: {SUPABASE_URL}")
    supabase = get_supabase_client()
    
    upload_directory(supabase, args.local_dir, args.bucket, args.prefix)
    
    print("\n✅ Upload complete!")
    print("\nNext steps:")
    print("1. Check images in Supabase Dashboard")
    print("2. Test the website: https://www.drstore.me")
    print("3. If everything works, delete old images from Supabase")

if __name__ == '__main__':
    main()

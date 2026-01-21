import os

def normalize_line_endings_to_crlf(directory):
    print(f"Scanning directory: {directory}")
    
    # Get all .bat files
    bat_files = [f for f in os.listdir(directory) if f.lower().endswith(".bat")]
    
    if not bat_files:
        print("No .bat files found.")
        return

    for filename in bat_files:
        filepath = os.path.join(directory, filename)
        
        try:
            # Read in binary mode to see exact bytes
            with open(filepath, 'rb') as f:
                content = f.read()
            
            # Check if empty
            if not content:
                print(f"Skipping empty file: {filename}")
                continue

            # Check existing line endings
            # Windows needs \r\n (CRLF). Mac/Linux usually gives \n (LF).
            
            # Normalize: Replace all \r\n with \n first, then all \n with \r\n
            # This handles mixed cases or already correct cases safely
            new_content = content.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
            
            # Write back only if changed
            if content != new_content:
                with open(filepath, 'wb') as f:
                    f.write(new_content)
                print(f"[FIXED] {filename}: Converted to CRLF.")
            else:
                print(f"[OK]    {filename}: Already CRLF.")
                
        except Exception as e:
            print(f"[ERROR] {filename}: {e}")

if __name__ == "__main__":
    # Run on current directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    normalize_line_endings_to_crlf(current_dir)
    
    print("\nDone! Please copy these files to your Windows PC now.")

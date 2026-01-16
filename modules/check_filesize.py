#!/usr/bin/env python3
import sys
import os

def main():
    try:
        max_bytes = int(sys.argv[1])
    except (IndexError, ValueError):
        # Default to 1MB if not provided or invalid
        max_bytes = 1048576

    # Use sys.stdin.buffer to read binary data (filenames can be anything)
    try:
        stream = sys.stdin.buffer
    except AttributeError:
        stream = sys.stdin

    try:
        content = stream.read()
    except Exception:
        return

    if not content:
        return

    # Split by null byte
    files = content.split(b'\0')

    for f_bytes in files:
        if not f_bytes:
            continue

        try:
            st = os.stat(f_bytes)
            if st.st_size >= max_bytes:
                # Output format: size\tfilename
                # Decode filename for display, replace errors to avoid crash
                try:
                    fname = f_bytes.decode('utf-8', 'replace')
                except:
                    fname = str(f_bytes)
                print(f"{st.st_size}\t{fname}")
        except OSError:
            # File might have been deleted or is not accessible
            continue

if __name__ == "__main__":
    main()

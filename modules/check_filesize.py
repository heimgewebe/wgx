#!/usr/bin/env python3
import sys
import os

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: check_filesize.py <max_bytes>\n")
        sys.exit(2)

    try:
        max_bytes = int(sys.argv[1])
    except ValueError:
        sys.stderr.write("Error: max_bytes must be an integer\n")
        sys.exit(2)

    # Use sys.stdin.buffer to read binary data
    try:
        stream = sys.stdin.buffer
    except AttributeError:
        stream = sys.stdin

    buffer = bytearray()
    chunk_size = 65536
    found_oversized = False

    while True:
        try:
            chunk = stream.read(chunk_size)
        except Exception:
            break

        if not chunk:
            break

        buffer.extend(chunk)
        offset = 0

        # Optimization: Scan via offset instead of modifying the buffer repeatedly.
        # This avoids O(N^2) memory moves when processing many small files in one chunk.
        while True:
            try:
                # Find the next null byte
                null_index = buffer.index(b'\0', offset)
            except ValueError:
                # No null byte found, wait for more data
                break

            # Extract the filename as immutable bytes
            file_bytes = bytes(buffer[offset:null_index])
            offset = null_index + 1

            if not file_bytes:
                continue

            try:
                # Use os.fsdecode for robust decoding (surrogateescape on POSIX)
                fname = os.fsdecode(file_bytes)
                st = os.stat(file_bytes)
                if st.st_size >= max_bytes:
                    print(f"{st.st_size}\t{fname}")
                    found_oversized = True
            except OSError:
                # File might have been deleted or is not accessible
                pass
            except Exception as e:
                sys.stderr.write(f"Error processing file: {e}\n")

        if offset > 0:
            del buffer[:offset]

    # Process any remaining data in buffer (though find -print0 usually ends with \0)
    if buffer:
        file_bytes = bytes(buffer)
        try:
            fname = os.fsdecode(file_bytes)
            st = os.stat(file_bytes)
            if st.st_size >= max_bytes:
                print(f"{st.st_size}\t{fname}")
                found_oversized = True
        except OSError:
            pass

    if found_oversized:
        sys.exit(1)

    sys.exit(0)

if __name__ == "__main__":
    main()

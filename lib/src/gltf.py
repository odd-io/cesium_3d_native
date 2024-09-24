import sys
import struct

def read_chunk(file, length):
    return file.read(length)

def check_and_validate_glb(file_path):
    with open(file_path, 'rb') as file:
        # Read GLB header
        header = read_chunk(file, 12)
        magic, version, length = struct.unpack('<4sII', header)
        
        if magic != b'glTF':
            print("Not a valid GLB file")
            return

        print(f"Examining GLB file: {file_path}")
        print(f"GLB version: {version}")
        print(f"Total file length: {length} bytes")

        # Read JSON chunk
        chunk_header = read_chunk(file, 8)
        json_length, json_type = struct.unpack('<II', chunk_header)
        json_data = read_chunk(file, json_length)

        print(f"\nJSON chunk length: {json_length} bytes")

        # Read Binary chunk
        chunk_header = read_chunk(file, 8)
        bin_length, bin_type = struct.unpack('<II', chunk_header)
        bin_data = read_chunk(file, bin_length)

        print(f"\nBinary chunk length: {bin_length} bytes")

        # Parse JSON data
        import json
        gltf = json.loads(json_data)

        # Validate buffers
        print("\nValidating Buffers:")
        for i, buffer in enumerate(gltf['buffers']):
            print(f"  Buffer {i}:")
            declared_length = buffer['byteLength']
            print(f"    Declared length: {declared_length}")
            if i == 0:  # Assuming the first buffer is the embedded one
                actual_length = len(bin_data)
                print(f"    Actual length: {actual_length}")
                if declared_length != actual_length:
                    print(f"    WARNING: Declared length ({declared_length}) does not match actual binary chunk length ({actual_length})")
            else:
                print("    NOTE: This is not the embedded buffer, skipping validation")

        # Validate buffer views
        print("\nValidating Buffer Views:")
        for i, view in enumerate(gltf['bufferViews']):
            print(f"  Buffer View {i}:")
            buffer_index = view['buffer']
            byte_offset = view.get('byteOffset', 0)
            byte_length = view['byteLength']
            
            print(f"    Buffer: {buffer_index}")
            print(f"    Byte Offset: {byte_offset}")
            print(f"    Byte Length: {byte_length}")

            if buffer_index == 0:  # Assuming buffer 0 is the embedded one
                if byte_offset + byte_length <= len(bin_data):
                    print("    Valid: Within binary chunk bounds")
                else:
                    print(f"    WARNING: Buffer view extends beyond binary chunk (chunk size: {len(bin_data)})")
            else:
                print("    NOTE: This view does not reference the embedded buffer, skipping validation")

        # Validate accessors (optional, but can be helpful)
        if 'accessors' in gltf:
            print("\nValidating Accessors:")
            for i, accessor in enumerate(gltf['accessors']):
                print(f"  Accessor {i}:")
                if 'bufferView' in accessor:
                    buffer_view = gltf['bufferViews'][accessor['bufferView']]
                    if buffer_view['buffer'] == 0:  # Embedded buffer
                        start = buffer_view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
                        component_type_size = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
                        type_count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT2': 4, 'MAT3': 9, 'MAT4': 16}
                        expected_length = accessor['count'] * component_type_size[accessor['componentType']] * type_count[accessor['type']]
                        
                        print(f"    Start Offset: {start}")
                        print(f"    Expected Length: {expected_length}")
                        
                        if start + expected_length <= len(bin_data):
                            print("    Valid: Within binary chunk bounds")
                        else:
                            print(f"    WARNING: Accessor data extends beyond binary chunk (chunk size: {len(bin_data)})")
                    else:
                        print("    NOTE: This accessor does not reference the embedded buffer, skipping validation")
                else:
                    print("    NOTE: This accessor does not reference a buffer view, skipping validation")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <path_to_glb_file>")
        sys.exit(1)
    
    glb_file_path = sys.argv[1]
    check_and_validate_glb(glb_file_path)
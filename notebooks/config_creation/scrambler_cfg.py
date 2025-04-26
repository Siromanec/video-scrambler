import argparse
import numpy as np
import mif  # Using your interface
import os

# Constants
MODE_ADDR = 0
SEED_ADDR_START = 32
SEED_ADDR_END = 64
MEM_SIZE = 64

def parse_args():
    parser = argparse.ArgumentParser(description="Fill memory and dump to MIF file.")
    parser.add_argument('--seed', required=True, help="256-bit seed in hex (64 hex characters).")
    parser.add_argument('--output_dir', default='out', help="Output MIF destination")
    return parser.parse_args()

def hex_to_bytes(seed_hex):
    seed_hex = seed_hex.lower().replace("0x", "")
    if len(seed_hex) != 64 or not all(c in "0123456789abcdef" for c in seed_hex):
        raise ValueError("Seed must be exactly 64 hex characters (256 bits).")
    return bytes.fromhex(seed_hex)

def fill_memory(seed_bytes: bytes) -> (np.ndarray, np.ndarray):
    mem = np.zeros(MEM_SIZE, dtype=np.uint8)

    # Fill seed into addresses 32–63
    mem[SEED_ADDR_START:SEED_ADDR_END] = np.frombuffer(seed_bytes, dtype=np.uint8)

    mem_copy  = mem.copy()

    # Map mode to value
    # if mode == 'scrambler':
    mem_copy[MODE_ADDR] = 0
    # elif mode == 'descrambler':
    mem[MODE_ADDR] = 1



    return mem_copy, mem

def save_to_mif(mem: np.ndarray, output_file: str):
    bit_mem = np.unpackbits(mem, bitorder="little").reshape(-1, 8)

    with open(output_file, 'w') as fp:
        mif.dump(bit_mem, fp)

    print(f"Memory dumped to '{output_file}'")

def main():
    args = parse_args()
    seed_bytes = hex_to_bytes(args.seed)
    mem_scr, mem_descr = fill_memory(seed_bytes)
    os.makedirs(os.path.join(args.output_dir, "scrambler"), exist_ok=True)
    os.makedirs(os.path.join(args.output_dir, "descrambler"), exist_ok=True)
    save_to_mif(mem_scr, os.path.join(args.output_dir, "scrambler", "scrambler.mif"))
    save_to_mif(mem_descr, os.path.join(args.output_dir, "descrambler", "scrambler.mif"))

if __name__ == "__main__":
    main()

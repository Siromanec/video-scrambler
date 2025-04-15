import getpass
import hashlib
import os
import argparse
import binascii
# debug value: 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
def derive_key(passphrase: str, salt: bytes, iterations: int = 100_000) -> bytes:
    return hashlib.pbkdf2_hmac(
        hash_name='sha256',
        password=passphrase.encode('utf-8'),
        salt=salt,
        iterations=iterations,
        dklen=32  # 256 bits
    )

def main():
    parser = argparse.ArgumentParser(description="Derive a 256-bit key from a passphrase.")
    parser.add_argument("--salt", help="Hex-encoded salt (or generated if omitted)", default=None)
    parser.add_argument("--show", action="store_true", help="Show the derived key in hex")
    args = parser.parse_args()
    # Use provided salt or generate one
    if args.salt:
        if len(args.salt) < 2:
            print("Salt must contain at least 2 digits")
            exit(1)
        salt = bytes.fromhex(args.salt)
    else:
        salt = os.urandom(16)
        print(f"Generated salt (save this!): {salt.hex()}")
    # Securely prompt for passphrase (no echo)
    passphrase = getpass.getpass("Enter passphrase: ")



    key = derive_key(passphrase, salt)

    print(f"Derived 256-bit key: {key.hex()}")

if __name__ == "__main__":
    main()

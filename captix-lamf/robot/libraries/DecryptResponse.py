"""AES-256-GCM payload decryption helper.

Wire format: base64(iv[12] + ciphertext + tag[16]).
The shared key must be base64-encoded (32 bytes -> 44-char b64 string).
"""

import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def decrypt_value(encoded_text: str, key_base64: str) -> str:
    """Decrypts a base64 AES-GCM blob using the supplied base64-encoded key.

    Args:
        encoded_text: base64(iv[12] || ciphertext || tag[16])
        key_base64:   base64-encoded 32-byte AES key

    Returns:
        The decoded UTF-8 plaintext.
    """
    key = base64.b64decode(key_base64)
    combined = base64.b64decode(encoded_text)

    iv = combined[:12]
    ciphertext = combined[12:]

    aesgcm = AESGCM(key)
    decrypted = aesgcm.decrypt(iv, ciphertext, None)

    return decrypted.decode("utf-8")

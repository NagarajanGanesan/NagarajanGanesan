import hmac
import hashlib
from datetime import datetime

def generate_timestamp():
    """Returns timestamp in yyyyMMddHHmmss format."""
    return datetime.now().strftime("%Y%m%d%H%M%S")


def generate_hmac_signature(hmac_key: str, payload: str, timestamp: str, timestamp_only: bool = False) -> str:
    """Generates HmacSHA256 hex signature matching SignatureGeneration.java logic."""
    if timestamp_only or not payload:
        message = timestamp
    else:
        message = f"{payload}::{timestamp}"

    return hmac.new(
        hmac_key.encode("utf-8"),
        message.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
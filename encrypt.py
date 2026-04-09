#!/usr/bin/env python3
import os, hashlib, base64, sys
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import re

with open('.env', 'r') as f:
    passphrase = next((line.split('=', 1)[1].strip() for line in f if line.startswith('ENCRYPTION_KEY=')), None)

with open('content.html', 'r', encoding='utf-8') as f:
    content = f.read()

salt = os.urandom(16)
iv = os.urandom(12)
key = hashlib.pbkdf2_hmac('sha256', passphrase.encode('utf-8'), salt, 2000000, dklen=32)
aesgcm = AESGCM(key)
ciphertext_with_tag = aesgcm.encrypt(iv, content.encode('utf-8'), None)
payload = base64.b64encode(salt).decode() + '.' + base64.b64encode(iv).decode() + '.' + base64.b64encode(ciphertext_with_tag).decode()
with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()
html = re.sub(r"const\s+E\s*=\s*'[^']*'", f"const E = '{payload}'", html)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

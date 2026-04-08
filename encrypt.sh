#!/bin/bash
# encrypt.sh
# Auto-encrypt content.html into index.html

# DIR is the directory where encrypt.sh is located
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -f "content.html" ] && [ -f ".env" ]; then
  echo "🔐 Encrypting content.html → index.html..."

  # Dump the Python script to a temporary file to avoid Bash quoting issues
  cat << 'EOF' > .temp_encrypt.py
import os, hashlib, base64, sys

USE_CRYPTOGRAPHY = False
try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    USE_CRYPTOGRAPHY = True
except ImportError:
    pass

with open('.env', 'r') as f:
    passphrase = next((line.split('=', 1)[1].strip() for line in f if line.startswith('ENCRYPTION_KEY=')), None)

if not passphrase:
    print('[Error] ENCRYPTION_KEY not set in .env')
    sys.exit(1)

with open('content.html', 'r', encoding='utf-8') as f:
    content = f.read()

salt = os.urandom(16)
iv = os.urandom(12)
key = hashlib.pbkdf2_hmac('sha256', passphrase.encode('utf-8'), salt, 600000, dklen=32)

if USE_CRYPTOGRAPHY:
    aesgcm = AESGCM(key)
    ciphertext_with_tag = aesgcm.encrypt(iv, content.encode('utf-8'), None)
else:
    import subprocess, tempfile
    content_bytes = content.encode('utf-8')
    with tempfile.NamedTemporaryFile(delete=False, suffix='.bin') as tmp:
        tmp.write(content_bytes)
        tmp_path = tmp.name
    try:
        result = subprocess.run([
            'openssl', 'enc', '-aes-256-gcm',
            '-K', key.hex(), '-iv', iv.hex(), '-in', tmp_path, '-nosalt'
        ], capture_output=True)
        if result.returncode != 0:
            print('[Error] No encryption library available.')
            sys.exit(1)
        ciphertext_with_tag = result.stdout
    finally:
        os.unlink(tmp_path)

payload = base64.b64encode(salt).decode() + '.' + base64.b64encode(iv).decode() + '.' + base64.b64encode(ciphertext_with_tag).decode()

import re
with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()
html = re.sub(r"const\s+E\s*=\s*'[^']*'", f"const E = '{payload}'", html)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)
EOF

  # Detect the valid python environment to use.
  if command -v wsl >/dev/null 2>&1 && wsl python3 -c 'import sys; sys.exit(0)' 2>/dev/null; then
      wsl python3 .temp_encrypt.py
      RET=$?
  elif python3 -c 'import sys; sys.exit(0)' 2>/dev/null; then
      python3 .temp_encrypt.py
      RET=$?
  elif python -c 'import sys; sys.exit(0)' 2>/dev/null; then
      python .temp_encrypt.py
      RET=$?
  else
      echo "[Error] Python is required to encrypt the payload. Please install Python."
      RET=1
  fi
  
  rm -f .temp_encrypt.py
  
  if [ $RET -ne 0 ]; then
      exit $RET
  fi

  # Support running stand-alone vs inside a git hook
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git add index.html
  fi
else
  echo "[Warning] content.html or .env file is missing. Skipping encryption."
fi

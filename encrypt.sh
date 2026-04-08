#!/bin/bash
# encrypt.sh
# Auto-encrypt content.html into index.html

# DIR is the directory where encrypt.sh is located
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -f "content.html" ] && [ -f ".env" ]; then
  echo "🔐 Encrypting content.html → index.html..."

  # Define the Python script
  PY_SCRIPT="
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

html = f'''<!DOCTYPE html>
<html><head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
<title>.</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{height:100%;background:#0a0a0a}}
body{{display:flex;align-items:center;justify-content:center}}
#k{{background:transparent;border:none;border-bottom:1px solid rgba(255,255,255,0.06);color:transparent;caret-color:rgba(255,255,255,0.15);font-size:16px;padding:8px 0;width:200px;outline:none;text-align:center;letter-spacing:2px;-webkit-text-security:disc;transition:border-color 0.3s;}}
#k:focus{{border-bottom-color:rgba(255,255,255,0.12)}}
#k.e{{border-bottom-color:rgba(180,40,40,0.4);animation:s .4s}}
@keyframes s{{0%,100%{{transform:translateX(0)}} 20%,60%{{transform:translateX(-6px)}} 40%,80%{{transform:translateX(6px)}}}}
</style>
</head>
<body>
<input type=\"password\" id=\"k\" autocomplete=\"off\" spellcheck=\"false\" autofocus>
<script>
const E='{payload}';
function b(s){{return Uint8Array.from(atob(s),c=>c.charCodeAt(0))}}
document.getElementById('k').addEventListener('keydown',async function(e){{
  if(e.key!=='Enter')return;
  const v=e.target.value;if(!v)return;
  try{{
    const p=E.split('.');
    const salt=b(p[0]),iv=b(p[1]),ct=b(p[2]);
    const km=await crypto.subtle.importKey('raw',new TextEncoder().encode(v),'PBKDF2',false,['deriveKey']);
    const key=await crypto.subtle.deriveKey({{name:'PBKDF2',salt:salt,iterations:600000,hash:'SHA-256'}},km,{{name:'AES-GCM',length:256}},false,['decrypt']);
    const d=await crypto.subtle.decrypt({{name:'AES-GCM',iv:iv}},key,ct);
    document.open();document.write(new TextDecoder().decode(d));document.close();
  }}catch(err){{
    e.target.value='';e.target.classList.add('e');
    setTimeout(function(){{e.target.classList.remove('e')}},400);
  }}
}});
</script>
</body></html>'''

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)
"

  # Detect the valid python environment to use.
  if command -v wsl >/dev/null 2>&1 && wsl python3 -c 'import sys; sys.exit(0)' 2>/dev/null; then
      wsl python3 -c "$PY_SCRIPT" || exit 1
  elif python3 -c 'import sys; sys.exit(0)' 2>/dev/null; then
      python3 -c "$PY_SCRIPT" || exit 1
  elif python -c 'import sys; sys.exit(0)' 2>/dev/null; then
      python -c "$PY_SCRIPT" || exit 1
  else
      echo "[Error] Python is required to encrypt the payload. Please install Python or run from inside WSL."
      exit 1
  fi

  # Support running stand-alone vs inside a git hook
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git add index.html
  fi
else
  echo "[Warning] content.html or .env file is missing. Skipping encryption."
fi

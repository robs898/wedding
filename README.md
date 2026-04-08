# Wedding Site

A minimalistic, secure, single-file wedding invitation site using zero-knowledge client-side encryption. The source contents are encrypted locally before they are ever pushed to GitHub.

## Setup Instructions

When you clone this repository, you'll instantly have the blank `index.html`. To start editing the site, you need to configure your local setup:

### 1. Configure the Encryption Key
Create a `.env` file in the root of the repository and add your encryption key:
```env
ENCRYPTION_KEY=reallyreallyreallyreallyreallylongpassword
```
*(Keep this file safe and never commit it to source control!)*

### 2. Configure the Git Hook
To ensure `index.html` is automatically encrypted on every commit, link the `pre-commit` hook to the included `encrypt.sh` script:

**On Mac/Linux/WSL:**
```bash
vim .git/hooks/pre-commit

    #!/bin/bash
    # .git/hooks/pre-commit
    # Calls the version-controlled encrypt.sh script in the repository root

    DIR="$(cd "$(dirname "$0")/../.." && pwd)"

    if [ -f "$DIR/encrypt.sh" ]; then
    bash "$DIR/encrypt.sh"
    else
    echo "[Warning] encrypt.sh missing from repo root. Skipping auto-encryption."
    fi

chmod +x .git/hooks/pre-commit
```

## How It Works

1. **Edit the content:** Make all your text and design changes in `content.html`. 
2. **Commit:** When you `git commit`, the pre-commit hook executes `encrypt.sh`.
3. **Encryption:** `encrypt.sh` generates a secure payload using your key from `.env` and embeds it directly into a fresh `index.html`.
4. **Push:** You safely push the `index.html` to GitHub, keeping your venue, timings, and names exclusively available to guests with the password. 

*Note: The script requires Python to be installed locally (or via WSL).*

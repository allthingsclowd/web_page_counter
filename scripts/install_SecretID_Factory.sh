#!/usr/bin/env bash
set -x

# download binary and template file from latest release
curl -s https://api.github.com/repos/allthingsclowd/VaultServiceIDFactory/releases/latest \
| grep "browser_download_url" \
| cut -d : -f 2,3 \
| tr -d \" | wget -i -

killall VaultServiceIDFactory &>/dev/null
mv VaultServiceIDFactory /usr/local/bin/.
chmod +x /usr/local/bin/VaultServiceIDFactory

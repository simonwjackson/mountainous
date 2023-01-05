#!/bin/sh

set -e

echo "${SSH_PERSONAL_RSA_PRIVATE}" > "${HOME}/.ssh/id_rsa"
echo "${SSH_CLERK_ED25519_PRIVATE}" > "${HOME}/.ssh/id_ed25519"

chmod 600 "${HOME}/.ssh/id_rsa"
chmod 600 "${HOME}/.ssh/id_ed25519"

ssh-keygen -y -f ~/.ssh/id_rsa > "${HOME}/.ssh/authorized_keys"
ssh-keygen -y -f ~/.ssh/id_ed25519 >> "${HOME}/.ssh/authorized_keys"

# TODO: Find a better way to install pip packages
# nix-shell -p python3.pkgs.pip --run 'pip install --user -r requirements.txt'

# Install packer plugins
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

npm install --global \
  @tailwindcss/language-server

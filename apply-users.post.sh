#!/bin/sh

set -e

echo "${SSH_PERSONAL_RSA_PRIVATE}" > "${HOME}/.ssh/id_rsa"
chmod 600 "${HOME}/.ssh/id_rsa"

ssh-keygen -y -f ~/.ssh/id_rsa > "${HOME}/.ssh/authorized_users"


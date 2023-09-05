./clean.sh && \
sudo nix-store --verify --check-contents --repair && \
sudo nix-store --optimise

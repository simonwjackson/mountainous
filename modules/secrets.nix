# Secrets, decrypted before anyone logs in.
#
# The whole point is the first boot of a fresh install. A machine that has just
# been imaged has to reach the tailnet by itself, because until it does there
# is no way to SSH in and fix it. That rules out any scheme where a human
# supplies the key.
#
# So the chain has to close without a person in it:
#
#   ssh-keygen on the workstation          the host key exists before the machine
#     -> its age public key in .sops.yaml  secrets are encrypted to it
#       -> planted by --extra-files        the key is on disk before first boot
#         -> sops-install-secrets          activation decrypts with a key already there
#           -> tailscaled-autoconnect      the machine joins, unattended
#
# Nothing here generates a key on the machine. A machine that generates its own
# identity cannot be sent secrets in advance, which is the deadlock this avoids.
#
# ed25519 only. sops derives the host's age key with ssh-to-age, which prints
# "skipped key: got ssh-rsa key type" and exits 0 for anything else -- a silent
# failure that would leave the machine unable to decrypt with no error to read.
{
  nixos.modules.base =
    {
      config,
      inputs,
      ...
    }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile = ../secrets/fleet.yaml;

        # The host decrypts with the SSH host key it already has, so there is no
        # second key to distribute or rotate. The default includes the RSA path
        # as well; naming only ed25519 means a machine that somehow has just an
        # RSA key fails loudly at activation instead of quietly holding an empty
        # recipient.
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

        # No GnuPG anywhere in this tree. Left empty so sops cannot silently
        # fall back to a PGP path nothing has been set up for.
        gnupg.sshKeyPaths = [ ];

        secrets = {
          # Read by tailscale-claim-name and by tailscaled-autoconnect, both as
          # root, both before multi-user.target. Owner is left as root because
          # nothing else has any business reading a credential that can register
          # and delete devices on the tailnet.
          tailscale-oauth-id.mode = "0400";
          tailscale-oauth-secret.mode = "0400";

          # The login password hash, for users.users.*.hashedPasswordFile.
          #
          # neededForUsers is the whole reason this works. Ordinary secrets are
          # installed during activation, which is after update-users-groups.pl
          # has already written /etc/shadow -- a password arriving then is a
          # password that arrives too late. neededForUsers decrypts into
          # /run/secrets-for-users before users are created.
          #
          # The option forbids setting owner or group: the accounts that would
          # own the file do not exist yet at the point it is written.
          user-password.neededForUsers = true;
        };
      };

      # Fleet-wide on purpose. One OAuth client registers every machine, so this
      # belongs in base rather than in each host. Both files are plain paths
      # under /run/secrets, which is a tmpfs -- the decrypted values never touch
      # a disk.
      mountainous.tailscale.oauthClientIdFile = config.sops.secrets.tailscale-oauth-id.path;
      mountainous.tailscale.oauthSecretFile = config.sops.secrets.tailscale-oauth-secret.path;
    };
}

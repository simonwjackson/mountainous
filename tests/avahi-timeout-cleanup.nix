{
  pkgs,
  avahi,
}:
pkgs.runCommand "avahi-timeout-cleanup" {nativeBuildInputs = [pkgs.stdenv.cc];} ''
  set -euo pipefail
  $CC -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror \
    -I${pkgs.lib.getDev avahi}/include \
    -L${pkgs.lib.getLib avahi}/lib \
    -Wl,-rpath,${pkgs.lib.getLib avahi}/lib \
    ${./avahi-timeout-cleanup.c} -lavahi-common -o regression
  ./regression | tee "$out"
''

{
  lib,
  writeShellApplication,
  yt-dlp,
}:
(writeShellApplication {
  name = "vinyl-vault";
  runtimeInputs = [yt-dlp];
  text = builtins.readFile ./vinyl-vault.sh;
})
// {
  meta = with lib; {
    licenses = licenses.mit;
    platforms = platforms.all;
  };
}

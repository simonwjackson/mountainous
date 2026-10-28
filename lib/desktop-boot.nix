# Both original theme packages. Runtime desktop switches never touch /boot.
{
  pkgs,
  platinumFont,
  win98Font,
}:
pkgs.runCommand "mountainous-boot-themes"
  {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
  }
  ''
    target=$out/share/plymouth/themes
    mkdir -p "$target"
    python3 ${../modules/desktop-boot/generate.py} "$target" ${platinumFont} ${win98Font}
    for theme in platinum win98; do
      name=mountainous-$theme
      cp ${../modules/desktop-boot/theme.script} "$target/$name/$name.script"
      # Keep Win98's existing desktop teal, without shipping Microsoft's logo.
      if [ "$theme" = win98 ]; then
        sed -i 's/0.67, 0.67, 0.67/0, 0.5, 0.5/g' "$target/$name/$name.script"
      fi
      cat > "$target/$name/$name.plymouth" <<THEME
    [Plymouth Theme]
    Name=Mountainous $theme
    Description=Original period-style startup and shutdown
    ModuleName=script

    [script]
    ImageDir=$target/$name
    ScriptFile=$target/$name/$name.script
    THEME
    done
  ''

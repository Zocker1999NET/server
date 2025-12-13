{
  pkgs,
  ...
}:
{
  config = {
    programs.retroarch = {

      cores = with pkgs.libretro; {
        # provide a list of recommended cores per console
        # as recommended by https://emulation.gametechwiki.com
        _1983-NES.package = mesen; # 1983 NES
        _1989-GB.package = sameboy; # 1989 GB
        _1990-SNES.package = bsnes-hd; # 1990 SNES
        _1996-N64.package = mupen64plus; # 1996 N64 (multi, maybe for SNES too; not for NES)
        _1998-GBC.package = sameboy; # 1998 GBC
        _2001-GBA.package = mgba; # 2001 GBA
        _2001-GCN.package = dolphin; # 2001 GCN
        _2004-NDS.package = melonds; # 2004 NDS (+NDSi)
        _2006-Wii.package = dolphin; # 2006 Wii
      };

    };
  };
}

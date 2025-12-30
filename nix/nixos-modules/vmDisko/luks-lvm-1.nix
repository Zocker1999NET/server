{
  disk = {
    main = {
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "500M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              askPassword = true; # ask for password at initialization
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
              settings = {
                crypttabExtraOpts = [
                  # required for TPM unlock to continue to work with another tpm2 option set
                  # (does not require a tpm2 token/slot to exist)
                  "tpm2-device=auto"
                  # allows for PCR 15 validation (not fully implemented by that!)
                  # (and has no disadvantages on systems without)
                  # without PCR 15 validation, TPM & signed initrd can be misused by replacing LUKS partition
                  # see: https://oddlama.org/blog/bypassing-disk-encryption-with-tpm2-unlock/
                  "tpm2-measure-pcr=yes"
                ];
              };
            };
          };
        };
      };
    };
  };
  lvm_vg = {
    pool = {
      type = "lvm_vg";
      lvs = {
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "defaults" ];
          };
        };
      };
    };
  };
}

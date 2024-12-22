abort "WIP vmDisko config mbr-ext4-1" {
  disk = {
    main = {
      type = "disk";
      content = {
        type = "table";
        format = "msdos";
        partitions = [
          {
            name = "root";
            part-type = "primary";
            start = "1M";
            end = "100%";
            bootable = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          }
        ];
      };
    };
  };
}

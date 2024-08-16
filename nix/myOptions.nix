# configures options only really useable for me


{ config
, lib
, pkgs
, ...
}:
let
  myOpts = config.x-banananetwork;
in
{


  config = {


    x-banananetwork = {


      # options defined in nixos-modules/options.nix

      sshPublicKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAEAQDPRH3HSoCpoeqsovMuHOMvFxRFnCTxRIM2mUlAHo+Ef72F7103OeqwgL59rEFOWD8XS3sJhJ/k/dkLvvrANMDWiu5ofaJgA/SAwZzeC4Nh+1r+NWvuwlqvMWvka6Jg0U7l8ZLXD6s9Mmc7+kt4HYnF7xMcuaYBXyCj43eSG+EaiPDMW1Td3MdpzSYI6TvZN+iuhzpWNEemxAouyJvuKFggJM2XhrMHaPufabMIxVjekmMXce4uTeJ6ySaeXrIKEYofkvTC/3dqHQRlTvDGX0Jiy2T2CxX+24EdWlFdxWYBN0mPhimvwfdIynOUsvqn/1JTtj5JnYVG0MCygTUi9xJ2/0Djx+ecbbUXSROtUN+V4MHVUrg/43nkTBPVW5mRHQPpb42MeHw2AXbLJEXASdRivaJ9bpIffvGD11jiMrIKDS0Hh7nek0Y0qoGuT/04O/fZSbJiyRQqrk6FZNWzwO4xfUhD8oKjGeAypjJlOty3Krc4ivE1IzE1I4ELKRTZYt2pJln1nHCd/9ELik54JYm+viitAa/yhU4Rg+Qhhtzq5rw6MonUfhLRgmvt2oq4JQWlqFz/qXEdtx3OOKMNZDbzlbFzDRAgP/Jqt7sx2QvivKI5kGpmlk9NXKaH/ucpTFbOkGFcx/bLOov6YfyrrRbwqHi7ZkUPT2BCo5KWvjr/cM5sRQc6Qs+aXD5Bye1Nd3SWMOj1izXd36RxCBqtfzXi5rkPE59qlB7gJ0Q1I49C1WyKUgd15Aw7CubHLpKZRXu8ko5xJ3JQhe15lIrLqMUUATb45DIrsVb3kueA5v8AMSiJkFhyxAjgvZ9V9+zCp8ElCBsjdqZb5/meu44pM/SBlpcntTFb/5BEFhjxdBEXoV6j0ZvkhcLcfWcR8rRnVpoK0CXzF5/xMCWxxM/OUfQ9xUKs0JdhDBWqhK0UWc1dCi48g9FTYXXApfoN/I52ec/3nHHj22FucIePsViw7+AOJm42DO9RJGQBIqRquasrH5uuJqEAufYFr4jSQCWPvdjBhCJIOGNHiu3jRjuEaIUoqH2fNDth69gUok588JvRypM7no2KpdMHvQdgpvqPU0Nuvm4/xnIhmu6jsamoHDObSLj2fagmzwptd5qw1rlqzwMfYtRX3Oj1NQW4qbE+bDozav4d9Pu243gn71ybmsJ5awGHAW/fW0nL5gsYhh9VNefY7Nst4+/KQZBDHppJZY+Cok9yUcnOVjH3qZFQTvIuljkk6IhCjgP5lfELUg3EIimADSJT9gnzE1jfs95CZTwFUhIXucC3CwYnIlPUPSU2DaS0hfopYeiBMxX4A7xvdUohOcY+cbnPHu8HtKIzYWsVg28gLaA+8YDXMHNoyaaD zocker Backup Key 2018-05-28"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDGKs41V0h0S4cXtodCUwyY7mKk2sMVdTOu2OKm9a1tT24rk2q3khVb+GkS5HetN54qDbylmxBk4egX46jizAsDh1DZnxE2AKTYK2fXrYAFgHZR++Gpjw6pUeFi//gNUh8XHT/5xFlYO5ftysIB4FEBED8Epy3pET1OvXI9/RSppmeQ2yB+cI7gMHDAqrlzdlXkqK1rNFihFtSF4u12b1Bze5tAON+QFDHbkyN+pvj2b2pZ/3FcBb+fvVqZAlM0qEFiRoz7+fYYvZBqFL6OeYvIlas9FcJzycxX9TbVPsfjBlKya0v3MA+LcEOGPTwUnva9og8WQZAuPB0OKkMA46wyw+XwWJvOlIplt6OnYrT8nZ7J+gJGDDGMzCx8jckojoNBPiir0DJFaOhiPsJeW/3LW6yQib8OfgQ6R6RqUmEEKgjcM1tdnZxsrYGtF2q63ZcL4DB24nvGcLAw77Gyi9F0FU4H1uf096NIPM5Rmgvw48ZNkg4+kJ2PsVFO5H+wAmV23/dmIBz12Qltx+l5N9rSwyrIVplVulpd3B2lLm+Av6Jhn65qc5uEBH/0FyBz+HoXI9OBhFRRV+q5LqfTXrjWC8LhljjKHzWo4pPsQJp5TKOsoSLconeQG+ByP/iy1wfmXh+MLTK191Dw4Th2hZUHEMlek7y9SIKm/RY2buPxuQ== 93e1bd26f6b02fb@keys.banananet.work"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ322iTs4HagYWO5C/O8t2smxBOJNW68amar99H7f0kq zocker@zockerpc 2018-07-22"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBdtHoYx74Dp2P/Th72JpY/vnSL8LUDG10HGoU+I162 zocker@thinkie 2019-06-04"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEaWqcgeNh3BjyDXCg0DQfbuPg5VLVYlt8ucYu7VZNr zocker@x13yz 2024-07-04"
      ];

      userName = "zocker";


      # defaults for other modules, derived from them above

      frontend = {
        username = myOpts.userName;
      };


    };


  };


}

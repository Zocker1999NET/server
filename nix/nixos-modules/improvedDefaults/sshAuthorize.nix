{ config
, lib
, pkgs
, ...
}:
let
  myOpts = config.x-banananetwork;
  cfg = config.x-banananetwork.improvedDefaults;
in
{


  options = {

    x-banananetwork.improvedDefaults = {

      autoSshAuthorizeRoot = lib.mkEnableOption ''
        automatically add option{x-banananetwork.sshPublicKeys} to root’s authorized keys
        and enable option{services.openssh.settings.PermitRootLogin}
        if no other user has "wheel" power & SSH authorized keys defined.

        Also, option{services.openssh.settings.PermitRootLogin} will be disabled
        if this module does not require it.
      '' // { default = true; };

    };

  };


  config = lib.mkIf
    (lib.lists.all (x: x) [
      cfg.enable
      cfg.autoSshAuthorizeRoot
      config.services.openssh.enable
    ]
    )
    (
      let
        inherit (lib.attrsets) attrValues filterAttrs;
        inherit (lib.lists) any;
        # variables
        users = config.users.users;
        wheelUsers = lib.trivial.pipe users [
          (filterAttrs (n: v: n != "root"))
          (filterAttrs (n: v: builtins.elem "wheel" v.extraGroups))
        ];
        areKeysSet = authKeysOpts: any (x: true) (authKeysOpts.keys ++ authKeysOpts.keyFiles);
        isUserAuthed = userOpts: areKeysSet userOpts.openssh.authorizedKeys;
        # used facts
        isNonRootAuthed = any isUserAuthed (attrValues wheelUsers);
        isRootAuthed = isUserAuthed users."root";
        doRootAuth = !isNonRootAuthed;
      in
      {

        services.openssh.settings.PermitRootLogin = if isRootAuthed then true else lib.mkDefault false;

        users.users.root.openssh.authorizedKeys = lib.mkIf doRootAuth (lib.mkDefault myOpts.sshPublicKeys);
        warnings = lib.mkIf doRootAuth [
          ''
            root’s authorized keys were automatically configured
            because no other user with wheel permission has authorized keys configured
          ''
        ];

      }
    );


}

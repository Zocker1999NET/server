{
  # _class = "homeManager.vscodeProfile";
  userSettings."chat.tools.edits.autoApprove" = {

    # default set configured by VSCode
    "**/*" = true;
    "**/.vscode/*.json" = false;
    "**/.git/**" = false;
    "**/{package.json,server.xml,build.rs,web.config,.gitattributes,.env,Cargo.toml}" = false;
    "**/*.{code-workspace,csproj,fsproj,vbproj,vcxproj,proj,targets,props,gradle,gradle.kts}" = false;
    "**/gradle.properties" = false;
    "**/ruby_lsp/*/addon" = false;
    "**/*.lock" = false;
    "**/*-lock.{yaml,json}" = false;

    # my definitions, sorted alphabetically

    "**/flake.{nix,lock}" = false;

  };
}

# settings configuring handling of files
# grouped because they often refer to the same directories & files
{
  # _class = "homeManager.vscodeProfile";
  userSettings = {
    # cSpell:disable

    "files.associations" = {
      "*.makefile" = "makefile";
    };

    "files.exclude" = {
      "**/.classpath" = true;
      "**/.factorypath" = true;
      "**/.mypy_cache" = true;
      "**/.project" = true;
      "**/.pytest_cache" = true;
      "**/.settings" = true;
      "**/__pycache__" = true;
      "**/venv" = true;
    };

    "files.watcherExclude" = {
      "**/venv" = true;
    };

    # cSpell:enable
  };
}

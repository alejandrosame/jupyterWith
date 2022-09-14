{
  self,
  pkgs,
  # https://github.com/nix-community/poetry2nix#mkPoetryEnv
  projectDir ? self + "/kernels/available/postgres",
  pyproject ? projectDir + "/pyproject.toml",
  poetrylock ? projectDir + "/poetry.lock",
  overrides ? pkgs.poetry2nix.overrides.withDefaults (import ./overrides.nix),
  python ? pkgs.python3,
  editablePackageSources ? {},
  extraPackages ? ps: [],
  preferWheels ? false,
}: let
  env = pkgs.poetry2nix.mkPoetryEnv {
    inherit
      projectDir
      pyproject
      poetrylock
      overrides
      python
      editablePackageSources
      extraPackages
      preferWheels
      ;
  };
in
  {
    name ? "postgres",
    displayName ? "PostgreSQL", # TODO: add Ansible version
    language ? "postgres",
    argv ? null,
    codemirrorMode ? "pgsql",
    logo64 ? ./logo64.png,
    runtimePackages ? with pkgs; [postgresql],
    extraRuntimePackages ? [],
  }: let
    allRuntimePackages = runtimePackages ++ extraRuntimePackages;

    wrappedEnv =
      pkgs.runCommand "wrapper-${env.name}"
      {nativeBuildInputs = [pkgs.makeWrapper];}
      ''
        mkdir -p $out/bin
        for i in ${env}/bin/*; do
          filename=$(basename $i)
          ln -s ${env}/bin/$filename $out/bin/$filename
          wrapProgram $out/bin/$filename \
            --set PATH "${pkgs.lib.makeSearchPath "bin" allRuntimePackages}"
        done
      '';

    argv_ =
      if argv == null
      then [
        "${wrappedEnv}/bin/python"
        "-m"
        "postgres_kernel"
        "-f"
        "{connection_file}"
      ]
      else argv;
  in {
    argv = argv_;
    inherit
      name
      displayName
      language
      codemirrorMode
      logo64
      ;
  }
let
  nixpkgs = builtins.fetchTarball {
    # commit from September 28 2021, branch: master
    url =
      "https://github.com/NixOS/nixpkgs/archive/8b725cf8980fd3c54a978432ea32121bc34eb61d.tar.gz";
    sha256 = "0sz1yalfv1if8qm719dw8fyw4f8s6i4ks828q33xdja5b43ialsw";
  };
  pkgs = import nixpkgs { config.allowUnfree = true; };
  ghc = "ghc8107";
in with pkgs;
let
  ghcCompiler = haskell.compiler.${ghc};
  ghcHaskellPkgs = haskell.packages.${ghc};
  exe = haskell.lib.justStaticExecutables;

  mkPackage = self: pkg: path: inShell:
    let orig = self.callCabal2nix pkg path { };
    in if inShell
    # Avoid copying the source directory to nix store by using
    # src = null.
    then
      orig.overrideAttrs (oldAttrs: { src = null; })
    else
      orig;

  streamingBenchmarkPkgs = inShell:
    ghcHaskellPkgs.override {
      overrides = self: super: {
        conduit = self.callHackageDirect {
          pkg = "conduit";
          ver = "1.3.4.2";
          sha256 = "0mknjn13kb98ihzv4w9za8aq1fi76wnp4lbp1il66al0i9brn09p";
        } { };
        streamly = self.callHackageDirect {
          pkg = "streamly";
          ver = "0.8.0";
          sha256 = "0vy2lkljizlhpbpbybmg9jcmj2g4s1aaqd2dzy5c0y0n4rgwxask";
        } { };
        streaming-benchmark = mkPackage self "streaming-benchmark" ./streaming-benchmark.cabal inShell;
      };
    };


  workOnPkgs =
    p: [
      p.streaming-benchmark
    ];

  shell = (streamingBenchmarkPkgs true).shellFor {
    withHoogle = true;
    packages = workOnPkgs;
    passthru.pkgs = pkgs;
    src = null; # pkgs.nix-gitignore.gitignoreSource [] ./.;
    nativeBuildInputs = with ghcHaskellPkgs; [
      (exe cabal-install)
      hpack
      haskell-language-server
      ghcid
      pkgs.gnuplot

      pkgs.dhall
      pkgs.dhall-json
      pkgs.dhall-lsp-server

      pkgs.autoconf
      pkgs.automake
      pkgs.m4
    ];
    buildInputs = [ pkgs.zlib ];
  };
in {
  # Pass the kronor* program to be built, defaults to `kronor`
  # We don't need profiled builds when we want to build the project
  streaming-benchmark =
    haskell.lib.dontCheck (haskell.lib.disableLibraryProfiling (exe (streamingBenchmarkPkgs false).streaming-benchmark));
  shell = shell;
}

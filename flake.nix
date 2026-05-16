{
  description = "modem73 — KISS TNC for the aicodix MFSK modem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    aicodix-dsp = {
      url = "github:aicodix/dsp";
      flake = false;
    };
    aicodix-code = {
      url = "github:aicodix/code";
      flake = false;
    };
    aicodix-modem = {
      url = "github:aicodix/modem";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, aicodix-dsp, aicodix-code, aicodix-modem }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;

        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./Makefile
            ./kiss_tnc.cc
            (lib.fileset.fileFilter (f: f.hasExt "hh") ./.)
            ./phy
            ./deps
            ./misc/50-cm108-ptt.rules
          ];
        };

        modem73 = pkgs.stdenv.mkDerivation {
          pname = "modem73";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];

          buildInputs = with pkgs; [
            ncurses
            hidapi
            alsa-lib
            libpulseaudio
          ];

          makeFlags = [
            "AICODIX_DSP=${aicodix-dsp}"
            "AICODIX_CODE=${aicodix-code}"
            "MODEM_SRC=${aicodix-modem}"
          ];

          enableParallelBuilding = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 modem73 $out/bin/modem73
            install -Dm644 misc/50-cm108-ptt.rules \
              $out/lib/udev/rules.d/50-cm108-ptt.rules
            runHook postInstall
          '';

          postFixup = ''
            wrapProgram $out/bin/modem73 \
              --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.alsa-lib pkgs.libpulseaudio ]}"
          '';

          meta = with pkgs.lib; {
            description = "KISS TNC built around the aicodix MFSK modem";
            homepage = "https://github.com/RFnexus/modem73";
            license = licenses.gpl3Plus;
            platforms = platforms.linux;
            mainProgram = "modem73";
          };
        };
      in {
        packages = {
          default = modem73;
          modem73 = modem73;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ modem73 ];

          packages = with pkgs; [
            gdb
            clang-tools
            hamlib
          ];

          shellHook = ''
            export AICODIX_DSP=${aicodix-dsp}
            export AICODIX_CODE=${aicodix-code}
            export MODEM_SRC=${aicodix-modem}
            echo "modem73 dev shell"
            echo "  AICODIX_DSP=$AICODIX_DSP"
            echo "  AICODIX_CODE=$AICODIX_CODE"
            echo "  MODEM_SRC=$MODEM_SRC"
            echo "Build with: make -j\$(nproc)"
          '';
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}

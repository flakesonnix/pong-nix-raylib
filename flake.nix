{
  description = "2D Pong in Nix, powered by nixray (no audio)";

  inputs = {
    nixray.url = "github:flakesonnix/nixray";
    nixpkgs.follows = "nixray/nixpkgs";
  };

  outputs = { self, nixray, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      forSystem = system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtime = nixray.packages.${system}.default;
          pong = pkgs.writeShellApplication {
            name = "pong";
            text = ''
              exec ${runtime}/bin/nixray ${self}/pong.nix --arg ray 'import ${nixray}/lib' "$@"
            '';
            meta.description = "Play Pong against the CPU or a second local player";
          };
        in { inherit pkgs runtime pong; };
    in {
      packages = eachSystem (system: {
        default = (forSystem system).pong;
        pong = (forSystem system).pong;
      });
      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.pong}/bin/pong";
          meta.description = "Play 2D Pong (without audio)";
        };
      });
      checks = eachSystem (system:
        let inherit (forSystem system) pkgs runtime pong;
        in {
          game = pkgs.runCommand "pong-tests" {
            nativeBuildInputs = [ pkgs.python3 pkgs.xvfb-run ];
          } ''
            export HOME="$TMPDIR/home"
            export XDG_RUNTIME_DIR="$TMPDIR/runtime"
            mkdir -p "$HOME"
            mkdir -m 700 -p "$XDG_RUNTIME_DIR"
            export LIBGL_ALWAYS_SOFTWARE=1
            export GALLIUM_DRIVER=llvmpipe
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.mesa ]}
            export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
            export __GLX_VENDOR_LIBRARY_NAME=mesa
            export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
            export XDG_SESSION_TYPE=x11
            unset WAYLAND_DISPLAY
            xvfb-run -a -s '-screen 0 1280x800x24 -noreset' \
              python3 ${./tests/run.py} --source ${self} \
                --nixray ${runtime}/bin/nixray --pong ${pong}/bin/pong --ray ${nixray}/lib
            touch "$out"
          '';
        });
      devShells = eachSystem (system:
        let inherit (forSystem system) pkgs runtime;
        in {
          default = pkgs.mkShell {
            packages = [ runtime pkgs.python3 pkgs.xvfb-run ];
          };
        });
    };
}

{
  description = "Utility to simplify running commands asynchronously using the ts(1) task spooler";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: {
    overlays.default = final: prev: {
      asynq = with final; stdenv.mkDerivation {
        pname = "asynq";
        version = "1.0.0";
        src = self;
        buildInputs = [ ts ];
        installPhase =
          ''
            install -D asynq.sh -m 0555 "$out/bin/asynq.sh"
          '';
      };
    };
  } //
  flake-utils.lib.eachDefaultSystem (system: {
    packages = {
      default = (import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      }).asynq;
    };
  });
}

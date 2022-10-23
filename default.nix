{ stdenv, ... }:

stdenv.mkDerivation rec {
  name = "asynq";
  version = "1.0.0";
  src = ./asynq.sh;
  phases = "installPhase";
  buildInputs = [ ts ];
  installPhase = ''
    mkdir -p $out/bin
    cp ${src} $out/bin/asynq.sh
    chmod +x $out/bin/asynq.sh
  '';
}

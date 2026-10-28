{ ray ? import ../nixray/lib, hidden ? false, maxFrames ? 0 }:
let app = import ./app.nix { inherit ray; };
in ray.run (app.config // { inherit hidden maxFrames; }) app.frame

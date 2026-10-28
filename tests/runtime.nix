{ ray }:
let
  game = import ../game.nix;
  app = import ../app.nix { inherit ray; };
in ray.run (app.config // { hidden = true; maxFrames = 10; fps = 0; }) (frame:
  app.frame (frame // {
    delta = 1.0 / 120;
    keysDown = if frame.frame == 2 then [ ray.keys.w ] else [];
    keysPressed = if builtins.elem frame.frame [ 1 5 9 ] then [ ray.keys.space ]
      else if frame.frame == 3 then [ 80 ] else if frame.frame == 8 then [ 258 ] else [];
    state = if frame.frame == 6 then (game.initial {}) // { phase = "point"; serveTimer = 0.5; rightScore = 2; }
      else if frame.frame == 7 then (game.initial {}) // { phase = "finished"; leftScore = 7; winner = "left"; }
      else frame.state;
  })
)

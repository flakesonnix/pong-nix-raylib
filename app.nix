{ ray }:
let
  game = import ./game.nix;
  render = import ./render.nix { inherit ray; };
in {
  config = {
    inherit (game.rules) width height;
    title = "Pong / nixray";
    fps = 120;
    state = game.initial {};
  };
  frame = frame:
    let
      down = ray.keyDown frame;
      pressed = ray.keyPressed frame;
      axis = up: downKey: (if down downKey then 1 else 0) - (if down up then 1 else 0);
      left = if frame.state.mode == "solo" then
        (if down ray.keys.s || down ray.keys.down then 1 else 0)
        - (if down ray.keys.w || down ray.keys.up then 1 else 0)
        else axis ray.keys.w ray.keys.s;
      state = game.step frame.state {
        delta = frame.delta;
        inherit left;
        right = axis ray.keys.up ray.keys.down;
        start = pressed ray.keys.space || pressed ray.keys.enter;
        pause = pressed 80; # P
        restart = pressed 82; # R
        toggleMode = pressed 258; # Tab
      };
    in {
      inherit state;
      commands = render frame state;
    };
}

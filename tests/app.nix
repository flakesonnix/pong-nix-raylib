{ ray }:
let
  game = import ../game.nix;
  app = import ../app.nix { inherit ray; };
  render = import ../render.nix { inherit ray; };
  initial = game.initial {};
  mockFrame = {
    state = initial;
    delta = 0.02;
    keysDown = [];
    keysPressed = [];
    measureText = { text, size }: { width = builtins.stringLength text * size * 0.6; height = size; };
  };
  update = attrs: (app.frame (mockFrame // attrs)).state;
  texts = state: map (command: command.text)
    (builtins.filter (command: command.op == "text") (render mockFrame state));
  playing = update { keysPressed = [ ray.keys.space ]; };
  paused = playing // { phase = "paused"; };
  versus = game.initial { mode = "versus"; };
  phases = [ "ready" "playing" "paused" "point" "finished" ];
  # Validate every status in both modes, including full trails and a two-digit rally.
  drawings = builtins.concatMap (mode:
    map (phase: ray.validate (render mockFrame ((game.initial { inherit mode; }) // {
      inherit phase;
      leftScore = 7; rightScore = 6; winner = "left"; rally = 99;
      trail = builtins.genList (i: { x = 400.0 + i * 4.5; y = 300.0; }) 8;
    }))) phases
  ) [ "solo" "versus" ];
  checks = {
    drawsAllStatuses = builtins.all (count: count > 40) drawings;
    drawsRightWinner = ray.validate (render mockFrame (initial // { phase = "finished"; winner = "right"; rightScore = 7; })) > 40;
    englishReadyText = builtins.elem "READY?" (texts initial) && builtins.elem "SPACE  START" (texts initial);
    soloWinnerGrammar = builtins.elem "YOU WIN!" (texts (initial // { phase = "finished"; winner = "left"; }));
    cpuWinnerText = builtins.elem "CPU WINS!" (texts (initial // { phase = "finished"; winner = "right"; }));
    versusWinnerText = builtins.elem "PLAYER 2 WINS!" (texts (versus // { phase = "finished"; winner = "right"; }));
    englishPointText = builtins.elem "Next serve ..." (texts (initial // { phase = "point"; }));
    spaceStarts = playing.phase == "playing";
    enterStarts = (update { keysPressed = [ ray.keys.enter ]; }).phase == "playing";
    heldSpaceDoesNotStart = (update { keysDown = [ ray.keys.space ]; }).phase == "ready";
    wMovesLeft = (update { keysDown = [ ray.keys.w ]; }).leftY < initial.leftY;
    sMovesLeft = (update { keysDown = [ ray.keys.s ]; }).leftY > initial.leftY;
    arrowsMoveLeftInSolo = (update { keysDown = [ ray.keys.up ]; }).leftY < initial.leftY;
    sameDirectionKeysDoNotDoubleSpeed = update { keysDown = [ ray.keys.up ray.keys.w ]; } == update { keysDown = [ ray.keys.w ]; };
    oppositeKeysCancel = (update { keysDown = [ ray.keys.up ray.keys.s ]; }).leftY == initial.leftY;
    versusArrowsOnlyMoveRight = let s = update { state = versus; keysDown = [ ray.keys.down ]; };
      in s.leftY == versus.leftY && s.rightY > versus.rightY;
    versusWOnlyMovesLeft = let s = update { state = versus; keysDown = [ ray.keys.w ]; };
      in s.leftY < versus.leftY && s.rightY == versus.rightY;
    pPauses = (update { state = playing; keysPressed = [ 80 ]; }).phase == "paused";
    pResumes = (update { state = paused; keysPressed = [ 80 ]; }).phase == "playing";
    rRestarts = update { state = playing; keysPressed = [ 82 ]; } == initial;
    tabSwitchesMode = update { keysPressed = [ 258 ]; } == versus;
    callbackDraws = ray.validate (app.frame mockFrame).commands > 40;
  };
  failed = builtins.filter (name: !checks.${name}) (builtins.attrNames checks);
in
  if failed != [] then throw "Pong app tests failed: ${builtins.concatStringsSep ", " failed}"
  else { passed = builtins.length (builtins.attrNames checks); }

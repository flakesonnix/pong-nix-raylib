{ ray }:
let
  game = import ./game.nix;
  inherit (game) rules;
  colors = {
    background = [ 10 14 24 255 ];
    court = [ 16 23 37 255 ];
    border = [ 42 56 76 255 ];
    muted = [ 134 152 176 255 ];
    white = [ 236 244 255 255 ];
    cyan = [ 91 228 235 255 ];
    pink = [ 255 127 166 255 ];
  };
  rect = x: y: width: height: color: ray.rectangle {
    x = builtins.floor x; y = builtins.floor y;
    inherit width height color;
  };
  label = text: x: y: size: color: ray.text { inherit text x y size color; };
in frame: state:
let
  centered = text: center: y: size: color:
    label text (builtins.floor (center - (frame.measureText { inherit text size; }).width / 2.0)) y size color;
  solo = state.mode == "solo";
  rightName = if solo then "CPU" else "PLAYER 2";
  leftName = if solo then "YOU" else "PLAYER 1";
  winnerName = if state.winner == "left" then leftName else rightName;
  overlay = builtins.elem state.phase [ "ready" "paused" "finished" ];
  heading = if state.phase == "ready" then "READY?"
    else if state.phase == "paused" then "PAUSED"
    else if solo && state.winner == "left" then "YOU WIN!" else "${winnerName} WINS!";
  subtitle = if state.phase == "ready" then "First to 7 points wins."
    else if state.phase == "paused" then "Take a breather."
    else "${toString state.leftScore} : ${toString state.rightScore}  /  Well played.";
  action = if state.phase == "paused" then "SPACE / P  RESUME"
    else if state.phase == "finished" then "SPACE  PLAY AGAIN" else "SPACE  START";
  paddle = x: y: color: glow: [
    (rect (x - 5) (y - 4) (rules.paddleWidth + 10) (rules.paddleHeight + 8) glow)
    (ray.rectangleRounded {
      inherit x color;
      y = builtins.floor y;
      width = rules.paddleWidth; height = rules.paddleHeight; roundness = 0.5;
    })
  ];
  trailCount = builtins.length state.trail;
in [
  (ray.clear colors.background)
  (label "PONG" 40 25 32 colors.white)
  (label "NIX + RAYLIB" 42 63 12 colors.muted)
  (label (if solo then "01 / CPU MATCH" else "02 / LOCAL DUEL") 724 33 16 colors.cyan)
  (label "FIRST TO 7 POINTS" 724 58 12 colors.muted)
  (centered leftName 380 24 14 colors.cyan)
  (centered rightName 580 24 14 colors.pink)
  (centered (toString state.leftScore) 380 49 64 colors.white)
  (centered (toString state.rightScore) 580 49 64 colors.white)
  (centered ":" 480 59 36 colors.border)
  (rect rules.left rules.top (rules.right - rules.left) (rules.bottom - rules.top) colors.court)
  (rect rules.left rules.top (rules.right - rules.left) 2 colors.border)
  (rect rules.left (rules.bottom - 2) (rules.right - rules.left) 2 colors.border)
  (ray.circleLines { x = 480; y = 348; radius = 56; color = [ 42 56 76 110 ]; })
] ++ builtins.genList (i:
  rect 479 (152 + i * 24) 2 10 colors.border
) 17
++ paddle rules.leftX state.leftY colors.cyan [ 91 228 235 20 ]
++ paddle rules.rightX state.rightY colors.pink [ 255 127 166 20 ]
++ builtins.genList (i:
  let point = builtins.elemAt state.trail (trailCount - i - 1);
  in ray.circle {
    x = builtins.floor point.x; y = builtins.floor point.y;
    radius = 3.0 + i * 0.5; color = [ 236 244 255 (12 + i * 9) ];
  }
) trailCount
++ [
  (ray.circle { x = builtins.floor state.ball.x; y = builtins.floor state.ball.y; radius = 14; color = [ 236 244 255 15 ]; })
  (ray.circle { x = builtins.floor state.ball.x; y = builtins.floor state.ball.y; radius = rules.radius; color = colors.white; })
  (label (if solo then "W / S  OR  UP / DOWN" else "W / S  PLAYER 1") 40 572 16 colors.cyan)
  (label (if solo then "CPU  /  RIGHT" else "UP / DOWN  PLAYER 2") 680 572 16 colors.pink)
  (label "P / SPACE  PAUSE    R  RESTART    TAB  GAME MODE    ESC  QUIT" 40 610 14 colors.muted)
  (centered "RALLY ${toString state.rally}" 480 578 12 colors.muted)
]
++ (if state.phase == "point" then [
  (centered "POINT!" 480 218 26 colors.white)
  (centered "Next serve ..." 480 250 14 colors.muted)
] else [])
++ (if overlay then [
  (rect 40 146 880 404 [ 10 14 24 175 ])
  (ray.rectangleRounded { x = 240; y = 260; width = 480; height = 176; roundness = 0.12; color = colors.background; })
  (rect 448 260 64 3 colors.cyan)
  (centered heading 480 286 30 colors.white)
  (centered subtitle 480 335 18 colors.muted)
  (centered action 480 387 18 colors.cyan)
] else [])

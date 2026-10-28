let
  game = import ../game.nix;
  inherit (game) rules step;
  initial = game.initial {};
  versus = game.initial { mode = "versus"; };
  playing = step initial { start = true; };
  near = a: b: let d = a - b; in d > -0.00001 && d < 0.00001;
  tick = state: step state { delta = 1.0 / 120; };
  repeat = n: f: state: builtins.foldl' (s: _: builtins.deepSeq s (f s)) state (builtins.genList (i: i) n);
  withBall = attrs: playing // { ball = playing.ball // attrs; };
  leftHit = tick (withBall { x = 87.0; vx = -360.0; vy = 0.0; });
  rightHit = tick (withBall { x = 873.0; vx = 360.0; vy = 0.0; });
  leftPoint = tick (withBall { x = 929.0; vx = 360.0; });
  rightPoint = tick (withBall { x = 31.0; vx = -360.0; });
  win = tick ((withBall { x = 929.0; vx = 360.0; }) // { leftScore = 6; });
  paused = step playing { pause = true; delta = 0.03; };
  topBounce = tick (withBall { x = 480.0; y = 153.0; vy = -400.0; });
  bottomBounce = tick (withBall { x = 480.0; y = 543.0; vy = 400.0; });
  simulation = repeat 1800 tick playing;
  checks = {
    startsReady = initial.phase == "ready" && initial.mode == "solo";
    startsCentered = initial.ball.x == 480 && initial.ball.y == 348;
    startsScoreless = initial.leftScore == 0 && initial.rightScore == 0 && initial.winner == null;
    startsStationary = initial.ball.vx == 0 && initial.ball.vy == 0;
    idleDoesNotServe = (step initial { delta = 0.02; }).phase == "ready";
    spaceServes = playing.phase == "playing" && playing.ball.vx > 0;
    zeroDeltaDoesNotMove = step playing {} == playing;
    negativeDeltaDoesNotMove = step playing { delta = -10; } == playing;
    movementUsesTime = near (tick playing).ball.x (playing.ball.x + playing.ball.vx / 120.0);
    clampsLongFrames = step playing { delta = 10; } == step playing { delta = rules.maxDelta; };
    leftMovesUp = (step initial { delta = 0.02; left = -1; }).leftY < initial.leftY;
    leftMovesDown = (step initial { delta = 0.02; left = 1; }).leftY > initial.leftY;
    rightMovesInVersus = (step versus { delta = 0.02; right = -1; }).rightY < versus.rightY;
    clampsInput = step versus { delta = 0.02; left = 99; right = -99; }
      == step versus { delta = 0.02; left = 1; right = -1; };
    clampsPaddleAtTop = (step (initial // { leftY = rules.top + 1; }) { delta = 0.05; left = -1; }).leftY == rules.top;
    clampsPaddleAtBottom = (step (versus // { rightY = rules.bottom - rules.paddleHeight - 1; })
      { delta = 0.05; right = 1; }).rightY == rules.bottom - rules.paddleHeight;
    cpuFollowsIncomingBall = (tick (withBall { y = 450.0; })).rightY > playing.rightY;
    cpuIgnoresHumanRightInput = step playing { delta = 0.02; right = -1; } == step playing { delta = 0.02; right = 1; };
    cpuSpeedLimited = near (step (withBall { y = 450.0; }) { delta = 0.05; }).rightY (playing.rightY + rules.cpuSpeed * 0.05);
    cpuRecentersForOutgoingBall = (tick ((withBall { vx = -360.0; }) // { rightY = 400.0; })).rightY < 400;
    topReflects = topBounce.ball.vy > 0 && topBounce.ball.y >= rules.top + rules.radius;
    bottomReflects = bottomBounce.ball.vy < 0 && bottomBounce.ball.y <= rules.bottom - rules.radius;
    wallKeepsHorizontalSpeed = topBounce.ball.vx == playing.ball.vx;
    leftReflects = leftHit.ball.vx > 0 && leftHit.rally == 1;
    rightReflects = rightHit.ball.vx < 0 && rightHit.rally == 1;
    hitSpeedsUpBall = leftHit.ball.vx > 360;
    hitHasVerticalMovement = leftHit.ball.vy != 0;
    speedIsCapped = (tick (withBall { x = 87.0; vx = -760.0; })).ball.vx == 760;
    upperHitDeflectsUp = (tick (withBall { x = 87.0; y = initial.leftY + 8; vx = -360.0; vy = 0.0; })).ball.vy < 0;
    lowerHitDeflectsDown = (tick (withBall { x = 87.0; y = initial.leftY + 80; vx = -360.0; vy = 0.0; })).ball.vy > 0;
    doesNotHitWhileMovingAway = (tick (withBall { x = 87.0; vx = 360.0; })).rally == 0;
    missesAbovePaddle = (tick (withBall { x = 87.0; y = 180.0; vx = -360.0; })).ball.vx < 0;
    fastestBallCannotTunnelLeft = (step (withBall { x = 120.0; vx = -760.0; vy = 0.0; }) { delta = 0.05; }).ball.vx > 0;
    fastestBallCannotTunnelRight = (step (withBall { x = 840.0; vx = 760.0; vy = 0.0; }) { delta = 0.05; }).ball.vx < 0;
    leftGoalAwardsRight = rightPoint.rightScore == 1 && rightPoint.leftScore == 0;
    rightGoalAwardsLeft = leftPoint.leftScore == 1 && leftPoint.rightScore == 0;
    pointCentersBall = leftPoint.ball == initial.ball && leftPoint.trail == [];
    pointWaits = leftPoint.phase == "point" && (tick leftPoint).phase == "point";
    pointScoresOnlyOnce = (step (withBall { x = 929.0; vx = 760.0; }) { delta = 0.05; }).leftScore == 1;
    serveTargetsConcedingPlayer = (step rightPoint { start = true; }).ball.vx < 0;
    serveAlternatesVerticalDirection = (step leftPoint { start = true; }).ball.vy < 0;
    automaticallyServes = (step (leftPoint // { serveTimer = 0.005; }) { delta = 0.01; }).phase == "playing";
    spaceSkipsPointDelay = (step leftPoint { start = true; }).phase == "playing";
    winsAtSeven = win.phase == "finished" && win.leftScore == 7 && win.winner == "left";
    rightCanWin = (tick ((withBall { x = 31.0; vx = -360.0; }) // { rightScore = 6; })).winner == "right";
    finishedIsStable = step win { delta = 0.05; left = 1; } == win;
    canReplay = let s = step win { start = true; }; in s.phase == "playing" && s.leftScore == 0 && s.winner == null;
    pauseDoesNotAdvance = paused.ball == playing.ball && paused.phase == "paused";
    pauseFreezesEverything = step paused { delta = 0.05; left = 1; right = -1; } == paused;
    pResumes = (step paused { pause = true; }).phase == "playing";
    spacePauses = (step playing { start = true; }).phase == "paused";
    spaceResumes = (step paused { start = true; }).phase == "playing";
    restartClearsMatch = step win { restart = true; } == initial;
    restartPreservesMode = step (versus // { leftScore = 3; }) { restart = true; } == versus;
    tabEntersVersus = step win { toggleMode = true; } == versus;
    tabReturnsToSolo = step versus { toggleMode = true; } == initial;
    trailIsBounded = builtins.length simulation.trail <= 8;
    simulationPaddlesStayInBounds = simulation.leftY >= rules.top && simulation.leftY <= rules.bottom - rules.paddleHeight
      && simulation.rightY >= rules.top && simulation.rightY <= rules.bottom - rules.paddleHeight;
    simulationScoresStayInBounds = simulation.leftScore <= rules.winningScore && simulation.rightScore <= rules.winningScore;
    simulationBallStaysInVerticalBounds = simulation.ball.y >= rules.top + rules.radius && simulation.ball.y <= rules.bottom - rules.radius;
  };
  failed = builtins.filter (name: !checks.${name}) (builtins.attrNames checks);
in
  if failed != [] then throw "Pong tests failed: ${builtins.concatStringsSep ", " failed}"
  else { passed = builtins.length (builtins.attrNames checks); tests = builtins.attrNames checks; }

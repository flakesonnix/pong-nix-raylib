let
  min = a: b: if a < b then a else b;
  max = a: b: if a > b then a else b;
  abs = n: if n < 0 then -n else n;
  clamp = lo: hi: n: max lo (min hi n);
  take = n: xs: builtins.genList (i: builtins.elemAt xs i) (min n (builtins.length xs));

  rules = {
    width = 960;
    height = 640;
    left = 40;
    right = 920;
    top = 144;
    bottom = 552;
    leftX = 64;
    rightX = 882;
    paddleWidth = 14;
    paddleHeight = 88;
    paddleSpeed = 440;
    cpuSpeed = 320;
    radius = 8;
    winningScore = 7;
    serveDelay = 0.85;
    maxDelta = 0.05;
  };
  centerY = (rules.top + rules.bottom) / 2.0;
  centerBall = { x = rules.width / 2.0; y = centerY; vx = 0.0; vy = 0.0; };

  initial = { mode ? "solo" }: {
    inherit mode;
    phase = "ready";
    leftY = centerY - rules.paddleHeight / 2.0;
    rightY = centerY - rules.paddleHeight / 2.0;
    leftScore = 0;
    rightScore = 0;
    winner = null;
    serveDirection = 1;
    serveTimer = 0.0;
    rally = 0;
    ball = centerBall;
    trail = [];
  };

  serve = state: state // {
    phase = "playing";
    serveTimer = 0.0;
    rally = 0;
    trail = [];
    ball = centerBall // {
      vx = state.serveDirection * 360.0;
      vy = if builtins.bitAnd (state.leftScore + state.rightScore) 1 == 0 then 132.0 else -132.0;
    };
  };

  movePaddles = state: input: dt:
    let
      target = if state.phase == "playing" && state.ball.vx > 0 then state.ball.y else centerY;
      distance = target - (state.rightY + rules.paddleHeight / 2.0);
      cpuMovement = if abs distance < 12 then 0 else if distance > 0 then 1 else -1;
      rightMovement = if state.mode == "solo" then cpuMovement else input.right;
      rightSpeed = if state.mode == "solo" then rules.cpuSpeed else rules.paddleSpeed;
      limit = clamp rules.top (rules.bottom - rules.paddleHeight);
    in state // {
      leftY = limit (state.leftY + input.left * rules.paddleSpeed * dt);
      rightY = limit (state.rightY + rightMovement * rightSpeed * dt);
    };

  score = state: side:
    let
      leftScore = state.leftScore + (if side == "left" then 1 else 0);
      rightScore = state.rightScore + (if side == "right" then 1 else 0);
      won = max leftScore rightScore >= rules.winningScore;
    in state // {
      inherit leftScore rightScore;
      phase = if won then "finished" else "point";
      winner = if won then side else null;
      serveDirection = if side == "left" then 1 else -1;
      serveTimer = rules.serveDelay;
      ball = centerBall;
      trail = [];
    };

  advance = state: input: dt:
    let
      moved = movePaddles state input dt;
      b = state.ball;
      x = b.x + b.vx * dt;
      rawY = b.y + b.vy * dt;
      ceiling = rules.top + rules.radius;
      floor = rules.bottom - rules.radius;
      y = if rawY < ceiling then 2 * ceiling - rawY
        else if rawY > floor then 2 * floor - rawY else rawY;
      vy = if rawY < ceiling then abs b.vy else if rawY > floor then -(abs b.vy) else b.vy;
      overlaps = paddleY: y + rules.radius >= paddleY && y - rules.radius <= paddleY + rules.paddleHeight;
      hitLeft = b.vx < 0 && x - rules.radius <= rules.leftX + rules.paddleWidth
        && x + rules.radius >= rules.leftX && overlaps moved.leftY;
      hitRight = b.vx > 0 && x + rules.radius >= rules.rightX
        && x - rules.radius <= rules.rightX + rules.paddleWidth && overlaps moved.rightY;
      hit = hitLeft || hitRight;
      paddleY = if hitLeft then moved.leftY else moved.rightY;
      offset = clamp (-1.0) 1.0 ((y - (paddleY + rules.paddleHeight / 2.0)) / (rules.paddleHeight / 2.0));
      speed = min 760.0 (abs b.vx * 1.065);
      deflection = offset * speed * 0.8;
      bounceY = if abs deflection < 70 then (if vy < 0 then -70.0 else 70.0) else deflection;
      next = moved // {
        rally = state.rally + (if hit then 1 else 0);
        ball = {
          x = if hitLeft then rules.leftX + rules.paddleWidth + rules.radius
            else if hitRight then rules.rightX - rules.radius else x;
          inherit y;
          vx = if hitLeft then speed else if hitRight then -speed else b.vx;
          vy = if hit then bounceY else vy;
        };
      };
    in
      if state.phase != "playing" then state
      else if x + rules.radius < rules.left then score moved "right"
      else if x - rules.radius > rules.right then score moved "left"
      else next;

  step = state: {
    delta ? 0.0, left ? 0, right ? 0,
    start ? false, pause ? false, restart ? false, toggleMode ? false
  }:
    let
      dt = clamp 0.0 rules.maxDelta delta;
      input = { left = clamp (-1) 1 left; right = clamp (-1) 1 right; };
      # Small bounded steps keep even the fastest ball from tunnelling through a paddle.
      count = max 1 (builtins.ceil (dt * 240));
      advanced = builtins.foldl'
        (s: _: builtins.deepSeq s (advance s input (dt / count)))
        state (builtins.genList (i: i) count);
      moving = movePaddles state input dt;
    in
      if toggleMode then initial { mode = if state.mode == "solo" then "versus" else "solo"; }
      else if restart then initial { inherit (state) mode; }
      else if state.phase == "finished" then
        (if start then serve (initial { inherit (state) mode; }) else state)
      else if state.phase == "ready" then (if start then serve moving else moving)
      else if state.phase == "paused" then (if start || pause then state // { phase = "playing"; } else state)
      else if state.phase == "point" then
        (if start || state.serveTimer <= dt then serve moving
         else moving // { serveTimer = state.serveTimer - dt; })
      else if start || pause then state // { phase = "paused"; }
      else advanced // {
        trail = if advanced.phase == "playing" && dt > 0
          then take 8 ([ { inherit (state.ball) x y; } ] ++ state.trail)
          else if advanced.phase == "playing" then state.trail else [];
      };
in {
  inherit rules initial step;
}

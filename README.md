# Pong / nixray

2D Pong written in Nix using the local plugin from `../nixray`. No audio or
external graphics assets. The first player to **7 points** wins.

## Run

Keep `pong-nix-raylib` and `nixray` next to each other. Requires Nix with flakes
and an X11/Wayland desktop. Run from this directory:

```sh
nix run .
```

Alternatively, use the built nixray launcher directly:

```sh
nix build ../nixray
./result/bin/nixray pong.nix
```

`nix run .` builds a `pong` launcher with matching Nix/plugin versions.
nixray's graphics driver selection remains available: for example,
`NIXRAY_GRAPHICS=system nix run .` uses your configured system drivers.

## Controls

| Key | Action |
| --- | --- |
| Space / Enter | Start, pause, resume, or play again after a match |
| W / S | Move the left paddle |
| Up / Down | Also move the left paddle in solo mode; move the right paddle in versus mode |
| P | Pause / resume |
| R | Reset the match |
| Tab | Switch CPU / local versus mode (resets the match) |
| Escape | Quit |

The next serve starts automatically after a point; Space skips the short delay.
Paddle hits speed up the ball, and the impact position determines its bounce
angle. Simulation time is capped after long interruptions to keep the ball from
tunnelling through paddles.

## Tests

```sh
nix flake check -L
```

Checks cover pure game logic, keyboard mapping, draw-command validation, and real
OpenGL windows using software Mesa under Xvfb. No visible desktop is needed for
the checks. For a short manual window test on your desktop:

```sh
nix run . -- --arg hidden true --arg maxFrames 5
```

- `game.nix`: pure state machine and physics with small simulation steps.
- `render.nix`: court, scoreboard, ball trail, and status overlays.
- `app.nix`: nixray frame and keyboard integration.
- `pong.nix`: directly runnable entry point.

The flake uses the local Git checkout `git+file:../nixray`, pinned by `flake.lock`.
After new commits there, run `nix flake update nixray` from this directory.
Use the direct nixray launcher to test uncommitted nixray changes.

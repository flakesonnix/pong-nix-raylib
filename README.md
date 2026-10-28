# Pong / nixray

2D Pong written in Nix using [nixray](https://github.com/flakesonnix/nixray). No audio or
external graphics assets. The first player to **7 points** wins.

## Run

Requires Nix with flakes and an X11/Wayland desktop. The nixray dependency is
fetched from GitHub; no sibling checkout is needed. Run from this directory:

```sh
nix run .
```

Alternatively, build and run the packaged launcher:

```sh
nix build .
./result/bin/pong
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
- `pong.nix`: entry point used by the packaged launcher.

The flake uses `github:flakesonnix/nixray`, pinned by `flake.lock`.
Run `nix flake update nixray` to update it. To test a local checkout instead:

```sh
nix run . --override-input nixray ../nixray
```

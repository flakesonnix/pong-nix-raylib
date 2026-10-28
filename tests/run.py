#!/usr/bin/env python3
"""Evaluate pure tests and exercise the real nixray/packaged launchers under Xvfb."""

import argparse
import json
from pathlib import Path
import subprocess


def evaluate(command):
    result = subprocess.run(command, text=True, capture_output=True, timeout=90)
    if result.returncode:
        raise AssertionError(
            f"Command failed ({result.returncode}): {command}\n"
            f"{result.stdout}\n{result.stderr}"
        )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AssertionError(f"Invalid JSON:\n{result.stdout}\n{result.stderr}") from error


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--nixray", required=True)
    parser.add_argument("--pong", required=True)
    parser.add_argument("--ray", type=Path, required=True)
    args = parser.parse_args()
    ray_arg = ["--arg", "ray", f"import {args.ray.resolve()}"]

    model = evaluate([args.nixray, str(args.source / "tests/game.nix")])
    print(f"PASS: {model['passed']} physics/state tests", flush=True)

    app = evaluate([args.nixray, str(args.source / "tests/app.nix"), *ray_arg])
    print(f"PASS: {app['passed']} input/render tests", flush=True)

    runtime = evaluate([args.nixray, str(args.source / "tests/runtime.nix"), *ray_arg])
    require(runtime["frames"] == 10, "Runtime must render ten frames")
    state = runtime["state"]
    require(state["phase"] == "playing" and state["mode"] == "versus", "Runtime input did not start versus mode")
    require(state["leftScore"] == state["rightScore"] == 0, "Mode switch must clear scores")
    require(state["ball"]["vx"] > 0, "Final frame must serve the ball")
    print("PASS: real OpenGL rendering of all phases and scripted keyboard input", flush=True)

    smoke = evaluate([args.pong, "--arg", "hidden", "true", "--arg", "maxFrames", "5"])
    require(smoke["frames"] == 5 and smoke["state"]["phase"] == "ready", "Packaged launcher smoke test failed")
    print("PASS: packaged launcher / finite hidden window", flush=True)


if __name__ == "__main__":
    main()

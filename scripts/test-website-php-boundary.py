#!/usr/bin/env python3
# -----------------------------------------------------------------------------
#  Copyright (c) 2024-present NoMercy Entertainment. All rights reserved.
#
#  This file is part of NoMercy Stack, source-available software (NOT open
#  source). Personal use and contributions are welcome; distribution, resale,
#  relicensing, and commercial exploitation are prohibited without explicit
#  written consent. See LICENSE for full terms. Distributed WITHOUT ANY WARRANTY.
#
#  SPDX-License-Identifier: LicenseRef-NoMercy-Proprietary
# -----------------------------------------------------------------------------

"""Check website PHP routing using inert text in an isolated local container.

Requires an already-built website image (default: nomercy-stack-website).
The container has no network, application mounts, secrets or published ports.
Every fixture is plain text without PHP tags; no exploit or downloaded code
is used. Only the repository nginx and FPM configs are copied into the fixture.
"""

import argparse
import subprocess
import uuid
from pathlib import Path


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"Command failed: {args!r}\n{result.stderr.strip()}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", default="nomercy-stack-website")
    parser.add_argument("--config", type=Path, help="Website server config to check")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    name = "nomercy-php-boundary-" + uuid.uuid4().hex[:12]
    checked = 0
    failures = 0
    try:
        run(
            "docker", "run", "--detach", "--name", name,
            "--network", "none", "--no-healthcheck",
            "--tmpfs", "/var/www/html:rw,noexec,nosuid,size=1m",
            "--entrypoint", "sleep", args.image, "300",
        )
        run("docker", "exec", name, "mkdir", "-p", "/var/www/html/public/uploads")
        fixtures = {
            "index.php": "front-controller-sentinel\n",
            "styles.css": "static-asset-sentinel\n",
            "uploaded.php": "inert-upload-sentinel\n",
            "uploaded.PHP": "inert-upload-sentinel\n",
            "uploaded.php.jpg": "inert-upload-sentinel\n",
            "uploads/uploaded.php": "inert-upload-sentinel\n",
        }
        for path, content in fixtures.items():
            subprocess.run(
                ["docker", "exec", "-i", name, "tee", "/var/www/html/public/" + path],
                input=content, check=True, capture_output=True, text=True,
            )
        for source, destination in (
            ("website/config/nginx.conf", "/etc/nginx/nginx.conf"),
            (args.config or "website/config/conf.d/default.conf", "/etc/nginx/conf.d/default.conf"),
            ("website/config/fpm-pool.conf", "/usr/local/etc/php-fpm.d/www.conf"),
        ):
            run("docker", "cp", str(repo / source), name + ":" + destination)
        run("docker", "exec", name, "nginx", "-t")
        run("docker", "exec", name, "php-fpm", "-D", "-y", "/usr/local/etc/php-fpm.d/www.conf")
        run("docker", "exec", name, "nginx")
        cases = [
            ("/", 200, "front-controller-sentinel"),
            ("/index.php", 200, "front-controller-sentinel"),
            ("/index.php?value=uploaded.php", 200, "front-controller-sentinel"),
            ("/settings/profile", 200, "front-controller-sentinel"),
            ("/api/v1/server", 200, "front-controller-sentinel"),
            ("/icons.svg", 200, "front-controller-sentinel"),
            ("/styles.css", 200, "static-asset-sentinel"),
            ("/missing.css", 404, None),
            ("/fpm-ping", 200, "pong"),
            ("/uploaded.php", 404, None),
            ("/uploaded.PHP", 404, None),
            ("/uploaded.php.jpg", 404, None),
            ("/uploads/uploaded.php", 404, None),
            ("/uploaded%2ephp", 404, None),
            ("/uploaded.php/path", 404, None),
            ("/index.php/path", 404, None),
            ("/missing.php", 404, None),
        ]
        for path, expected, marker in cases:
            response = run(
                "docker", "exec", name, "curl", "--silent", "--show-error",
                "--max-time", "5", "--path-as-is", "--write-out", "\n%{http_code}",
                "http://127.0.0.1:8080" + path,
            )
            body, status = response.rsplit("\n", 1)
            checked += 1
            ok = int(status) == expected and (marker is None or marker in body)
            if expected == 404:
                ok = ok and "inert-upload-sentinel" not in body
            failures += not ok
            print(f"{'PASS' if ok else 'FAIL'} {path}: status={status} expected={expected}")
        print(f"checked={checked} failures={failures}")
        return 1 if failures else 0
    finally:
        subprocess.run(["docker", "rm", "--force", name], capture_output=True)


if __name__ == "__main__":
    raise SystemExit(main())

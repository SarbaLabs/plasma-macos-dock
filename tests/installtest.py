# SPDX-License-Identifier: GPL-2.0-or-later
"""Exercise installer branching without sudo, installation or desktop changes."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

source = Path(sys.argv[1])
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    shutil.copy(source / "install.sh", root / "install.sh")
    (root / "contents").mkdir()
    (root / "contents" / "sentinel").write_text("matching QML")
    (root / "metadata.json").write_text('{}')
    commands = root / "commands"
    commands.mkdir()
    log = root / "calls"
    shim = commands / "shim"
    shim.write_text('''#!/bin/bash
name="${0##*/}"
printf '%s' "$name" >> "$TEST_LOG"
printf ' <%s>' "$@" >> "$TEST_LOG"
printf '\\n' >> "$TEST_LOG"
if [ "$name" = systemctl ]; then exit 1; fi
''')
    shim.chmod(0o755)
    for name in ("cmake", "g++", "make", "sudo", "systemctl"):
        (commands / name).symlink_to(shim)
    data = root / "user data"
    applet = data / "plasma/plasmoids/com.github.mattanis.macosdock"
    applet.mkdir(parents=True)
    env = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ["PATH"],
               XDG_DATA_HOME=str(data), TEST_LOG=str(log))

    def run(*args):
        log.write_text("")
        subprocess.run(["bash", str(root / "install.sh"), *args], env=env, check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return log.read_text()

    calls = run("--plugin-only")
    assert "<-DBUILD_PLUGIN_ONLY=ON>" in calls
    assert not (applet / "contents/sentinel").exists()
    calls = run()
    assert "<-DBUILD_PLUGIN_ONLY=OFF>" in calls
    assert "<-DBUILD_PLUGIN_ONLY=ON>" not in calls
    assert "<-DBUILD_NATIVE_MENUS=ON>" in calls
    assert (applet / "contents/sentinel").read_text() == "matching QML"
    assert (applet / "metadata.json").read_text() == '{}'
    assert not (applet / "build").exists()
    (applet / "contents/sentinel").write_text("old version")
    run()
    assert (applet / "contents/sentinel").read_text() == "matching QML"
    shutil.rmtree(applet)
    run()
    assert not applet.exists()
print("Installer: plugin-only, full install, and user override paths passed")

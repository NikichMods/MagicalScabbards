# SPDX-License-Identifier: MPL-2.0
"""Build a byte-reproducible, source-only UE4SS candidate from a clean commit."""
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ["Scripts/main.lua", "Scripts/equipment.lua", "Scripts/outgoing.lua",
         "Scripts/reconcile.lua", "Scripts/visibility.lua", "Scripts/vfx.lua",
         "LICENSE", "LICENSING.md", "README.md"]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def archive(files):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_STORED) as out:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo("MagicalScabbards/" + name, (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            out.writestr(info, data)
    return buffer.getvalue()


def build():
    if git("status", "--porcelain").strip():
        raise SystemExit("Candidate requires a clean committed source tree")
    commit = git("rev-parse", "HEAD").decode().strip()
    files = {name: git("show", f"{commit}:{name}") for name in FILES}
    main = files["Scripts/main.lua"].decode()
    version = re.search(r'^local VERSION = "([^"]+)"$', main, re.M).group(1)
    assert re.fullmatch(r"\d+\.\d+\.\d+(?:-test\.\d+)?", version)
    stable = "-test." not in version
    assert 'local DEBUG_LOGGING = false' in main
    assert f"MagicalScabbards-{version}.zip".encode() in files["README.md"]
    record_name = f"docs/RELEASE_{version}.md" if stable else f"docs/RELEASE_CANDIDATE_{version}.md"
    record = git("show", f"{commit}:{record_name}")
    accepted_test_source = None
    if stable:
        assert f"# MagicalScabbards {version}".encode() in record
        match = re.search(rb"(?m)^Accepted test source: `([0-9a-f]{40})`$", record)
        assert match, "Stable release requires an accepted immutable test source"
        accepted_test_source = match.group(1).decode()
        for name in FILES:
            if not name.startswith("Scripts/"):
                continue
            accepted = git("show", f"{accepted_test_source}:{name}")
            if name == "Scripts/main.lua":
                test_version = re.compile(rb'(?m)^local VERSION = "' + re.escape(version.encode())
                                          + rb'-test\.\d+"$')
                accepted, matches = test_version.subn(f'local VERSION = "{version}"'.encode(), accepted)
                assert matches == 1, "Accepted source must be a numbered candidate for this release"
            assert files[name] == accepted, f"Stable behavior differs from accepted source: {name}"
    else:
        assert f"# MagicalScabbards {version}".encode() in record
        assert b"NOT ACCEPTED FOR RELEASE" in record
    for name in FILES:
        if name.startswith("Scripts/"):
            assert files[name].startswith(b"-- SPDX-License-Identifier: MPL-2.0"), name
    assert 'require("vfx")' in main and "Scripts/vfx.lua" in files
    assert b"ModRef" not in files["Scripts/vfx.lua"], "research browser bridge in production"
    assert b"snapshot.kinds" not in files["Scripts/vfx.lua"], "staff-only VFX gate remains"
    assert b"Mozilla Public License Version 2.0" in files["LICENSE"]
    files["enabled.txt"] = b""
    manifest = {"mod": "MagicalScabbards", "version": version, "source_commit": commit,
                "source_url": f"https://github.com/NikichMods/MagicalScabbards/tree/{commit}",
                "target": "Asterigos Steam 1.09 build 12996889; UE4SS 3.0.1-1181-g83330635; Windows x64",
                "acceptance": "ACCEPTED" if stable else "PENDING",
                "accepted_test_source": accepted_test_source,
                "sha256": {name: sha(data) for name, data in sorted(files.items())}}
    files["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()
    data = archive(files)
    assert data == archive(files), "non-reproducible archive"
    # Verify the consumer layout, exact payload bytes and complete manifest before handoff.
    with zipfile.ZipFile(io.BytesIO(data)) as candidate:
        assert candidate.testzip() is None
        assert set(candidate.namelist()) == {"MagicalScabbards/" + name for name in files}
        for name, original in files.items():
            assert candidate.read("MagicalScabbards/" + name) == original
        assert json.loads(candidate.read("MagicalScabbards/manifest.json")) == manifest
    output = ROOT / "dist" / f"MagicalScabbards-{version}.zip"
    output.parent.mkdir(exist_ok=True)
    if output.exists() and output.read_bytes() != data:
        raise SystemExit("Refusing to overwrite a different candidate with this version; use a fresh output directory/version")
    output.write_bytes(data)
    output.with_suffix(".zip.sha256").write_text(sha(data) + "  " + output.name + "\n", encoding="ascii")
    output.with_suffix(".manifest.json").write_bytes(files["manifest.json"])
    print(json.dumps({"file": str(output), "source_commit": commit, "version": version,
                      "bytes": len(data), "sha256": sha(data), "payload_sha256": manifest["sha256"]}, indent=2))


if __name__ == "__main__":
    build()

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
         "Scripts/reconcile.lua", "Scripts/visibility.lua", "LICENSE", "LICENSING.md", "README.md"]


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
    assert re.fullmatch(r"\d+\.\d+\.\d+-test\.\d+", version)
    assert 'local DEBUG_LOGGING = false' in main
    assert f"MagicalScabbards-{version}.zip".encode() in files["README.md"]
    record = git("show", f"{commit}:docs/RELEASE_CANDIDATE_01.md")
    assert f"# Устанавливаемый кандидат 01 — {version}".encode() in record
    for name in FILES:
        if name.startswith("Scripts/"):
            assert files[name].startswith(b"-- SPDX-License-Identifier: MPL-2.0")
            assert sha(files[name]).encode() in record, f"stale documented hash: {name}"
            if name != "Scripts/main.lua":
                assert files[name] == git("show", f"{commit}:research/scabbard-reconcile-bracer-03/{name}"), name
    assert b"Mozilla Public License Version 2.0" in files["LICENSE"]
    files["enabled.txt"] = b""
    manifest = {"mod": "MagicalScabbards", "version": version, "source_commit": commit,
                "source_url": f"https://github.com/NikichMods/MagicalScabbards/tree/{commit}",
                "target": "Asterigos Steam 1.09 build 12996889; UE4SS 3.0.1-1181-g83330635; Windows x64",
                "acceptance": "PENDING", "sha256": {name: sha(data) for name, data in sorted(files.items())}}
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

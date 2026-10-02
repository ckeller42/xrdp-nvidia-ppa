#!/usr/bin/env python3
"""Launchpad PPA checks (anonymous, read-only).
  lp-build-status.py --exists <source> <version>   exit 0 if the version is already in the PPA, else 1
  lp-build-status.py <source> <version> [--timeout S] wait for the builds: 0 all built, 1 failed, 2 timeout
"""
import argparse, sys, time
from launchpadlib.launchpad import Launchpad

OWNER, PPA = "christoph-keller", "xrdp-nvidia"
OK = {"Successfully built"}
PENDING = {"Needs building", "Currently building", "Uploading build", "Dependency wait", "Gathering build output"}


def sources(archive, src, ver):
    return list(archive.getPublishedSources(source_name=src, version=ver, exact_match=True))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exists", action="store_true")
    ap.add_argument("--timeout", type=int, default=10800)
    ap.add_argument("source"); ap.add_argument("version")
    a = ap.parse_args()
    lp = Launchpad.login_anonymously("xrdp-nvidia-ppa", "production", version="devel")
    archive = lp.people[OWNER].getPPAByName(name=PPA)
    if a.exists:
        found = sources(archive, a.source, a.version)
        print(f"{a.source} {a.version}: {'present' if found else 'not in PPA'}")
        return 0 if found else 1
    deadline = time.time() + a.timeout
    while True:
        pubs = sources(archive, a.source, a.version)
        states = [(b.arch_tag, b.buildstate) for p in pubs for b in p.getBuilds()]
        print(f"{a.source} {a.version}: {states or 'not yet accepted'}", flush=True)
        if states and all(s in OK for _, s in states):
            return 0
        if any(s not in OK and s not in PENDING for _, s in states):
            return 1
        if time.time() > deadline:
            return 2
        time.sleep(60)


if __name__ == "__main__":
    sys.exit(main())

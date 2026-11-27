# Avelra 0.5 documentation (staging)

This directory is the staging area for documentation of the unreleased Avelra
0.5.0. It starts as a copy of the current 0.4.2 user documentation. It currently
contains a partial 0.5 sync for verified behavior: x64 targets, unsigned
Windows/macOS artifacts, Windows prerequisites and the Windows .exe/openUrl
fixes. Pending release gates still require updates before promotion.

Rules:

- this directory is not the current release documentation;
- do not link to it from `docs/user/` or the public README;
- do not publish it until release promotion;
- before 0.5.0, sync it with the release candidate, run `docs.py`, then move
  its contents into `docs/user/` and delete this directory.

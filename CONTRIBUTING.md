# Contributing to Kotton's distribution

Kotton is pre-alpha, built by one owner and the agents working at the owner's direction, and
open to anyone who wants to read it whole and send a change back. This repository is the
distribution: the installers, the launcher and the nine lines a person types. This page is how
a change to it works.

## Reach green

```sh
git clone https://github.com/kottonllc/kotton-dist && cd kotton-dist
sh tools/check.sh
```

`tools/check.sh` runs `sh -n` over every script, refuses an archive `release.lock` names and
the release workflow does not, or the other way round, refuses a release workflow that does
not mark a pre-release tag's release as one, and refuses a README whose nine lines or host lines
clone anything but this repository or run anything but its `install.sh` (a line still naming
`kottonllc/kotton` or `kotton/install.sh`); `.github/workflows/lint.yml` runs it on
every pull request. Every script here is POSIX `sh`, and nothing here is built: a change is
proved by running what it changes, on the machine it is for, and saying in the pull request what
ran and what it printed.

## The loop

- **An issue is the brief.** It says what is wrong or missing, where, and what done looks like.
  Open one before anything larger than a fix, so the shape is agreed before the work.
- **A pull request is the change.** One logical change, on a branch named for it, against
  `main`. Its description says what changed and every check that ran, each with its real exit.
  A claim a reviewer cannot reproduce is a reason to send it back.
- **An assessor, then a reviewer.** The assessor holds the change to the issue: does it do what
  was asked, at the cause rather than the site, and nothing else. The reviewer holds it to the
  design: does it keep the ownership bar, and does it say what it changed. Either may send it
  back, with the reason in writing.

## Every commit is signed off

Every commit carries a `Signed-off-by: Your Name <email>` line, which `git commit -s` adds.
By it you certify the [Developer Certificate of Origin 1.1](DCO.md): that you have the right
to submit the change under the licence [`LICENSE`](LICENSE) gives the directory it lands in,
and that the record of it is public and kept.

There is no exemption. A commit an agent made at your direction is authored as you, carries
an `Assisted-by: <tool>` trailer, and carries your own sign-off: an agent cannot certify, and
a commit authored as an agent is refused. A merge commit is a commit: `git merge --signoff`
signs it.

The check that holds this is [`.github/workflows/signoff.yml`](.github/workflows/signoff.yml),
and it runs on every pull request.

## What does not bend

- **Ownership is the bar.** Ask of any surface you touch: does this compose into an asset, and
  whose?
- **Nothing is unpacked before its signature checks.** `install.sh` verifies the release's
  `SHA256SUMS.sig` against `infra/release/allowed_signers` as the tag holds it, and the archive
  against the signed sums, before anything runs; a change that loosens that is refused.
- **Never `--no-verify`, never force-push a shared branch, never rewrite published history.**
- **Never delete code on suspicion.** Remove what you can show is dead, in its own commit.

## Security

Report a vulnerability privately, per [`SECURITY.md`](SECURITY.md), and never in a public issue.

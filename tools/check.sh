#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# The distribution's gate: every script parses, and the release lock and the release workflow
# name the same archives.
#
#   sh tools/check.sh [<root>]       <root> is the checkout, this script's own by default
#
# .github/workflows/lint.yml runs it on every pull request. It refuses, naming each:
#
#   - a script `sh -n` cannot parse: every `*.sh`, and every file whose first line is a `sh`
#     shebang, outside .git;
#   - a line of release.lock that is not `<name> <platform> <owner>/<repository> <tag>
#     <commit>`, with a `v*` tag and a full commit, or `-` for both (not released yet), and an
#     archive named twice for one platform;
#   - an archive release.lock names and the ARCHIVES line of .github/workflows/release.yml does
#     not, or the other way round, or a workflow without exactly one ARCHIVES line;
#   - a release workflow that does not mark a pre-release tag's release as one: a tag with a
#     `-` in it (`vX.Y.Z-dev.N`, `vX.Y.Z-rc.N`, kotton-protocol's VERSIONING.md) must set
#     `--prerelease`, and both the `gh release create` that makes the release and the
#     `gh release edit` after an upload to a release the owner drafted must pass it;
#   - a README that installs from anywhere but this repository: its nine lines' install line
#     must clone https://github.com/kottonllc/kotton-dist at `<tag>` and run
#     `sh kotton-dist/install.sh`; the host's two lines (what `kotton mint host` prints) must
#     be in a fenced block, the clone alone and then `sh kotton-dist/install.sh --kind host`
#     with the keys; and every `git clone` line and every install.sh run (`sh`, `bash` or `.`
#     followed by a path ending in install.sh) anywhere in it
#     must name that same repository and that same installer, so a line still cloning
#     `kottonllc/kotton` or running `kotton/install.sh` is refused.
#
# The release workflow holds the same equality again at the tag (tools/assemble.sh), so a lock
# that drifted after this ran is refused before anything is attached.
set -eu

root=${1:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
lock=$root/release.lock
workflow=$root/.github/workflows/release.yml
bad=0
say() {
    echo "check: $*" >&2
    bad=1
}

# 1. Every script parses.
n=0
for f in $(find "$root" -path "$root/.git" -prune -o -type f -print | sort); do
    case "$f" in
        *.sh) ;;
        *) head -n 1 "$f" 2>/dev/null | grep -qx '#! *\(/bin/sh\|/usr/bin/env sh\)' || continue ;;
    esac
    n=$((n + 1))
    sh -n "$f" || say "${f#"$root"/} does not parse as sh"
done
echo "check: sh -n over $n script(s)"

# 2. The lock is well formed.
[ -f "$lock" ] || { say "there is no release.lock"; exit 1; }
rows=$(sed 's/#.*//' "$lock" | awk 'NF')
[ -n "$rows" ] || say "release.lock names no archive"
seen=
while read -r name platform repo tag commit extra; do
    [ -n "$name" ] || continue
    row="release.lock: '$name $platform $repo $tag $commit${extra:+ $extra}'"
    if [ -n "$extra" ] || [ -z "$commit" ]; then
        say "$row is not <name> <platform> <repository> <tag> <commit>"
        continue
    fi
    echo "$name" | grep -qx 'kotton\(-[a-z][a-z0-9]*\)*' || say "$row: '$name' is not an archive's name"
    echo "$platform" | grep -qx '[a-z][a-z0-9]*-[a-z0-9_]*' || say "$row: '$platform' is not <os>-<arch>"
    echo "$repo" | grep -qx '[A-Za-z0-9_.-]*/[A-Za-z0-9_.-]*' || say "$row: '$repo' is not <owner>/<repository>"
    if [ "$tag" = - ] || [ "$commit" = - ]; then
        [ "$tag" = - ] && [ "$commit" = - ] || say "$row: a tag and a commit, or '-' for both"
    else
        echo "$tag" | grep -qx 'v[0-9A-Za-z.+-]*' || say "$row: '$tag' is not a v* tag"
        echo "$commit" | grep -qx '[0-9a-f]\{40\}' || say "$row: '$commit' is not a full commit"
    fi
    case " $seen " in *" $name@$platform "*) say "$row: $name for $platform is named twice" ;; esac
    seen="$seen $name@$platform"
done <<EOF
$rows
EOF

# 3. The lock and the workflow name the same archives.
if [ ! -f "$workflow" ]; then
    say "there is no .github/workflows/release.yml"
else
    lines=$(grep -c '^[[:space:]]*ARCHIVES:' "$workflow" || true)
    if [ "$lines" != 1 ]; then
        say ".github/workflows/release.yml has $lines ARCHIVES lines, and names the archives it ships in exactly one"
    else
        shipped=$(grep '^[[:space:]]*ARCHIVES:' "$workflow" | sed 's/^[[:space:]]*ARCHIVES:[[:space:]]*//; s/[[:space:]]#.*//' | tr -d "'\"")
        locked=$(printf '%s\n' "$rows" | awk 'NF { print $1 }' | sort -u)
        for a in $locked; do
            case " $shipped " in *" $a "*) ;; *) say "release.lock names $a, and the release workflow's ARCHIVES does not" ;; esac
        done
        for a in $shipped; do
            case " $(echo $locked) " in *" $a "*) ;; *) say "the release workflow's ARCHIVES names $a, and release.lock does not" ;; esac
        done
        echo "check: release.lock names $(echo $locked); the release workflow ships $shipped"
    fi
fi

# 4. A pre-release tag's release is marked as one, on both of the workflow's paths.
if [ -f "$workflow" ]; then
    pre=0
    grep -qF 'case "$TAG" in *-*) prerelease="--prerelease" ;; esac' "$workflow" || {
        say ".github/workflows/release.yml does not set --prerelease for a tag with a '-' in it"
        pre=1
    }
    grep -q '^[[:space:]]*gh release create .*\$prerelease' "$workflow" || {
        say ".github/workflows/release.yml's gh release create does not pass \$prerelease"
        pre=1
    }
    grep -q '^[[:space:]]*gh release edit .*--prerelease' "$workflow" || {
        say ".github/workflows/release.yml does not mark a release the owner drafted as a pre-release (gh release edit --prerelease)"
        pre=1
    }
    [ "$pre" = 1 ] || echo "check: the release workflow marks a pre-release tag's release as one"
fi

# 5. The README installs from this repository on every line: the nine lines' install line and
# the host's two lines clone the same repository and run the same installer, this one's.
readme=$root/README.md
url=https://github.com/kottonllc/kotton-dist
installer=kotton-dist/install.sh
clone="git clone --depth 1 --branch <tag> $url"
if [ ! -f "$readme" ]; then
    say "there is no README.md"
else
    rd=0
    fenced=$(awk '/^[[:space:]]*```/ { f = !f; next } f { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$readme")
    printf '%s\n' "$fenced" | grep -qxF "$clone && sh $installer" || {
        say "README.md's nine lines do not install with '$clone && sh $installer'"
        rd=1
    }
    printf '%s\n' "$fenced" | grep -qxF "$clone" || {
        say "README.md's host section does not show '$clone', the first line kotton mint host prints"
        rd=1
    }
    printf '%s\n' "$fenced" | grep -qxF "KOTTON_OPERATOR_KEY_RELAY=<relay key> KOTTON_OPERATOR_KEY_VAULT=<vault key> sh $installer --kind host" || {
        say "README.md's host section does not show 'KOTTON_OPERATOR_KEY_RELAY=<relay key> KOTTON_OPERATOR_KEY_VAULT=<vault key> sh $installer --kind host', the second line kotton mint host prints"
        rd=1
    }
    # Every clone and every installer, fenced or in prose, is this repository's.
    wrong=$(grep -n 'git clone' "$readme" | while IFS= read -r l; do
        case "${l#*git clone}" in
            *" $url" | *" $url "* | *" $url\`"*) ;;
            *) echo "check: README.md:${l%%:*} clones something other than $url: '${l#*:}'" >&2; echo x ;;
        esac
    done)
    wrong=$wrong$(grep -noE '(^|[^A-Za-z0-9_./-])(sh|bash|\.) +[^ `]*install\.sh' "$readme" | while IFS= read -r l; do
        run=$(printf '%s\n' "${l#*:}" | sed -E 's/^[^A-Za-z.]*//')
        [ "$run" = "sh $installer" ] || { echo "check: README.md:${l%%:*} runs '$run', not this repository's 'sh $installer'" >&2; echo x; }
    done)
    [ -z "$wrong" ] || { rd=1; bad=1; }
    [ "$rd" = 1 ] || echo "check: README.md clones $url and runs $installer, in the nine lines and on the host"
fi

[ "$bad" = 0 ] || exit 1
echo "check: OK"

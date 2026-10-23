#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Assemble a release of the distribution: fetch every archive release.lock names from its
# component's own release, check each against that component's SHA256SUMS, and write one
# SHA256SUMS over the set.
#
#   ARCHIVES='kotton kotton-relay …' sh tools/assemble.sh <lock> <out>
#
# The release workflow (.github/workflows/release.yml) runs this on a `v*` tag, with the lock
# as the tag holds it, and attaches what it leaves in <out> to the tag's release. It builds
# nothing: each component built its archive once, from its own tag, and published it with its
# own sums; the distribution composes. It signs nothing: the owner signs <out>/SHA256SUMS on
# their own machine and attaches SHA256SUMS.sig by hand.
#
# For each line of the lock, in order, stopping at the first thing that is not so:
#
#   1. the line has a tag and a commit, not `-` (a component that has not released yet);
#   2. the component's tag names the lock's commit, read with `git ls-remote` (a moved tag is
#      refused, not followed);
#   3. the component's SHA256SUMS at that tag names the archive
#      `<name>-<commit, 12>-<platform>.tar.gz` exactly once;
#   4. the archive downloaded from that release has the sum that line gives.
#
# and before any of it, that the lock names exactly the archives ARCHIVES names, so the
# workflow and the lock cannot drift apart at the moment of a release either.
#
# Downloads take no token: a component's release page answers anyone. KOTTON_COMPONENT_SITE
# replaces https://github.com, under which a component is <site>/<repository> for git and
# <site>/<repository>/releases/download/<tag>/<file> for its assets; a `file://` site runs the
# whole of this against a local copy, which is how it is tried without a release.
set -eu

refuse() {
    echo "assemble: $*" >&2
    exit 1
}

[ "$#" -eq 2 ] || refuse "usage: ARCHIVES='<name> …' sh tools/assemble.sh <lock> <out>"
lock=$1
out=$2
[ -f "$lock" ] || refuse "there is no lock at $lock"
[ -n "${ARCHIVES:-}" ] || refuse "ARCHIVES is not set: the workflow names the archives it ships"
site=${KOTTON_COMPONENT_SITE:-https://github.com}

for tool in git curl sha256sum awk mktemp; do
    command -v "$tool" >/dev/null 2>&1 || refuse "$tool is not on this machine"
done

# The lock's lines, comments and blank lines gone, each refused unless it has five fields.
rows=$(sed 's/#.*//' "$lock" | awk 'NF { if (NF != 5) { print "line with " NF " fields: " $0 > "/dev/stderr"; bad = 1 } else print } END { exit bad }') ||
    refuse "$lock has a line that is not <name> <platform> <repository> <tag> <commit>"
[ -n "$rows" ] || refuse "$lock names no archive"

# The lock names exactly what the workflow ships.
locked=$(printf '%s\n' "$rows" | awk '{ print $1 }' | sort -u)
named=$(printf '%s\n' $ARCHIVES | sort -u)
[ "$locked" = "$named" ] || refuse "$lock names $(echo $locked) and the workflow's ARCHIVES names $(echo $named); every archive is named in both or in neither"

[ ! -e "$out" ] || [ -z "$(ls -A "$out")" ] || refuse "$out is not empty, and only what the lock names goes in it"
mkdir -p "$out"
work=$(mktemp -d "${TMPDIR:-/tmp}/kotton-assemble.XXXXXX")
trap 'rm -rf "$work"' EXIT

fetch() {   # $1 the URL, $2 where it goes
    curl -fsSL --retry 2 --proto '=https,file' --proto-redir '=https' -o "$2" "$1"
}

files=
printf '%s\n' "$rows" > "$work/rows"
while read -r name platform repo tag commit; do
    if [ "$tag" = - ] || [ "$commit" = - ]; then
        refuse "$name for $platform: $repo has not released it yet (the lock's tag and commit are '-')"
    fi
    echo "$name $platform" | grep -qx '[a-z][a-z0-9-]* [a-z0-9_-]*' || refuse "'$name $platform' is not a name and a platform"
    echo "$commit" | grep -qx '[0-9a-f]\{40\}' || refuse "$name: '$commit' is not a full commit"
    file=$name-$(echo "$commit" | cut -c1-12)-$platform.tar.gz

    # 2. The tag names the commit: the peeled line for an annotated tag, else the tag's own.
    refs=$(git ls-remote "$site/$repo" "refs/tags/$tag" "refs/tags/$tag^{}") ||
        refuse "could not read the tags of $site/$repo"
    at=$(printf '%s\n' "$refs" | awk -v t="refs/tags/$tag^{}" '$2 == t { print $1 }')
    [ -n "$at" ] || at=$(printf '%s\n' "$refs" | awk -v t="refs/tags/$tag" '$2 == t { print $1 }')
    [ -n "$at" ] || refuse "$repo has no tag $tag"
    [ "$at" = "$commit" ] || refuse "$repo's $tag names $at, and the lock says $commit"

    # 3. The component's sums, once per repository and tag.
    sums=$work/$(echo "$repo" | tr / _)@$tag.SHA256SUMS
    if [ ! -f "$sums" ]; then
        fetch "$site/$repo/releases/download/$tag/SHA256SUMS" "$sums" ||
            refuse "could not download SHA256SUMS from $repo's $tag release"
    fi
    want=$(awk -v f="$file" '$2 == f || $2 == "*" f { print $1; n++ } END { exit n != 1 }' "$sums") ||
        refuse "$repo's $tag SHA256SUMS does not name $file exactly once"
    echo "$want" | grep -qx '[0-9a-f]\{64\}' || refuse "$repo's $tag SHA256SUMS gives '$want' for $file"

    # 4. The archive, against the component's line.
    case " $files " in *" $file "*) refuse "$lock names $file twice" ;; esac
    fetch "$site/$repo/releases/download/$tag/$file" "$out/$file" ||
        refuse "could not download $file from $repo's $tag release"
    got=$(sha256sum "$out/$file" | awk '{ print $1 }')
    [ "$got" = "$want" ] || refuse "$file from $repo's $tag release is $got, and its SHA256SUMS says $want"
    echo "assemble: $file  $repo@$tag  $want"
    files="$files $file"
done < "$work/rows"

# One SHA256SUMS over the set, in the lock's order: the file the owner signs.
# shellcheck disable=SC2086 # one file per word; the names hold no blank
(cd "$out" && sha256sum $files > SHA256SUMS)
echo "assemble: SHA256SUMS over$files"
cat "$out/SHA256SUMS"

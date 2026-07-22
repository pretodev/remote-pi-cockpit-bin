#!/usr/bin/env bash
set -Eeuo pipefail

readonly upstream_repo="jacobaraujo7/remote_pi"
readonly package_name="remote-pi-cockpit-bin"
readonly source_name="remote-pi-cockpit"

usage() {
  cat <<'EOF'
Usage: release.sh [--dry-run] <version|cockpit-vVERSION>

Validate and publish Remote Pi Cockpit to origin/main and aur/master.
Use --dry-run to perform all preparation and package checks without committing
or pushing; metadata is restored before exit.
EOF
}

fail() {
  printf 'release: %s\n' "$*" >&2
  exit 1
}

dry_run=false
if [[ ${1:-} == "--dry-run" ]]; then
  dry_run=true
  shift
fi

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  usage
  exit 0
fi

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

version=${1#cockpit-v}
[[ $version =~ ^[0-9]+([.][0-9]+){2}$ ]] ||
  fail "invalid version '$1'; expected X.Y.Z or cockpit-vX.Y.Z"
readonly version
readonly tag="cockpit-v${version}"

for command_name in bash bsdtar diff gh git jq ldd makepkg readlink sed sha256sum; do
  command -v "$command_name" >/dev/null || fail "missing command: $command_name"
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) ||
  fail "run this command inside the packaging repository"
readonly repo_root
cd "$repo_root"

[[ -f PKGBUILD && -f .SRCINFO ]] || fail "PKGBUILD or .SRCINFO is missing"
grep -qx "pkgname=${package_name}" PKGBUILD || fail "unexpected package repository"
[[ $(git branch --show-current) == "main" ]] || fail "release must run from branch main"
[[ -z $(git status --porcelain) ]] || fail "working tree must be clean before release"
git remote get-url origin >/dev/null || fail "missing origin remote"
git remote get-url aur >/dev/null || fail "missing aur remote"
[[ -z $(git ls-files -- src pkg) ]] || fail "src/ or pkg/ contains tracked files"

runtime_dir=$(mktemp -d -t remote-pi-cockpit-release.XXXXXX)
readonly runtime_dir
readonly original_pkgbuild="${runtime_dir}/PKGBUILD.original"
readonly original_srcinfo="${runtime_dir}/SRCINFO.original"
cp PKGBUILD "$original_pkgbuild"
cp .SRCINFO "$original_srcinfo"

metadata_changed=false
changes_committed=false
build_cleaned=false
aur_worktree=""
package_archive=""

restore_metadata() {
  if [[ $metadata_changed == true && $changes_committed == false ]]; then
    git restore --staged -- PKGBUILD .SRCINFO >/dev/null 2>&1 || true
    cp "$original_pkgbuild" PKGBUILD
    cp "$original_srcinfo" .SRCINFO
  fi
}

clean_build_output() {
  if [[ $build_cleaned == false ]]; then
    rm -rf -- "${repo_root}/src" "${repo_root}/pkg"
    rm -f -- "${repo_root}/${source_name}-${version}-x86_64.deb"
    if [[ -n $package_archive ]]; then
      rm -f -- "$package_archive"
    fi
    build_cleaned=true
  fi
}

cleanup() {
  local exit_code=$?
  if [[ -n $aur_worktree && -e $aur_worktree/.git ]]; then
    git worktree remove --force "$aur_worktree" >/dev/null 2>&1 || true
  fi
  clean_build_output
  restore_metadata
  rm -rf -- "$runtime_dir"
  exit "$exit_code"
}
trap cleanup EXIT

printf 'release: checking remotes\n'
git fetch origin main
git fetch aur master
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] ||
  fail "main differs from origin/main; synchronize it first"

printf 'release: reading upstream %s\n' "$tag"
release_json=$(gh api "repos/${upstream_repo}/releases/tags/${tag}") ||
  fail "upstream release ${tag} was not found"
jq -e '.draft == false and .prerelease == false' <<<"$release_json" >/dev/null ||
  fail "${tag} is a draft or prerelease"

x86_asset="${source_name}_${version}_amd64.deb"
arm_asset="${source_name}_${version}_arm64.deb"
x86_digest=$(jq -er --arg name "$x86_asset" '.assets[] | select(.name == $name) | .digest' <<<"$release_json") ||
  fail "missing upstream asset: ${x86_asset}"
arm_digest=$(jq -er --arg name "$arm_asset" '.assets[] | select(.name == $name) | .digest' <<<"$release_json") ||
  fail "missing upstream asset: ${arm_asset}"
[[ $x86_digest == sha256:* && $arm_digest == sha256:* ]] ||
  fail "upstream assets do not expose SHA-256 digests"
x86_sum=${x86_digest#sha256:}
arm_sum=${arm_digest#sha256:}

printf 'release: updating package metadata\n'
metadata_changed=true
sed -Ei \
  -e "s/^pkgver=.*/pkgver=${version}/" \
  -e 's/^pkgrel=.*/pkgrel=1/' \
  -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${x86_sum}')/" \
  -e "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${arm_sum}')/" \
  PKGBUILD
makepkg --printsrcinfo >"${runtime_dir}/.SRCINFO"
install -m 644 "${runtime_dir}/.SRCINFO" .SRCINFO

bash -n PKGBUILD
diff -u .SRCINFO <(makepkg --printsrcinfo)
git diff --check

printf 'release: verifying arm64 checksum\n'
gh release download "$tag" \
  --repo "$upstream_repo" \
  --pattern "$arm_asset" \
  --dir "$runtime_dir"
printf '%s  %s\n' "$arm_sum" "${runtime_dir}/${arm_asset}" | sha256sum --check --status -

printf 'release: building and inspecting native package\n'
makepkg --verifysource
package_archive=$(makepkg --packagelist)
makepkg --cleanbuild --force

package_dir="${repo_root}/pkg/${package_name}"
binary="${package_dir}/opt/cockpit/cockpit"
[[ -x $binary ]] || fail "packaged launcher is missing"
[[ $(readlink "${package_dir}/usr/bin/cockpit") == "/opt/cockpit/cockpit" ]] ||
  fail "launcher symlink is incorrect"
[[ -f ${package_dir}/usr/share/applications/work.jacobmoura.cockpit.desktop ]] ||
  fail "desktop file is missing"
[[ -f ${package_dir}/usr/share/metainfo/work.jacobmoura.cockpit.metainfo.xml ]] ||
  fail "AppStream metadata is missing"
[[ ! -e ${package_dir}/opt/cockpit/share ]] || fail "duplicate upstream share directory remains"
[[ $(find "${package_dir}/usr/share/icons" -type f | wc -l) -eq 5 ]] ||
  fail "expected five installed icons"
[[ -z $(ldd "$binary" | sed -n '/not found/p') ]] || fail "native dependencies are missing"

clean_build_output

if [[ $dry_run == true ]]; then
  restore_metadata
  metadata_changed=false
  [[ -z $(git status --porcelain) ]] || fail "dry-run cleanup left repository changes"
  printf 'release: dry-run passed for %s\n' "$version"
  exit 0
fi

git add PKGBUILD .SRCINFO
git diff --cached --quiet && fail "version ${version} is already committed"
git commit -m "Update to ${version}-1"
changes_committed=true
git push origin main
github_commit=$(git rev-parse --short HEAD)

printf 'release: publishing AUR metadata\n'
aur_worktree="${runtime_dir}/aur"
git worktree add "$aur_worktree" aur/master
mapfile -t aur_files < <(git -C "$aur_worktree" ls-files | sort)
[[ ${#aur_files[@]} -eq 2 && ${aur_files[0]} == ".SRCINFO" && ${aur_files[1]} == "PKGBUILD" ]] ||
  fail "AUR branch contains files other than PKGBUILD and .SRCINFO"
cp PKGBUILD .SRCINFO "$aur_worktree/"
git -C "$aur_worktree" add PKGBUILD .SRCINFO
git -C "$aur_worktree" diff --cached --quiet && fail "AUR already contains version ${version}"
git -C "$aur_worktree" commit -m "Update to ${version}-1"
aur_commit=$(git -C "$aur_worktree" rev-parse --short HEAD)
git -C "$aur_worktree" push aur HEAD:master
git worktree remove "$aur_worktree"
aur_worktree=""

[[ -z $(git status --porcelain) ]] || fail "release completed but working tree is not clean"
printf 'release: published %s-1 (GitHub %s, AUR %s)\n' "$version" "$github_commit" "$aur_commit"

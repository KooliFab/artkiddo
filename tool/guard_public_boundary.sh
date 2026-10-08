#!/usr/bin/env bash
# Guard: reject legacy domain vocabulary and public/private boundary leaks.
#
# Flag notes (each one here fixes a real way this class of guard silently
# passes without ever catching anything):
#   -P (PCRE) is required for any pattern using \b. On macOS/BSD, `git grep
#      -E` silently ignores \b and returns an empty, vacuously-passing
#      result. This already happened on this project once.
#   -i must be passed explicitly and separately from -I. They look alike but
#      do different things: -i is case-insensitivity, -I skips binary files
#      (PNG/TTF, etc. produce false matches otherwise). A typo that drops -i
#      (e.g. writing -InP instead of -inP) silently makes the whole scan
#      case-sensitive and misses every capitalized identifier (`FoyerApi`,
#      `Masterpiece`) while still exiting 0. This exact typo was made and
#      caught while building this script — see the self-test below.
#   --untracked makes newly added-but-uncommitted files visible to the scan
#      too. By default `git grep` only searches tracked content; a file
#      that has been created but not `git add`-ed is invisible to it. CI
#      checkouts are always fully tracked so this mostly matters for local,
#      pre-commit runs, but it costs nothing to include.
#
# We run BOTH a word-boundary scan and a boundary-free scan. The boundary
# scan alone misses camelCase carriers such as `topFoyersList` or `myR2Key`,
# where the forbidden token sits mid-identifier with no non-word character
# next to it. A guard that only ever uses \b would pass on exactly that kind
# of leak.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0

# Localized French UI copy is the one sanctioned home for legacy vocabulary.
L10N_EXCLUDES=(':!packages/artkiddo_core/lib/l10n/**')

# This script, the CI step that invokes it, and ADR 0007 (which documents
# the retired vocabulary by name to explain the decision) necessarily spell
# the patterns they forbid; excluding them is not a loophole, it is the same
# reasoning the backend's own guard uses for its own workflow file.
SELF_EXCLUDES=(
  ':!tool/guard_public_boundary.sh'
  ':!.github/workflows/quality.yml'
  ':!docs/adr/0007-family-artwork-vocabulary-and-clean-schema-baseline.md'
)

run() {
  local label="$1"; shift
  echo "== $label =="
  if git grep --untracked "$@"; then
    echo "FAIL: match found above" >&2
    fail=1
  else
    echo "clean"
  fi
}

run "[1/7] legacy vocabulary (word-boundary, case-insensitive)" \
  -inIP '\b(foyer|masterpiece|contributeur)' -- . "${L10N_EXCLUDES[@]}" "${SELF_EXCLUDES[@]}"

run "[2/7] legacy vocabulary (boundary-free, catches camelCase carriers)" \
  -inIE 'foyer|masterpiece|contributeur' -- . "${L10N_EXCLUDES[@]}" "${SELF_EXCLUDES[@]}"

run "[3/7] public/private boundary — vendor and sibling-repo names (word-boundary)" \
  -inIP '\b(r2|supabase|cloudflare|artkiddo-cloud|artkiddo-backend|artkiddo-web)\b' -- . "${SELF_EXCLUDES[@]}"

run "[4/7] public/private boundary (boundary-free, catches camelCase carriers)" \
  -inIE 'r2|supabase|cloudflare|artkiddo-cloud|artkiddo-backend|artkiddo-web' -- . "${SELF_EXCLUDES[@]}"

run "[5/7] private architecture vocabulary (server runtimes, hosting, sibling layout)" \
  -inIP 'edge.?functions?\b|\bdata api\b|\bastro\b|\bdeno\b|postgres|\bplpgsql\b|\brls\b|row.level.security|private backend|backend (contract|ticket|documentation)|pubspec_overrides|sibling (repo|checkout)|workspace split|firebase|\bfcm\b' \
  -- . "${SELF_EXCLUDES[@]}"

# Concrete credentials and hosted endpoints. Unlike the scans above this one
# has no ADR exclusion: no file in a public repository may hold a secret.
run "[6/7] secrets and hosted endpoints" \
  -nIP 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}|sb_(publishable|secret)_[A-Za-z0-9_-]{10,}|service_role|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|\.supabase\.co\b|r2\.cloudflarestorage\.com|\.r2\.dev\b|(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*["\x27][A-Za-z0-9_\-/+=]{16,}["\x27]' \
  -- . ':!tool/guard_public_boundary.sh'

echo "== [7/7] filenames =="
if git ls-files -z | tr '\0' '\n' | grep -inE 'foyer|masterpiece|contributeur|r2|supabase|cloudflare|artkiddo-cloud|artkiddo-backend|artkiddo-web'; then
  echo "FAIL: a tracked filename contains a legacy or vendor/sibling-repo token" >&2
  fail=1
else
  echo "clean"
fi

exit "$fail"

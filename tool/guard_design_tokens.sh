#!/usr/bin/env bash
# Guard: reject raw style values in UI code. Colors, shadows, radii and type
# sizes come from `presentation/theme/app_tokens.dart`, so a new visual style
# is a token change rather than a sweep through every screen.
#
# -P is required: on macOS/BSD `git grep -E` silently ignores \b and passes
# vacuously. --untracked also scans files that are not `git add`-ed yet.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

SCOPE=(
  'packages/artkiddo_core/lib/*.dart'
  'app/lib/*.dart'
  # The token and theme files are where these values belong.
  ':!packages/artkiddo_core/lib/src/presentation/theme/'
  # Generated localizations carry no styling.
  ':!packages/artkiddo_core/lib/l10n/'
)

# Parallel arrays rather than an associative array: macOS ships bash 3.2.
NAMES=(
  'raw color literal (use AppColors)'
  'Material black/white (use AppColors)'
  'raw font size (use AppTypography)'
  'raw radius (use AppRadii)'
)
PATTERNS=(
  '\bColor\(0x'
  '(?<![A-Za-z])Colors\.(white|black)'
  '\bfontSize:\s*\d'
  'Radius\.circular\(\d'
)
# Self-test: each pattern must match its own sample, otherwise a flag or
# escaping mistake would make the whole guard pass without checking anything.
# `git grep --no-index` keeps the same PCRE engine as the real scan (BSD
# grep has no -P).
SAMPLES=(
  'color: Color(0x33000000),'
  'color: Colors.white54,'
  'fontSize: 12,'
  'BorderRadius.circular(4),'
)
sample_dir=$(mktemp -d)
trap 'rm -rf "$sample_dir"' EXIT
for i in "${!PATTERNS[@]}"; do
  printf '%s\n' "${SAMPLES[$i]}" >"$sample_dir/sample.dart"
  if ! (cd "$sample_dir" &&
    git --no-pager grep --no-index -qP "${PATTERNS[$i]}" -- sample.dart); then
    echo "guard_design_tokens self-test failed: '${NAMES[$i]}' misses '${SAMPLES[$i]}'" >&2
    exit 2
  fi
done

fail=0
for i in "${!PATTERNS[@]}"; do
  if matches=$(git --no-pager grep -nIP --untracked "${PATTERNS[$i]}" -- "${SCOPE[@]}"); then
    echo "✗ ${NAMES[$i]}:" >&2
    echo "$matches" >&2
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "Add or reuse a token in app_tokens.dart instead of a raw value." >&2
  exit 1
fi
echo "✓ design tokens: no raw style values"

#!/usr/bin/env bash
# Build a release APK for AquaRythu.
#
# Usage:
#   ./scripts/build_release_apk.sh
#
# Required environment variables (set in your shell or CI secrets):
#   SUPABASE_URL        — your Supabase project URL
#   SUPABASE_ANON_KEY   — your Supabase publishable anon key
#   RAZORPAY_KEY_ID     — rzp_test_... (beta) or rzp_live_... (production)
#
# Example (sourcing from .env):
#   set -o allexport && source .env && set +o allexport
#   ./scripts/build_release_apk.sh

set -euo pipefail

# ── Validate required vars ────────────────────────────────────────────────────
missing=()
[[ -z "${SUPABASE_URL:-}"      ]] && missing+=("SUPABASE_URL")
[[ -z "${SUPABASE_ANON_KEY:-}" ]] && missing+=("SUPABASE_ANON_KEY")
[[ -z "${RAZORPAY_KEY_ID:-}"   ]] && missing+=("RAZORPAY_KEY_ID")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "❌  Missing required environment variables:"
  for v in "${missing[@]}"; do echo "    • $v"; done
  echo ""
  echo "    Set them in your shell or source your .env file first:"
  echo "    set -o allexport && source .env && set +o allexport"
  exit 1
fi

if [[ "$RAZORPAY_KEY_ID" == "FILL_ME_IN" ]]; then
  echo "❌  RAZORPAY_KEY_ID is still set to the placeholder value."
  echo "    Update .env with your real Razorpay key before building."
  exit 1
fi

# ── Build ─────────────────────────────────────────────────────────────────────
echo "🔨  Building release APK..."
echo "    SUPABASE_URL:    ${SUPABASE_URL}"
echo "    SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo "    RAZORPAY_KEY_ID: ${RAZORPAY_KEY_ID:0:12}..."
echo ""

flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

if [[ -f "$APK_PATH" ]]; then
  SIZE=$(du -sh "$APK_PATH" | cut -f1)
  echo ""
  echo "✅  APK ready: $APK_PATH ($SIZE)"
  echo ""
  echo "    Share via:"
  echo "    • Firebase App Distribution: firebase appdistribution:distribute $APK_PATH --app <app-id> --groups farmers-beta"
  echo "    • Direct: adb install $APK_PATH"
else
  echo "❌  Build failed — APK not found at $APK_PATH"
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Installing OTPilot..."
echo

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift was not found."
  echo "Install Xcode Command Line Tools first, then run this installer again:"
  echo
  echo "  xcode-select --install"
  echo
  read -r -p "Press Return to close this window."
  exit 1
fi

if ! command -v make >/dev/null 2>&1; then
  echo "make was not found."
  echo "Install Xcode Command Line Tools first, then run this installer again:"
  echo
  echo "  xcode-select --install"
  echo
  read -r -p "Press Return to close this window."
  exit 1
fi

make install

echo
echo "OTPilot was installed to /Applications/OTPilot.app and launched."
echo "If macOS asks for permissions, grant Full Disk Access and Accessibility as described in the README."
echo
read -r -p "Press Return to close this window."

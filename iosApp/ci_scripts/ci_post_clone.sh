#!/bin/bash
# Xcode Cloud runs this after cloning the repository, before it builds.
# Its machines have no Java, which the Kotlin `Shared` framework needs, so
# install it with Homebrew; scripts/build-shared.sh finds it there.
set -euo pipefail

# Skip Homebrew's self-update and cleanup, which take minutes on a fresh machine.
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
brew install openjdk@21

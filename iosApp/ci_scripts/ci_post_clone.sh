#!/bin/bash
# Xcode Cloud runs this after cloning the repository, before it builds.
# Its machines have no Java, which the Kotlin `Shared` framework needs, so
# install it with Homebrew; scripts/build-shared.sh finds it there.
set -euo pipefail

brew install openjdk@21

#!/bin/bash
# Builds the Kotlin `Shared` framework for Xcode.
# Xcode's build scripts don't inherit your Terminal's environment, so this
# finds Java itself and explains what to install when something is missing.
set -euo pipefail

find_java() {
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    return 0
  fi
  local home
  if home="$(/usr/libexec/java_home 2>/dev/null)" && [ -x "$home/bin/java" ]; then
    export JAVA_HOME="$home"
    return 0
  fi
  # Homebrew's openjdk formula isn't registered with java_home.
  for prefix in /opt/homebrew/opt /usr/local/opt; do
    for name in openjdk@21 openjdk@17 openjdk; do
      home="$prefix/$name/libexec/openjdk.jdk/Contents/Home"
      if [ -x "$home/bin/java" ]; then
        export JAVA_HOME="$home"
        return 0
      fi
    done
  done
  return 1
}

if ! find_java; then
  echo "error: TaskWall needs Java 17 or newer to build its shared Kotlin code. Install it with 'brew install --cask temurin', then restart Xcode."
  exit 1
fi
echo "Using Java at $JAVA_HOME"

if [ "$(xcode-select -p 2>/dev/null)" = "/Library/Developer/CommandLineTools" ]; then
  echo "error: Kotlin needs the full Xcode, but xcode-select points at the Command Line Tools. Run 'sudo xcode-select -s /Applications/Xcode.app' and build again."
  exit 1
fi

cd "$SRCROOT/.."
./gradlew :shared:embedAndSignAppleFrameworkForXcode

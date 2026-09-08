#!/usr/bin/env bash
# Prefer JDK 21 for Android builds; JDK 23 can trigger javac bugs with CameraX.

configure_java_home() {
  for candidate in \
    "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home" \
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" \
    "/Library/Java/JavaVirtualMachines/jdk-23.jdk/Contents/Home" \
    "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"; do
    if [[ -d "$candidate" ]]; then
      export JAVA_HOME="$candidate"
      flutter config --jdk-dir="$JAVA_HOME" >/dev/null
      echo "JAVA_HOME=$JAVA_HOME"
      return 0
    fi
  done
  echo "No JDK 17/21/23 found. Install one or set JAVA_HOME manually." >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_java_home
  exit $?
fi

configure_java_home

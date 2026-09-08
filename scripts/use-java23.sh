#!/usr/bin/env bash
# Prefer JDK 17–23; Android Studio's Java 25 breaks Kotlin ("25.0.2" error).

configure_java_home() {
  for candidate in \
    "/Library/Java/JavaVirtualMachines/jdk-23.jdk/Contents/Home" \
    "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home" \
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

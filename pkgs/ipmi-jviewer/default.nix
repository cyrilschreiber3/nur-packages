{
  bash,
  coreutils,
  curl,
  gnused,
  gawk,
  libxml2,
  zip,
  python3,
  jdk8_headless,
  adoptopenjdk-icedtea-web,
  writeShellApplication,
}: let
  runtime = [
    bash
    coreutils
    curl
    gnused
    gawk
    libxml2
    zip
    python3
    jdk8_headless
    adoptopenjdk-icedtea-web
  ];
in
  writeShellApplication {
    name = "ipmi-jviewer";
    runtimeInputs = runtime;

    text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          usage() {
            cat <<EOF
      Usage:
        ipmi-jviewer /path/to/jviewer.jnlp [port]

      Env (optional):
        FORCE_HTTP_REMOTE=true|false   (default: true)
        COOKIE_NAME=SessionCookie      (default: SessionCookie)
        CERT_ALIAS=ipmi-local          (default: ipmi-local)
        KEYSTORE_PASS=changeit         (default: changeit)
        KEY_PASS=changeit              (default: changeit)
        USER_AGENT="Mozilla/5.0"       (default: Mozilla/5.0)
      EOF
          }

          if [[ $# -lt 1 ]]; then
            usage
            exit 1
          fi

          JNLP_INPUT="$(readlink -f "$1")"
          PORT="''${2:-8000}"

          [[ -f "$JNLP_INPUT" ]] || { echo "JNLP not found: $JNLP_INPUT"; exit 1; }

          FORCE_HTTP_REMOTE="''${FORCE_HTTP_REMOTE:-true}"
          COOKIE_NAME="''${COOKIE_NAME:-SessionCookie}"
          CERT_ALIAS="''${CERT_ALIAS:-ipmi-local}"
          KEYSTORE_PASS="''${KEYSTORE_PASS:-changeit}"
          KEY_PASS="''${KEY_PASS:-changeit}"
          USER_AGENT="''${USER_AGENT:-Mozilla/5.0}"

          for cmd in xmllint curl keytool jarsigner zip python3 sed awk java javaws; do
            command -v "$cmd" >/dev/null 2>&1 || { echo "Missing command: $cmd"; exit 1; }
          done

          WORKDIR="$(mktemp -d /tmp/ipmi-jviewer.XXXXXX)"
          HTTP_PID=""

          cleanup() {
            if [[ -n "$HTTP_PID" ]]; then
              kill "$HTTP_PID" >/dev/null 2>&1 || true
            fi
            rm -rf "$WORKDIR"
          }
          trap cleanup EXIT INT TERM

          cp "$JNLP_INPUT" "$WORKDIR/original.jnlp"

          CODEBASE="$(xmllint --xpath 'string(/jnlp/@codebase)' "$WORKDIR/original.jnlp" 2>/dev/null || true)"
          [[ -n "$CODEBASE" ]] || { echo "Could not parse @codebase in JNLP"; exit 1; }

          REMOTE_CODEBASE="$CODEBASE"
          if [[ "$FORCE_HTTP_REMOTE" == "true" ]]; then
            REMOTE_CODEBASE="$(echo "$REMOTE_CODEBASE" | sed -E 's#^https://#http://#')"
          fi

          SESSION_TOKEN="$(xmllint --xpath 'string((/jnlp/application-desc/argument)[last()])' "$WORKDIR/original.jnlp" 2>/dev/null || true)"
          [[ -n "$SESSION_TOKEN" ]] || { echo "Could not extract session token from last <argument>"; exit 1; }

          echo "[*] JNLP codebase:  $CODEBASE"
          echo "[*] Remote base:    $REMOTE_CODEBASE"
          echo "[*] Cookie:         $COOKIE_NAME=<redacted>"
          echo "[*] Temp dir:       $WORKDIR"

          # Detect OS/arch and map to typical JNLP values
          UOS="$(uname -s)"
          UARCH="$(uname -m)"

          case "$UOS" in
            Linux)   JNLP_OS_CSV="Linux" ;;
            Darwin)  JNLP_OS_CSV="Mac OS X" ;;
            MINGW*|MSYS*|CYGWIN*|Windows_NT) JNLP_OS_CSV="Windows" ;;
            *)       JNLP_OS_CSV="$UOS" ;;
          esac

          case "$UARCH" in
            x86_64|amd64) JNLP_ARCH_CSV="x86_64,amd64" ;;
            i386|i486|i586|i686) JNLP_ARCH_CSV="x86,i386" ;;
            aarch64|arm64) JNLP_ARCH_CSV="aarch64,arm64" ;;
            armv7l|armv6l) JNLP_ARCH_CSV="arm" ;;
            *) JNLP_ARCH_CSV="$UARCH" ;;
          esac

          echo "[*] Host mapped to JNLP os=$JNLP_OS_CSV arch=$JNLP_ARCH_CSV"

          # Resolve needed hrefs (common + matching os/arch resources)
          HREFS_FILE="$WORKDIR/needed_hrefs.txt"
          python3 - "$WORKDIR/original.jnlp" "$HREFS_FILE" "$JNLP_OS_CSV" "$JNLP_ARCH_CSV" <<'PY'
      import sys, xml.etree.ElementTree as ET

      jnlp_path, out_path, os_csv, arch_csv = sys.argv[1:]
      os_set = set([x for x in os_csv.split(",") if x])
      arch_set = set([x for x in arch_csv.split(",") if x])

      root = ET.parse(jnlp_path).getroot()

      def get_attr(el, name):
          return (el.attrib.get(name) or "").strip()

      hrefs = []

      for res in root.findall("resources"):
          ros = get_attr(res, "os")
          rarch = get_attr(res, "arch")

          os_ok = (ros == "" or ros in os_set)
          arch_ok = (rarch == "" or rarch in arch_set)

          if os_ok and arch_ok:
              for tag in ("jar", "nativelib"):
                  for n in res.findall(tag):
                      href = get_attr(n, "href")
                      if href:
                          hrefs.append(href)

      seen = set()
      uniq = []
      for h in hrefs:
          if h not in seen:
              seen.add(h)
              uniq.append(h)

      with open(out_path, "w", encoding="utf-8") as f:
          for h in uniq:
              f.write(h + "\n")
      PY

          mapfile -t HREFS < "$HREFS_FILE"
          [[ "''${#HREFS[@]}" -gt 0 ]] || { echo "No matching jar/nativelib hrefs found in JNLP"; exit 1; }

          echo "[*] Need ''${#HREFS[@]} artifact(s)"
          for h in "''${HREFS[@]}"; do
            echo "    - $h"
          done

          # Download only needed artifacts
          for href in "''${HREFS[@]}"; do
            url="''${REMOTE_CODEBASE%/}/$href"
            out="$WORKDIR/$href"
            mkdir -p "$(dirname "$out")"

            echo "[*] Downloading $url"
            curl --fail --location --silent --show-error \
              --user-agent "$USER_AGENT" \
              -H "Cookie: $COOKIE_NAME=$SESSION_TOKEN" \
              "$url" -o "$out" || {
                echo "Failed downloading: $url"
                echo "Token may be expired; regenerate JNLP from active IPMI session."
                exit 1
              }
          done

          # Generate local signing cert
          KEYSTORE="$WORKDIR/ipmi-keystore.jks"
          CERT_PEM="$WORKDIR/ipmi-local.crt"

          keytool -genkeypair \
            -alias "$CERT_ALIAS" \
            -keyalg RSA -keysize 2048 -validity 3650 \
            -keystore "$KEYSTORE" \
            -storepass "$KEYSTORE_PASS" \
            -keypass "$KEY_PASS" \
            -dname "CN=IPMI Local, OU=Lab, O=Lab, L=Lab, ST=Lab, C=US" \
            -noprompt >/dev/null

          keytool -exportcert \
            -alias "$CERT_ALIAS" \
            -keystore "$KEYSTORE" \
            -storepass "$KEYSTORE_PASS" \
            -rfc \
            -file "$CERT_PEM" >/dev/null

          # Re-sign jars
          mapfile -t JARS < <(find "$WORKDIR" -type f -name '*.jar' | sort)
          [[ "''${#JARS[@]}" -gt 0 ]] || { echo "No jars downloaded"; exit 1; }

          echo "[*] Re-signing ''${#JARS[@]} jar(s)"
          for jar in "''${JARS[@]}"; do
            zip -d "$jar" 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA' >/dev/null 2>&1 || true
            jarsigner \
              -keystore "$KEYSTORE" \
              -storepass "$KEYSTORE_PASS" \
              -keypass "$KEY_PASS" \
              -sigalg SHA256withRSA \
              -digestalg SHA-256 \
              "$jar" "$CERT_ALIAS" >/dev/null
          done

          echo "[*] Verifying signatures"
          for jar in "''${JARS[@]}"; do
            jarsigner -verify -verbose -certs "$jar" >/dev/null || {
              echo "Signature verification failed: $jar"
              exit 1
            }
          done

          # Build temporary truststore from current java cacerts
          JAVA_BIN="$(readlink -f "$(command -v java)")"
          JAVA_HOME_GUESS="$(dirname "$(dirname "$JAVA_BIN")")"

          DEFAULT_CACERTS=""
          for p in \
            "$JAVA_HOME_GUESS/lib/security/cacerts" \
            "$JAVA_HOME_GUESS/jre/lib/security/cacerts"
          do
            [[ -f "$p" ]] && DEFAULT_CACERTS="$p" && break
          done
          [[ -n "$DEFAULT_CACERTS" ]] || { echo "Could not locate default cacerts"; exit 1; }

          TRUSTSTORE="$WORKDIR/cacerts.local"
          cp "$DEFAULT_CACERTS" "$TRUSTSTORE"
          chmod +w "$TRUSTSTORE"

          keytool -importcert \
            -alias "$CERT_ALIAS" \
            -file "$CERT_PEM" \
            -keystore "$TRUSTSTORE" \
            -storepass changeit \
            -noprompt >/dev/null

          # Patch JNLP to local codebase
          LOCAL_CODEBASE="http://127.0.0.1:$PORT"
          JNLP_LOCAL="$WORKDIR/launch.local.jnlp"
          sed -E "s#codebase=\"[^\"]+\"#codebase=\"$LOCAL_CODEBASE\"#g" \
            "$WORKDIR/original.jnlp" > "$JNLP_LOCAL"

          # Serve local files
          (
            cd "$WORKDIR"
            python3 -m http.server "$PORT" >/dev/null 2>&1
          ) &
          HTTP_PID="$!"
          sleep 1

          echo "[*] Launching javaws"
          exec javaws \
            -J-Djavax.net.ssl.trustStore="$TRUSTSTORE" \
            -J-Djavax.net.ssl.trustStorePassword=changeit \
            "$JNLP_LOCAL"
    '';
  }

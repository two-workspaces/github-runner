#!/bin/bash
# Railway entrypoint for a GitHub Actions self-hosted runner. Starts as root to fix the
# volume's owner, registers the runner once, keeps its registration on the volume, and
# runs it as the runner user.
set -uo pipefail
say() { echo "[railway] $*"; }

# A problem the user has to fix: log it, and keep logging it, instead of exiting.
# A crash loop restarts ten times, then leaves a dead deploy with the reason buried.
idle() {
  say "$1"
  while true; do sleep 3600 & wait $!; say "$1"; done
}

home=/home/runner
state=/runner-state
mkdir -p "$state"
chown runner:runner "$state"
files=".runner .credentials .credentials_rsaparams"

url=${GITHUB_URL:-}
url=${url%/}; url=${url%.git}
name=${RUNNER_NAME:-railway-${RAILWAY_SERVICE_ID:0:8}}
labels=${RUNNER_LABELS:-railway}
pat=${GITHUB_PAT:-}
regtoken=${RUNNER_TOKEN:-}

# Jobs inherit the runner's environment, so every workflow step could read these.
# Keep them in shell variables only.
unset GITHUB_PAT RUNNER_TOKEN
# The official image copies the runner's debug log to stdout, dozens of lines a minute,
# which buries the job lines in Railway's logs. The full log stays in /home/runner/_diag.
unset ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT

if [[ ! $url =~ ^https://[^/]+/[^/]+(/[^/]+)?$ ]]; then
  idle "Set GITHUB_URL to the repository (https://github.com/OWNER/REPO) or organization (https://github.com/ORG) this runner serves, then redeploy."
fi

# Ask GitHub for a registration token with the personal access token.
mint_token() {
  local host path api scope
  host=${url#https://}; host=${host%%/*}
  path=${url#https://$host/}
  if [ "$host" = github.com ]; then api=https://api.github.com; else api=https://$host/api/v3; fi
  if [[ $path == */* ]]; then scope=repos/$path; else scope=orgs/$path; fi
  curl -fsS -X POST -H "Authorization: Bearer $pat" -H "Accept: application/vnd.github+json" \
    "$api/$scope/actions/runners/registration-token" | jq -r .token
}

configured() {
  [ -f "$home/.runner" ] && [ "$(jq -r .gitHubUrl "$home/.runner" 2>/dev/null)" = "$url" ]
}

restore() { for f in $files; do [ -f "$state/$f" ] && cp -p "$state/$f" "$home/$f"; done; }
save() { for f in $files; do [ -f "$home/$f" ] && cp -p "$home/$f" "$state/$f"; done; }
forget() { for f in $files; do rm -f "$home/$f" "$state/$f"; done; }

as_runner() {
  setpriv --reuid=runner --regid=runner --init-groups env HOME="$home" "$@"
}

register() {
  local token=$regtoken
  if [ -n "$pat" ]; then
    token=$(mint_token) || token=
    if [ -z "$token" ] || [ "$token" = null ]; then
      say "GitHub refused GITHUB_PAT for $url. It needs repository Administration (read and write), or for an organization, Self-hosted runners (read and write)."
      return 1
    fi
  fi
  if [ -z "$token" ]; then
    idle "This runner isn't registered (or it was removed on GitHub). Set GITHUB_PAT (a token that can manage runners; it lets the runner register itself again whenever needed), or RUNNER_TOKEN (from Settings > Actions > Runners > New self-hosted runner; it expires in an hour), then redeploy."
  fi
  say "registering runner $name for $url with labels: $labels"
  local group=()
  [ -n "${RUNNER_GROUP:-}" ] && group=(--runnergroup "$RUNNER_GROUP")
  (cd "$home" && as_runner ./config.sh --unattended --replace --url "$url" --token "$token" \
    --name "$name" --labels "$labels" --work _work "${group[@]}") || return 1
  save
}

runner=
stopping=
trap 'stopping=1; [ -n "$runner" ] && kill -TERM "$runner" 2>/dev/null' TERM INT

restore
delay=30
while true; do
  if ! configured; then
    forget
    if ! register; then
      if [ -z "$pat" ]; then
        idle "Registration failed (the reason is above). RUNNER_TOKEN expires an hour after GitHub shows it: make a new one, or set GITHUB_PAT instead, and redeploy."
      fi
      say "Retrying in $delay seconds."; sleep "$delay" & wait $!
      [ -n "$stopping" ] && exit 0
      delay=$((delay * 2)); [ $delay -gt 900 ] && delay=900
      continue
    fi
  fi
  delay=30

  log=/tmp/runner.log
  (cd "$home" && exec setpriv --reuid=runner --regid=runner --init-groups env HOME="$home" ./run.sh) \
    > >(tee "$log") 2>&1 &
  runner=$!
  rc=0
  wait "$runner" || rc=$?
  wait "$runner" 2>/dev/null || true
  [ -n "$stopping" ] && exit 0

  say "the runner stopped (exit $rc)."
  if grep -qiE "registration has been deleted|runner .* not found|was not found|not configured" "$log"; then
    say "GitHub no longer knows this runner (it was removed in Settings > Actions > Runners)."
    forget
  fi
  sleep 10 & wait $!
  [ -n "$stopping" ] && exit 0
done

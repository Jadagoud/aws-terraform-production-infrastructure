#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

CONTAINER="devops-backend"
CANDIDATE="devops-backend-candidate"
ROLLBACK="devops-backend-rollback"
NETWORK="aws-terraform-production-infrastructure_devops-network"
STATE_DIR="/opt/devops-deploy"
IMAGE="${DEPLOY_IMAGE:?Set DEPLOY_IMAGE to an immutable ECR digest URI}"
WORK_DIR=""
SWITCH_STARTED=0
DEPLOY_SUCCEEDED=0
OLD_DISCONNECTED=0

health_check() {
    local url="$1" attempt status
    for attempt in $(seq 1 30); do
        status="$(curl -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
        [[ "$status" == "200" ]] && return 0
        sleep 2
    done
    return 1
}

exists() { docker inspect "$1" >/dev/null 2>&1; }
running() { [[ "$(docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]; }

cleanup() {
    local rc=$? rollback_rc=0
    trap - EXIT
    set +e

    if [[ "$SWITCH_STARTED" == "1" && "$DEPLOY_SUCCEEDED" != "1" ]]; then
        echo "Deployment failed; attempting rollback."
        if exists "$ROLLBACK"; then
            if exists "$CONTAINER"; then
                docker rm -f "$CONTAINER" >/dev/null 2>&1
                exists "$CONTAINER" && rollback_rc=2
            fi
            if [[ "$rollback_rc" == "0" ]] && ! exists "$CONTAINER"; then
                docker rename "$ROLLBACK" "$CONTAINER" || rollback_rc=2
            fi
            if [[ "$rollback_rc" == "0" ]] && exists "$CONTAINER"; then
                if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
                    echo "CRITICAL: expected Docker network is missing."
                    rollback_rc=2
                else
                    docker network connect --alias backend --alias devops-backend "$NETWORK" "$CONTAINER" >/dev/null 2>&1 || true
                    docker start "$CONTAINER" >/dev/null || rollback_rc=2
                    if [[ "$rollback_rc" == "0" ]] && health_check "http://127.0.0.1:5001/api/health"; then
                        echo "Rollback health check passed."
                    else
                        echo "CRITICAL: rollback backend is not healthy."
                        rollback_rc=2
                    fi
                fi
            fi
        elif exists "$CONTAINER"; then
            # If switching failed before the old container was renamed, preserve it.
            if [[ "$OLD_DISCONNECTED" == "1" ]]; then
                docker network connect --alias backend --alias devops-backend "$NETWORK" "$CONTAINER" >/dev/null 2>&1 || true
            fi
            if ! running "$CONTAINER"; then
                docker start "$CONTAINER" >/dev/null || rollback_rc=2
            fi
            if [[ "$rollback_rc" == "0" ]] && ! health_check "http://127.0.0.1:5001/api/health"; then
                echo "CRITICAL: backend is not healthy after recovery."
                rollback_rc=2
            fi
        else
            echo "CRITICAL: no recoverable backend container was found."
            rollback_rc=2
        fi
    fi

    if exists "$CANDIDATE"; then docker rm -f "$CANDIDATE" >/dev/null 2>&1; fi
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then rm -rf "$WORK_DIR"; fi
    [[ "$rollback_rc" == "0" ]] || rc=2
    exit "$rc"
}
trap cleanup EXIT

[[ "$(id -u)" == "0" ]] || { echo "ERROR: run as root."; exit 1; }
[[ -d "$STATE_DIR" ]] || { echo "ERROR: deployment directory missing."; exit 1; }
[[ "$IMAGE" =~ ^451782721795\.dkr\.ecr\.eu-north-1\.amazonaws\.com/devops-backend@sha256:[a-f0-9]{64}$ ]] || {
    echo "ERROR: image must be an immutable digest in the expected ECR repository."
    exit 1
}

exec 9>"$STATE_DIR/deploy.lock"
flock -n 9 || { echo "ERROR: another deployment is running."; exit 1; }

exists "$CONTAINER" || { echo "ERROR: current backend container is missing."; exit 1; }
exists "$CANDIDATE" && { echo "ERROR: candidate container already exists; inspect it first."; exit 1; }
docker network inspect "$NETWORK" >/dev/null 2>&1 || { echo "ERROR: expected Docker network is missing."; exit 1; }
health_check "http://127.0.0.1:5001/api/health" || {
    echo "ERROR: current backend is unhealthy; refusing deployment."
    exit 1
}
exists "$ROLLBACK" && { echo "ERROR: rollback container already exists; inspect it before deploying."; exit 1; }

WORK_DIR="$(mktemp -d "$STATE_DIR/run.XXXXXX")"
chmod 700 "$WORK_DIR"
docker inspect "$CONTAINER" > "$WORK_DIR/container.json"
chmod 600 "$WORK_DIR/container.json"

python3 - "$WORK_DIR/container.json" "$NETWORK" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    c = json.load(f)[0]
expected = sys.argv[2]
if c.get("Mounts"):
    raise SystemExit("ERROR: current container has mounts; manual review required.")
if c["HostConfig"].get("Binds"):
    raise SystemExit("ERROR: bind mounts detected; manual review required.")
if expected not in c.get("NetworkSettings", {}).get("Networks", {}):
    raise SystemExit("ERROR: current backend is not attached to the expected Docker network.")
bindings = c.get("HostConfig", {}).get("PortBindings", {}).get("5000/tcp", [])
if not any(b.get("HostPort") == "5001" for b in bindings):
    raise SystemExit("ERROR: current backend is not mapped to host port 5001.")
PY

python3 - "$WORK_DIR/container.json" "$WORK_DIR/env.list" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    c = json.load(f)[0]
with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
    for item in c["Config"].get("Env", []):
        if "\n" in item or "\r" in item:
            raise SystemExit("ERROR: multiline environment values are unsupported.")
        f.write(item + "\n")
PY
chmod 600 "$WORK_DIR/env.list"

echo "Pulling immutable image..."
docker pull "$IMAGE" >/dev/null
NEW_IMAGE_ID="$(docker image inspect --format '{{.Id}}' "$IMAGE")"
OLD_IMAGE_ID="$(docker inspect --format '{{.Image}}' "$CONTAINER")"
if [[ "$NEW_IMAGE_ID" == "$OLD_IMAGE_ID" ]]; then
    echo "Backend already uses this image; no deployment needed."
    exit 0
fi

echo "Starting candidate on localhost port 15001 on the production Docker network..."
docker run -d --name "$CANDIDATE" \
    --network "$NETWORK" \
    --env-file "$WORK_DIR/env.list" \
    -p 127.0.0.1:15001:5000 "$NEW_IMAGE_ID" >/dev/null

health_check "http://127.0.0.1:15001/api/health" || {
    echo "ERROR: candidate health check failed; production unchanged."
    exit 1
}
# Also verify the DB-backed route before switching production.
health_check "http://127.0.0.1:15001/api/users" || {
    echo "ERROR: candidate API/database check failed; production unchanged."
    exit 1
}
docker rm -f "$CANDIDATE" >/dev/null

echo "Candidate passed health and API checks. Switching production..."
SWITCH_STARTED=1
docker stop "$CONTAINER" >/dev/null
docker network disconnect "$NETWORK" "$CONTAINER"
OLD_DISCONNECTED=1
docker rename "$CONTAINER" "$ROLLBACK"

docker run -d --name "$CONTAINER" \
    --network "$NETWORK" \
    --network-alias backend \
    --network-alias devops-backend \
    --restart unless-stopped \
    --env-file "$WORK_DIR/env.list" \
    -p 5001:5000 "$NEW_IMAGE_ID" >/dev/null

health_check "http://127.0.0.1:5001/api/health" || {
    echo "ERROR: new production backend failed health check."
    exit 1
}
health_check "http://127.0.0.1:5001/api/users" || {
    echo "ERROR: new production API/database check failed."
    exit 1
}

DEPLOY_SUCCEEDED=1
echo "Deployment succeeded. Previous container retained as $ROLLBACK."

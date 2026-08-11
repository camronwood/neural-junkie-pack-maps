#!/usr/bin/env bash
# Smoke: spin sidecar, geocode Millennium Park, walk-route to Art Institute.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}/assets/hub"
PORT="${NJ_MAPS_SMOKE_PORT:-18765}"
export NJ_PACK_ID=maps
export NJ_PACK_DIR="${ROOT}"
export NJ_PACK_SETTINGS_JSON='{"nominatim_base_url":"https://nominatim.openstreetmap.org","osrm_base_url":"https://router.project-osrm.org","maps_user_agent":"NeuralJunkieMapsSmoke/1.0","maps_rate_limit_rps":"1"}'

python3 server.py --port "${PORT}" &
PID=$!
cleanup() { kill "${PID}" 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 30); do
  if python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT}/health', timeout=1)" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

python3 - <<PY
import json, urllib.request

base = "http://127.0.0.1:${PORT}"

def post(path, body):
    req = urllib.request.Request(
        base + path,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "NeuralJunkieMapsSmoke/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        return json.load(resp)

geo_a = post("/api/maps/geocode", {"query": "Millennium Park, Chicago", "limit": 1})
geo_b = post("/api/maps/geocode", {"query": "Art Institute of Chicago", "limit": 1})
assert geo_a.get("results"), "geocode A empty"
assert geo_b.get("results"), "geocode B empty"
a, b = geo_a["results"][0], geo_b["results"][0]
route = post("/api/maps/route", {
    "mode": "walking",
    "waypoints": [
        {"lat": a["lat"], "lon": a["lon"]},
        {"lat": b["lat"], "lon": b["lon"]},
    ],
})
assert route.get("geometry", {}).get("coordinates"), "missing route geometry"
assert float(route.get("distance_m") or 0) > 0, "distance_m expected"
rev = post("/api/maps/reverse", {"lat": a["lat"], "lon": a["lon"]})
assert rev.get("display_name"), "reverse geocode missing display_name"
biased = post("/api/maps/geocode", {
    "query": "coffee",
    "limit": 1,
    "near": {"lat": a["lat"], "lon": a["lon"]},
})
assert biased.get("results"), "biased geocode empty"
print("OK maps smoke", round(float(route["distance_m"])), "m", route.get("mode"), rev.get("display_name", "")[:48])
PY

#!/usr/bin/env python3
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SOURCES = {"youtubeMusic", "youtube", "plex", "spotify", "ownFiles"}
VALID_ENGINES = {"webEmbed", "nativeAV", "connectRemote", "none"}
VALID_ROUTES = {"native", "visibleWebPlayer", "connectRemote", "blocked"}
VALID_STATES = {"idle", "loading", "playing", "paused", "ended", "blocked", "failed"}


def fail(message: str) -> None:
    print(f"CONTRACT-CHECK: FAIL {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path):
    try:
        return json.loads(path.read_text())
    except Exception as error:
        fail(f"{path}: {error}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def check_provider_policy() -> None:
    policy = load_json(ROOT / "contracts/provider-policy.json")
    sources = set(policy.get("sources", {}).keys())
    require(sources == EXPECTED_SOURCES, f"provider-policy sources mismatch: {sorted(sources)}")
    for source, values in policy["sources"].items():
        for key in ["metadata", "playback", "downloads", "nativeSystemNowPlaying"]:
            require(key in values, f"provider-policy {source} missing {key}")
        require(isinstance(values["nativeSystemNowPlaying"], bool), f"provider-policy {source} nativeSystemNowPlaying must be boolean")
    require(policy["sources"]["plex"]["nativeSystemNowPlaying"] is True, "Plex must own native system Now Playing")
    require(policy["sources"]["ownFiles"]["nativeSystemNowPlaying"] is True, "Own Files must own native system Now Playing")
    for source in ["youtubeMusic", "youtube", "spotify"]:
        require(policy["sources"][source]["nativeSystemNowPlaying"] is False, f"{source} must not own system Now Playing")


def check_route_decision(decision: dict, context: str) -> None:
    for key in ["route", "engine", "plan", "systemIntegration", "requiresVisiblePlayer", "canOwnSystemNowPlaying", "blockedState"]:
        require(key in decision, f"{context} routeDecision missing {key}")
    route = decision["route"]
    engine = decision["engine"]
    require(route in VALID_ROUTES, f"{context} invalid route {route}")
    require(engine in VALID_ENGINES, f"{context} invalid engine {engine}")

    plan = decision["plan"]
    require("kind" in plan and "policy" in plan, f"{context} plan missing kind/policy")
    integration = decision["systemIntegration"]
    require("kind" in integration and "canOwnSystemNowPlaying" in integration, f"{context} systemIntegration missing fields")
    require(decision["canOwnSystemNowPlaying"] == integration["canOwnSystemNowPlaying"], f"{context} ownership mismatch")

    if engine == "nativeAV":
        require(route == "native", f"{context} nativeAV must use native route")
        require(decision["requiresVisiblePlayer"] is False, f"{context} nativeAV must not require visible player")
        require(decision["canOwnSystemNowPlaying"] is True, f"{context} nativeAV must own system Now Playing")
        require(decision["blockedState"] is None, f"{context} nativeAV must not be blocked")
    elif engine == "webEmbed":
        require(route == "visibleWebPlayer", f"{context} webEmbed must use visibleWebPlayer route")
        require(decision["requiresVisiblePlayer"] is True, f"{context} webEmbed must require visible player")
        require(decision["canOwnSystemNowPlaying"] is False, f"{context} webEmbed must not own system Now Playing")
        require(decision["blockedState"] is not None, f"{context} webEmbed must carry blocked handoff evidence")
    elif engine == "none":
        require(route == "blocked", f"{context} none engine must be blocked route")
        require(decision["canOwnSystemNowPlaying"] is False, f"{context} none engine must not own system Now Playing")
        require(decision["blockedState"] is not None, f"{context} blocked route must carry blockedState")


def check_playback_fixture(path: Path) -> None:
    fixture = load_json(path)
    require(fixture.get("version") == 1, f"{path} version must be 1")
    session = fixture.get("session")
    require(isinstance(session, dict), f"{path} missing session")
    state = session.get("state", {})
    require(state.get("kind") in VALID_STATES, f"{path} invalid state kind {state.get('kind')}")
    queue = session.get("queue", {})
    items = queue.get("items", [])
    current_index = queue.get("currentIndex")
    require(isinstance(items, list), f"{path} queue items must be array")
    if current_index is not None:
        require(isinstance(current_index, int), f"{path} currentIndex must be integer or null")
        require(0 <= current_index < len(items), f"{path} currentIndex out of range")

    active = session.get("activeRouteDecision")
    if active is not None:
        check_route_decision(active, f"{path} active")
    for item in items:
        track = item.get("track", {})
        require(track.get("source") in EXPECTED_SOURCES, f"{path} invalid track source {track.get('source')}")
        check_route_decision(item.get("routeDecision", {}), f"{path} item {item.get('id')}")


def main() -> int:
    for path in [
        ROOT / "contracts/playback-session.schema.json",
        ROOT / "contracts/source-capabilities.schema.json",
        ROOT / "contracts/provider-policy.json",
    ]:
        load_json(path)
    check_provider_policy()
    fixtures = sorted((ROOT / "contracts/fixtures/playback").glob("*.json"))
    require(bool(fixtures), "missing playback fixtures")
    for fixture in fixtures:
        check_playback_fixture(fixture)
    print(f"CONTRACT-CHECK: PASS ({len(fixtures)} playback fixtures)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""
Integration tests for /v1/agent/run endpoint.
Requires LITELLM_KEY env var. Port-forward is managed by the session fixture.
"""
import os
import socket
import subprocess
import time
import pytest
import httpx

BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8080")
AUTH_KEY = os.getenv("LITELLM_KEY", "")


def _port_is_bound(port: int) -> bool:
    """Return True if something is already listening on localhost:port."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1)
        return s.connect_ex(("127.0.0.1", port)) == 0


@pytest.fixture(scope="session", autouse=True)
def port_forward():
    """Ensure a working port-forward for the test session."""
    if os.getenv("SKIP_PORT_FORWARD"):
        yield
        return

    # Kill any stale kubectl port-forwards on 8080
    subprocess.run(
        ["pkill", "-f", "kubectl port-forward svc/api-gateway"],
        capture_output=True,
    )
    time.sleep(1)

    proc = subprocess.Popen(
        ["kubectl", "port-forward", "svc/api-gateway", "-n", "agentic", "8080:80"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Wait up to 10s for port to become available
    for _ in range(10):
        if _port_is_bound(8080):
            break
        time.sleep(1)
    else:
        proc.terminate()
        pytest.exit("port-forward failed to bind on :8080 after 10s", returncode=1)

    yield

    proc.terminate()
    proc.wait(timeout=5)


@pytest.fixture
def client():
    return httpx.Client(
        base_url=BASE_URL,
        headers={"Authorization": f"Bearer {AUTH_KEY}"},
        timeout=60.0,
    )


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["db"] == "ok"


def test_agent_run_basic(client):
    r = client.post("/v1/agent/run", json={
        "agent_id": "default-agent",
        "model": "gemini-flash",
        "query": "What is 2+2?",
    })
    assert r.status_code == 200, f"Unexpected status: {r.status_code} — {r.text}"
    data = r.json()
    assert "answer" in data
    assert "trace_id" in data
    assert data["total_tokens"] > 0
    assert data["total_cost_usd"] >= 0.0
    assert data["iterations"] >= 1


def test_agent_run_no_auth():
    r = httpx.post(f"{BASE_URL}/v1/agent/run", json={
        "agent_id": "default-agent",
        "model": "gemini-flash",
        "query": "Hello",
    })
    assert r.status_code == 401


def test_agent_run_missing_query(client):
    r = client.post("/v1/agent/run", json={
        "agent_id": "default-agent",
        "model": "gemini-flash",
    })
    assert r.status_code == 422


def test_models_endpoint(client):
    r = client.get("/v1/models")
    assert r.status_code == 200
    data = r.json()
    model_ids = [m["id"] for m in data["data"]]
    assert "gemini-flash" in model_ids

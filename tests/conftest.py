"""
Shared pytest fixtures for the serverless-agentic-platform test suite.

DB fixtures connect through the Cloud SQL Auth Proxy (localhost:5433).
Set env vars to override defaults:
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
Skip DB tests entirely with: SKIP_DB_TESTS=1
"""
import os
import uuid
from datetime import datetime, timezone

import psycopg2
import psycopg2.extras
import pytest

# ---------------------------------------------------------------------------
# Connection defaults — match the running proxy / Cloud SQL instance
# ---------------------------------------------------------------------------
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "5433"))
DB_NAME = os.getenv("DB_NAME", "litellm")
DB_USER = os.getenv("DB_USER", "litellm-user")
DB_PASSWORD = os.getenv(
    "DB_PASSWORD",
    "pIkQQlxnEMtUAFwJfqYiRyRsjPxfm9x7tNbrwvx1",
)


def _skip_if_no_db():
    if os.getenv("SKIP_DB_TESTS"):
        pytest.skip("SKIP_DB_TESTS is set")


# ---------------------------------------------------------------------------
# Session-scoped connection — one connection for the whole test run
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def db_conn():
    """
    Psycopg2 connection to litellm-db via the Cloud SQL Auth Proxy.
    Autocommit is OFF; each test fixture manages its own transaction.
    Skipped when SKIP_DB_TESTS=1 or when the proxy is unreachable.
    """
    _skip_if_no_db()
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5,
            cursor_factory=psycopg2.extras.RealDictCursor,
        )
    except psycopg2.OperationalError as exc:
        pytest.skip(f"Cannot reach DB proxy ({DB_HOST}:{DB_PORT}): {exc}")

    conn.autocommit = False
    yield conn
    conn.close()


# ---------------------------------------------------------------------------
# Function-scoped agent_budget row — inserted before, deleted after each test
# ---------------------------------------------------------------------------
@pytest.fixture
def agent_budget(db_conn):
    """
    Insert a fresh agent_budgets row for one test, then hard-delete it.

    Yields a dict with the inserted row values so tests can reference them:
        {
            "agent_id":        "test-budget-<uuid4>",
            "daily_budget_usd": 1.0,
            "remaining_budget": 1.0,
            "is_active":        True,
            "budget_reset_at":  <datetime in UTC, ~1 second in the past>,
        }

    Setting budget_reset_at in the past means the cron job will treat this
    row as eligible for a reset on its very next run.
    """
    agent_id = f"test-budget-{uuid.uuid4()}"
    daily_budget = 1.0
    # Place reset time slightly in the past so cron resets it immediately
    reset_at = datetime.now(timezone.utc).replace(microsecond=0)

    with db_conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO agent_budgets
                (agent_id, daily_budget_usd, remaining_budget, is_active, budget_reset_at)
            VALUES
                (%(agent_id)s, %(daily_budget)s, %(daily_budget)s, TRUE, %(reset_at)s)
            """,
            {"agent_id": agent_id, "daily_budget": daily_budget, "reset_at": reset_at},
        )
    db_conn.commit()

    yield {
        "agent_id": agent_id,
        "daily_budget_usd": daily_budget,
        "remaining_budget": daily_budget,
        "is_active": True,
        "budget_reset_at": reset_at,
    }

    # Teardown — always runs, even if the test fails
    with db_conn.cursor() as cur:
        cur.execute(
            "DELETE FROM agent_budgets WHERE agent_id = %s",
            (agent_id,),
        )
    db_conn.commit()

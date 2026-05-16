"""
Tests for the agent_budgets table and the daily-budget-reset cron job.

All tests use the `agent_budget` fixture from conftest.py which:
  - inserts a fresh row before each test
  - deletes it after each test (pass or fail)

The cron job runs every minute (* * * * *) and resets remaining_budget
back to daily_budget_usd for any active agent whose budget_reset_at <= now().
"""
import time
from datetime import datetime, timezone, timedelta

import psycopg2.extras
import pytest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fetch_budget(db_conn, agent_id: str) -> dict:
    """Return the current agent_budgets row as a plain dict."""
    with db_conn.cursor() as cur:
        cur.execute(
            "SELECT * FROM agent_budgets WHERE agent_id = %s",
            (agent_id,),
        )
        row = cur.fetchone()
    assert row is not None, f"No agent_budgets row found for {agent_id!r}"
    return dict(row)


def spend(db_conn, agent_id: str, amount: float) -> None:
    """Simulate spend by decrementing remaining_budget."""
    with db_conn.cursor() as cur:
        cur.execute(
            """
            UPDATE agent_budgets
               SET remaining_budget = remaining_budget - %s
             WHERE agent_id = %s
            """,
            (amount, agent_id),
        )
    db_conn.commit()


# ---------------------------------------------------------------------------
# Schema / insert tests  (no cron dependency)
# ---------------------------------------------------------------------------

def test_row_inserted(db_conn, agent_budget):
    """Fixture must create exactly one row with correct initial values."""
    row = fetch_budget(db_conn, agent_budget["agent_id"])

    assert row["agent_id"] == agent_budget["agent_id"]
    assert float(row["daily_budget_usd"]) == pytest.approx(1.0)
    assert float(row["remaining_budget"]) == pytest.approx(1.0)
    assert row["is_active"] is True


def test_remaining_budget_decrements(db_conn, agent_budget):
    """Spending 0.25 USD must reduce remaining_budget by exactly that amount."""
    spend(db_conn, agent_budget["agent_id"], 0.25)
    row = fetch_budget(db_conn, agent_budget["agent_id"])
    assert float(row["remaining_budget"]) == pytest.approx(0.75)


def test_remaining_budget_can_go_negative(db_conn, agent_budget):
    """
    The DB does not enforce a floor — enforcement is the application's job.
    Overspend must be stored as-is.
    """
    spend(db_conn, agent_budget["agent_id"], 1.5)
    row = fetch_budget(db_conn, agent_budget["agent_id"])
    assert float(row["remaining_budget"]) == pytest.approx(-0.5)


def test_inactive_agent_not_reset(db_conn, agent_budget):
    """
    Deactivating an agent and manually triggering the reset logic must
    leave remaining_budget unchanged (the cron WHERE clause filters is_active).
    """
    agent_id = agent_budget["agent_id"]

    # Spend some budget then deactivate
    spend(db_conn, agent_id, 0.60)
    with db_conn.cursor() as cur:
        cur.execute(
            "UPDATE agent_budgets SET is_active = FALSE WHERE agent_id = %s",
            (agent_id,),
        )
    db_conn.commit()

    # Run the same UPDATE the cron job runs, manually
    with db_conn.cursor() as cur:
        cur.execute(
            """
            UPDATE agent_budgets
               SET remaining_budget = daily_budget_usd,
                   budget_reset_at  = budget_reset_at + INTERVAL '1 day'
             WHERE is_active        = TRUE
               AND budget_reset_at <= now()
               AND agent_id        = %s
            """,
            (agent_id,),
        )
        affected = cur.rowcount
    db_conn.commit()

    assert affected == 0, "Inactive agent must not be reset"
    row = fetch_budget(db_conn, agent_id)
    assert float(row["remaining_budget"]) == pytest.approx(0.40)


def test_future_reset_at_not_reset(db_conn, agent_budget):
    """
    An agent whose budget_reset_at is in the future must not be reset
    by the cron UPDATE (budget_reset_at <= now() must be False).
    """
    agent_id = agent_budget["agent_id"]

    # Push reset time 24 h into the future
    with db_conn.cursor() as cur:
        cur.execute(
            """
            UPDATE agent_budgets
               SET budget_reset_at = now() + INTERVAL '24 hours',
                   remaining_budget = 0.10
             WHERE agent_id = %s
            """,
            (agent_id,),
        )
    db_conn.commit()

    # Run cron logic manually
    with db_conn.cursor() as cur:
        cur.execute(
            """
            UPDATE agent_budgets
               SET remaining_budget = daily_budget_usd,
                   budget_reset_at  = budget_reset_at + INTERVAL '1 day'
             WHERE is_active        = TRUE
               AND budget_reset_at <= now()
               AND agent_id        = %s
            """,
            (agent_id,),
        )
        affected = cur.rowcount
    db_conn.commit()

    assert affected == 0, "Future reset_at must not trigger a reset"
    row = fetch_budget(db_conn, agent_id)
    assert float(row["remaining_budget"]) == pytest.approx(0.10)


def test_reset_advances_budget_reset_at_by_24h(db_conn, agent_budget):
    """
    Running the cron UPDATE manually on an eligible row must advance
    budget_reset_at by exactly 24 hours and restore remaining_budget.
    """
    agent_id = agent_budget["agent_id"]
    spend(db_conn, agent_id, 0.80)

    before = fetch_budget(db_conn, agent_id)
    before_reset_at = before["budget_reset_at"]
    if before_reset_at.tzinfo is None:
        before_reset_at = before_reset_at.replace(tzinfo=timezone.utc)

    # Run cron logic manually
    with db_conn.cursor() as cur:
        cur.execute(
            """
            UPDATE agent_budgets
               SET remaining_budget = daily_budget_usd,
                   budget_reset_at  = budget_reset_at + INTERVAL '1 day'
             WHERE is_active        = TRUE
               AND budget_reset_at <= now()
               AND agent_id        = %s
            """,
            (agent_id,),
        )
        affected = cur.rowcount
    db_conn.commit()

    assert affected == 1
    after = fetch_budget(db_conn, agent_id)
    after_reset_at = after["budget_reset_at"]
    if after_reset_at.tzinfo is None:
        after_reset_at = after_reset_at.replace(tzinfo=timezone.utc)

    assert float(after["remaining_budget"]) == pytest.approx(1.0)
    delta = after_reset_at - before_reset_at
    assert delta == timedelta(hours=24), f"Expected +24 h, got {delta}"


# ---------------------------------------------------------------------------
# Live cron test  (slow — waits up to 90 s for the real pg_cron job)
# ---------------------------------------------------------------------------

@pytest.mark.slow
def test_cron_resets_budget_live(db_conn, agent_budget):
    """
    Insert an eligible row and wait for the real pg_cron 'daily-budget-reset'
    job to fire.  Asserts remaining_budget is restored within 90 seconds.

    Mark: slow  —  skip in fast CI with:  pytest -m "not slow"
    """
    agent_id = agent_budget["agent_id"]
    spend(db_conn, agent_id, 0.55)

    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        time.sleep(5)
        row = fetch_budget(db_conn, agent_id)
        if float(row["remaining_budget"]) == pytest.approx(1.0, abs=1e-6):
            break
    else:
        row = fetch_budget(db_conn, agent_id)
        pytest.fail(
            f"Cron did not reset budget within 90 s. "
            f"remaining_budget={row['remaining_budget']}"
        )

    # Also verify reset_at advanced
    after_reset_at = row["budget_reset_at"]
    if after_reset_at.tzinfo is None:
        after_reset_at = after_reset_at.replace(tzinfo=timezone.utc)
    assert after_reset_at > agent_budget["budget_reset_at"]

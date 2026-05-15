-- schema/fiscal_guardrail.sql
-- Fiscal Guardrail: budget enforcement for agentic inference requests
-- Run once against the litellm-db Cloud SQL instance

BEGIN;

-- ─────────────────────────────────────────────
-- Table 1: agent_budgets
-- One row per agent. Tracks current daily budget
-- and whether the agent is allowed to make calls.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_budgets (
    agent_id          TEXT            PRIMARY KEY,
    daily_budget_usd  NUMERIC(10, 6)  NOT NULL,
    remaining_budget  NUMERIC(10, 6)  NOT NULL,
    is_active         BOOLEAN         NOT NULL DEFAULT TRUE,
    budget_reset_at   TIMESTAMPTZ     NOT NULL DEFAULT (NOW() + INTERVAL '1 day'),
    created_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- Table 2: inference_transactions
-- Append-only ledger. One row per inference call.
-- Never update or delete rows — audit trail.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inference_transactions (
    transaction_id    UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id          TEXT            NOT NULL REFERENCES agent_budgets(agent_id),
    model_name        TEXT            NOT NULL,
    prompt_tokens     INTEGER         NOT NULL DEFAULT 0,
    completion_tokens INTEGER         NOT NULL DEFAULT 0,
    total_tokens      INTEGER         GENERATED ALWAYS AS (prompt_tokens + completion_tokens) STORED,
    estimated_cost    NUMERIC(10, 6)  NOT NULL DEFAULT 0.000000,
    request_id        TEXT,
    created_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_agent_id
    ON inference_transactions(agent_id);

CREATE INDEX IF NOT EXISTS idx_transactions_created_at
    ON inference_transactions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_agent_daily
    ON inference_transactions(agent_id, created_at DESC);

-- ─────────────────────────────────────────────
-- Trigger: auto-update updated_at on agent_budgets
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_agent_budgets_updated_at
    BEFORE UPDATE ON agent_budgets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- Seed: default agent with $5.00 daily budget
-- ─────────────────────────────────────────────
INSERT INTO agent_budgets (
    agent_id,
    daily_budget_usd,
    remaining_budget,
    is_active,
    budget_reset_at
)
VALUES (
    'default-agent',
    5.000000,
    5.000000,
    TRUE,
    DATE_TRUNC('day', NOW()) + INTERVAL '1 day'
)
ON CONFLICT (agent_id) DO NOTHING;

COMMIT;

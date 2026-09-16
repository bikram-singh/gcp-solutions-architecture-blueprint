-- dr-smoke-test.sql
-- Run against the promoted DR replica immediately after Step 4 of the
-- failover runbook (docs/dr-drill/failover-runbook.md).
-- Exit non-zero / flag manually if any check fails -- do not mark the
-- incident resolved until all three pass.

-- 1. Schema integrity: confirm expected tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
-- Expected: matches the known MedSecure schema (patients, appointments,
-- clinic_accounts, consent_records -- compare against schema.sql in this repo)

-- 2. Most recent transaction timestamp -- THIS IS YOUR MEASURED RPO
-- Compare this value against the incident's declared-at timestamp from
-- the drill log; the gap between them is the actual data-loss window.
SELECT MAX(updated_at) AS most_recent_write
FROM appointments;

-- 3. End-to-end connectivity check (run from the application tier, not
-- just this SQL client, to confirm the app's connection pool and
-- credentials actually work against the promoted instance)
SELECT 1 AS connectivity_check;

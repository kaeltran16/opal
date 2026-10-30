-- row-count parity check. runs unchanged on the old sqlite db and on d1, so the
-- two outputs are directly comparable during phase 6 cutover.
SELECT 'device_tokens'   AS tbl, COUNT(*) AS n FROM device_tokens
UNION ALL SELECT 'pal_facts',      COUNT(*) FROM pal_facts
UNION ALL SELECT 'pal_patterns',   COUNT(*) FROM pal_patterns
UNION ALL SELECT 'widget_snapshot',COUNT(*) FROM widget_snapshot;

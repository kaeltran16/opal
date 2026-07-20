# Phase 1 benchmark results (template)

Produced by `node bench/drive.mjs`. Records per-case wall time, CPU-limit (1102/1027)
failures, CPU P50/P99 from GraphQL analytics, bundle size vs 3 MB, and the GO/NO-GO verdict.

Go: worst-case CPU P99 < 10 ms with a documented margin, zero 1102s, bundle < 3 MB.
No-go: any 1102, or CPU cannot fit reliably — stop the $0 migration (roadmap).

// Node driver: hammers the deployed spike, flags CPU-limit failures (1102/1027),
// then reads CPU quantiles from the Cloudflare GraphQL Analytics API.
// Run: node bench/drive.mjs   (env vars documented in README.md)
// Requires Node 22.6+ / 24 (imports the .ts fixtures via type stripping).
import { chatPayload, insightsPayload, routinePayload, emailExtractPayload } from './fixtures.ts'

const BASE = req('BASE_URL')
const PROV = req('PROVISIONING_KEY')
const REPS = Number(process.env.REPS ?? 50)
const CF_TOKEN = req('CF_API_TOKEN')
const CF_ACCOUNT = req('CF_ACCOUNT_ID')
const WORKER = process.env.WORKER_NAME ?? 'opal-spike'
const CPU_LIMIT_MS = 10

function req(name) { const v = process.env[name]; if (!v) throw new Error(`missing env ${name}`); return v }

const CASES = [
  { name: 'chat', path: '/v1/chat', body: chatPayload() },
  { name: 'insights', path: '/v1/insights', body: insightsPayload() },
  { name: 'routine', path: '/v1/routine', body: routinePayload() },
  { name: 'email-extract', path: '/v1/email/extract', body: emailExtractPayload() },
]

async function register() {
  const res = await fetch(`${BASE}/v1/register`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: PROV, deviceId: 'bench-driver' }),
  })
  if (!res.ok) throw new Error(`register failed ${res.status}`)
  return (await res.json()).token
}

// A CPU-limit kill surfaces as a 5xx whose body names error 1102/1027.
function isCpuLimit(status, text) {
  return status >= 500 && /\b(1102|1027)\b|exceeded (its )?(cpu|resource)/i.test(text)
}

async function runCase(token, c) {
  const walls = []
  let cpuFails = 0, otherFails = 0
  for (let i = 0; i < REPS; i++) {
    const t0 = performance.now()
    const res = await fetch(`${BASE}${c.path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify(c.body),
    })
    const text = await res.text()
    walls.push(performance.now() - t0)
    if (isCpuLimit(res.status, text)) cpuFails++
    else if (!res.ok) otherFails++
  }
  walls.sort((a, b) => a - b)
  const pct = (p) => walls[Math.min(walls.length - 1, Math.floor((p / 100) * walls.length))]
  return { name: c.name, reps: REPS, cpuFails, otherFails, wallP50: pct(50), wallP99: pct(99) }
}

// CPU quantiles from the GraphQL Analytics API. Field names per the
// workersInvocationsAdaptiveGroups dataset — verify against the current schema at
// https://developers.cloudflare.com/analytics/graphql-api/ if a field is rejected.
async function cpuQuantiles(sinceIso) {
  const query = `query($account:String!,$script:String!,$since:Time!){
    viewer{ accounts(filter:{accountTag:$account}){
      workersInvocationsAdaptiveGroups(limit:1, filter:{scriptName:$script, datetime_geq:$since}){
        quantiles{ cpuTimeP50 cpuTimeP99 }
        sum{ requests errors }
      }
    }}}`
  const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
    method: 'POST',
    headers: { authorization: `Bearer ${CF_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ query, variables: { account: CF_ACCOUNT, script: WORKER, since: sinceIso } }),
  })
  const j = await res.json()
  const g = j?.data?.viewer?.accounts?.[0]?.workersInvocationsAdaptiveGroups?.[0]
  if (!g) return { note: `no analytics rows yet (errors: ${JSON.stringify(j.errors ?? 'none')})` }
  // cpuTime quantiles are microseconds in this dataset; convert to ms.
  return { p50ms: g.quantiles.cpuTimeP50 / 1000, p99ms: g.quantiles.cpuTimeP99 / 1000, requests: g.sum.requests }
}

async function main() {
  const since = new Date(Date.now() - 60_000).toISOString()
  const token = await register()
  const rows = []
  for (const c of CASES) { const r = await runCase(token, c); rows.push(r); console.log(r) }
  // let analytics settle, then read CPU.
  await new Promise((r) => setTimeout(r, 60_000))
  const cpu = await cpuQuantiles(since)

  const anyCpuFail = rows.some((r) => r.cpuFails > 0)
  const verdict = anyCpuFail
    ? 'NO-GO — CPU-limit (1102/1027) failures observed'
    : (cpu.p99ms !== undefined && cpu.p99ms < CPU_LIMIT_MS)
      ? `GO — worst-case CPU P99 ${cpu.p99ms.toFixed(2)} ms < ${CPU_LIMIT_MS} ms limit`
      : 'REVIEW — no 1102s, but confirm CPU P99 margin from analytics'

  const md = [
    `# Phase 1 benchmark results`, ``,
    `Base: ${BASE} · reps/case: ${REPS} · worker: ${WORKER}`, ``,
    `## Per-case (wall time, ms)`, ``,
    `| case | reps | cpuFails | otherFails | wallP50 | wallP99 |`,
    `| --- | ---: | ---: | ---: | ---: | ---: |`,
    ...rows.map((r) => `| ${r.name} | ${r.reps} | ${r.cpuFails} | ${r.otherFails} | ${r.wallP50.toFixed(0)} | ${r.wallP99.toFixed(0)} |`),
    ``, `## CPU time (GraphQL analytics)`, ``, '```json', JSON.stringify(cpu, null, 2), '```', ``,
    `## Verdict`, ``, `**${verdict}**`, ``,
  ].join('\n')

  // write next to this script
  const { writeFile } = await import('node:fs/promises')
  const { fileURLToPath } = await import('node:url')
  const out = fileURLToPath(new URL('./results.md', import.meta.url))
  await writeFile(out, md)
  console.log(`\nwrote ${out}\n${verdict}`)
}

main().catch((e) => { console.error(e); process.exit(1) })

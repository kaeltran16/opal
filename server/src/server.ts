import { config } from './config.js'
import { buildApp } from './app.js'
import { OpenRouterClient, Pal } from './pal.js'
import { EmailWorker } from './email.js'
import { ImapFlowClient } from './imap.js'
import { TokenStore } from './store.js'
import { HealthStore } from './health.js'
import { WidgetSnapshotStore } from './widget.js'

// usage/latency of each completion, for cost/observability
const completionLogger = { info: (obj: unknown, msg?: string) => console.log(msg ?? '', obj) }
const client = new OpenRouterClient(config.openrouterApiKey, config.model, config.openrouterBaseUrl, fetch, config.requestTimeoutMs, completionLogger)
const pal = new Pal(client)
// per-email extraction failures must be visible in production (Bug D)
const syncLogger = { error: (obj: unknown, msg?: string) => console.error(msg ?? '', obj) }
const worker = new EmailWorker(new ImapFlowClient(), client, syncLogger)
const store = new TokenStore(config.sqlitePath)
const healthStore = new HealthStore(config.sqlitePath)
const widgetStore = new WidgetSnapshotStore(config.sqlitePath)

const app = buildApp({ pal, worker, store, healthStore, widgetStore, provisioningKey: config.provisioningKey, corsOrigins: config.corsOrigins, logger: true })

app.listen({ port: config.port, host: '0.0.0.0' }).then((addr) => {
  console.log(`pal proxy (openrouter) listening on ${addr}`)
})

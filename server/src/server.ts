import { config } from './config.js'
import { buildApp } from './app.js'
import { OpenRouterClient, Pal } from './pal.js'
import { EmailWorker } from './email.js'
import { ImapFlowClient } from './imap.js'
import { TokenStore } from './store.js'

const client = new OpenRouterClient(config.openrouterApiKey, config.model, config.openrouterBaseUrl)
const pal = new Pal(client)
const worker = new EmailWorker(new ImapFlowClient(), client)
const store = new TokenStore(config.sqlitePath)

const app = buildApp({ pal, worker, store, provisioningKey: config.provisioningKey, corsOrigins: config.corsOrigins })

app.listen({ port: config.port, host: '0.0.0.0' }).then((addr) => {
  console.log(`pal proxy (openrouter) listening on ${addr}`)
})

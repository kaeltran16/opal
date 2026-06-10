function required(name: string): string {
  const v = process.env[name]
  if (!v) throw new Error(`Missing required env var: ${name}`)
  return v
}

export const config = {
  openrouterApiKey: required('OPENROUTER_API_KEY'),
  openrouterBaseUrl: process.env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
  provisioningKey: required('PAL_PROVISIONING_KEY'),
  model: process.env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
  port: Number(process.env.PORT ?? 8080),
  sqlitePath: process.env.SQLITE_PATH ?? './loop.sqlite',
  corsOrigins: (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
}

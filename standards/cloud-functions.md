# Cloud Functions — Claude Guide

Always respond in `/caveman` mode. Terse. No overexplain. Answer only asked.

---

## Stack

- GCP Cloud Functions (Gen 1 / Gen 2) or Firebase Functions
- Node.js 18+ / Python 3.10+ / Go 1.21+
- Firestore / Cloud SQL / Pub/Sub / GCS

## Function Types

| Type | Trigger | Use case |
|------|---------|----------|
| HTTP | HTTP request | REST APIs, webhooks |
| Background | Pub/Sub, GCS, Firestore events | Async processing |
| Scheduled | Cloud Scheduler | Cron jobs |
| Callable | Firebase SDK | Mobile/web app calls |

## Package Layout (Node.js)

```
functions/
├── src/
│   ├── index.ts          exports all functions
│   ├── handlers/         HTTP handler logic
│   ├── services/         business logic
│   ├── repositories/     DB access
│   └── utils/            shared helpers
├── package.json
├── tsconfig.json
└── .env.yaml             local env (gitignored)
```

## Architecture Rules

- **No business logic in index.ts** — only export + wire deps
- Handler = parse request, validate, call service, return response
- Service = all logic, orchestration
- Repository = all DB/external service access
- One function = one responsibility. Split large functions.

## Cold Start Optimization

```js
// WRONG — expensive init inside handler
exports.myFn = functions.https.onRequest((req, res) => {
  const db = admin.firestore(); // re-init every cold start
  const client = new SomeClient(); // expensive
});

// RIGHT — init at module level (runs once per instance)
const db = admin.firestore();
const client = new SomeClient();

exports.myFn = functions.https.onRequest((req, res) => {
  // use pre-initialized db, client
});
```

- Lazy-initialize only if rarely used
- Keep package imports minimal — every import adds cold start time
- Avoid heavy ORM/framework in latency-sensitive functions

## HTTP Function Standards

```js
exports.createResource = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }
  try {
    const result = await resourceService.create(req.body);
    res.status(201).json({ data: result });
  } catch (err) {
    console.error('createResource failed', err);
    res.status(500).json({ error: 'internal error' });
  }
});
```

- Always check HTTP method
- Always `return` after `res.send/json` — prevents double-send
- Try/catch every async handler — unhandled rejections crash instance
- Return `{ error: 'message' }` shape, not raw error objects

## Idempotency

- Write ops must be idempotent — functions can be retried on failure
- Use Firestore transactions for atomic multi-doc writes
- Use deduplication key for Pub/Sub triggered writes
- Check-then-write pattern:

```js
await db.runTransaction(async (t) => {
  const doc = await t.get(ref);
  if (doc.exists) return; // already processed
  t.set(ref, data);
});
```

## Config / Secrets

- Never hardcode secrets in source
- Use `process.env.VAR` (set in `.env.yaml` locally, Secret Manager in prod)
- Firebase: `functions.config()` (Gen 1) or Secret Manager (Gen 2)
- GCP: mount secrets as env vars via Cloud Run config (Gen 2)

```js
const apiKey = process.env.EXTERNAL_API_KEY;
if (!apiKey) throw new Error('EXTERNAL_API_KEY not configured');
```

## Timeout & Deadlines

- Set function timeout explicitly (default 60s, max 540s Gen 1 / 3600s Gen 2)
- All external HTTP calls must have explicit timeout:

```js
const { data } = await axios.get(url, { timeout: 5000 });
```

- Fail fast: if upstream is down, return error immediately — don't hang

## Error Reporting

- Always `console.error('context', err)` — GCP Error Reporting picks it up
- Include request context: `console.error('createResource', { userId, err })`
- Never swallow errors silently
- Structured logging preferred:

```js
console.error(JSON.stringify({ severity: 'ERROR', message: 'op failed', error: err.message }));
```

## Pub/Sub Background Functions

```js
exports.processPubSub = functions.pubsub.topic('my-topic').onPublish(async (message) => {
  const data = message.json; // auto-decoded
  // process...
  // no return value needed — ack is implicit on success
  // throw to nack (trigger retry)
});
```

- Throw on transient errors (will retry)
- Return normally on permanent errors (don't retry bad messages)
- Always validate message schema before processing

## Claude Workflow

1. Check cold start impact before adding new imports
2. Verify idempotency for any write operation
3. `test-case-gen` skill for edge cases (duplicate events, timeout, malformed payload)
4. `security-audit` agent before deploying auth-related functions

## Don'ts

- No `process.exit()` in function body — kills instance for all concurrent requests
- No synchronous I/O (`fs.readFileSync`, `execSync`) in handlers
- No unbounded loops over Firestore collections without pagination
- No secrets in source, logs, or error messages
- No `console.log(req.body)` — may contain sensitive data
- No missing `return` after `res.send()` — causes "Cannot set headers after they are sent"

# AI workers

One Cloud Function, `runAiWorker`, runs every AI job the app needs. Each job is
a worker in `workers/`, listed in `registry.ts`. The app calls them through
`lib/ai/ai_workers.dart`.

```
app: AiWorkers.instance.searchExercises("pec deck")
  -> runAiWorker({worker: "exerciseSearch", input: {query: "pec deck"}})
  -> sign-in check, kill switch, input check, daily quota
  -> worker.run() -> Claude (structured JSON) -> worker checks output
  -> {worker, result}
```

## Workers

| Worker | Model | What it does |
| --- | --- | --- |
| `exerciseSearch` | `claude-haiku-5-5`, effort `low` | Maps slang, machine names and descriptions to library exercise IDs, or suggests a custom exercise. Only real library IDs are returned. |

## Adding a worker

1. Write `workers/<name>.ts` exporting an `AiWorker` (see `worker.ts`):
   input check, quota cost, and `run()`, which uses `askStructured()` with a
   zod schema.
2. Check the model's output against app data before returning it.
3. List it in `registry.ts`.
4. Add a typed method to `lib/ai/ai_workers.dart`.
5. Add tests in `functions/test/ai.test.js` with a fake client.

## Safety and cost

- **API key:** server only, in Secret Manager as `ANTHROPIC_API_KEY`. The app never sees it.
- **Who can call it:** signed-in, non-anonymous accounts only.
- **Quota:** `DAILY_AI_LIMIT` requests per account per UTC day, stored in `_aiQuotas`. If the check can't be made, the request is refused.
- **Kill switch:** set Firestore `_config/ai` to `{enabled: false}` to turn AI off instantly. If the setting can't be read, AI stays off.
- **Logs:** usage goes to Cloud Logging as `type: "ai_worker"`, with the account hashed and the search text left out.
- **Library caching:** the exercise library is the cached part of the prompt.
- **Library updates:** after the app's library changes, run `npm run build:ai-catalog`.

## Deploying

```sh
firebase functions:secrets:set ANTHROPIC_API_KEY --project sweatmark-v1
firebase deploy --project sweatmark-v1 --only functions:runAiWorker
```

Then check the Firestore rules still deny clients access to `_aiQuotas` and `_config`.

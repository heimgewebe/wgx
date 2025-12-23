# Heimgeist Mini-Spec

Domain: heimgeist

Wrapper:

```json
{
  "kind": "heimgeist.insight",
  "version": 1,
  "id": "<uuid>",
  "meta": {
    "occurred_at": "<ISO8601>",
    "role": "<string>"
  },
  "data": { ... }
}
```

ID: `evt-${insight.id}`

Timestamp: `meta.occurred_at` (ISO8601)

Transport: `POST /ingest/heimgeist` (+ Header `X-Auth`)

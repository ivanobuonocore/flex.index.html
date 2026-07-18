# Capitolo 14 – API Design Specification

## Filosofia

Le API rappresentano il contratto tra frontend e backend: semplici, coerenti, versionabili, indipendenti
dal frontend. Tutte le API seguono lo stesso formato di risposta.

## Convenzioni

- Base URL: `/api/v1/`
- Autenticazione: Bearer Token (JWT)
- Formato: JSON
- Errori (formato standard):
```json
{
  "success": false,
  "error": { "code": "...", "message": "..." }
}
```
- **Da aggiungere alle convenzioni**: paginazione standard (`?limit=&cursor=`), mappatura esplicita
  `error.code` → status HTTP (400/401/403/404/409/429), header `Idempotency-Key` per operazioni critiche
  (checkout, upload).

## Modulo Account
`POST /auth/signup` · `POST /auth/login` · `POST /auth/logout` · `POST /auth/refresh` · `GET /me` ·
`PATCH /me` · `DELETE /me`

## Workspace API
`GET /workspaces` · `POST /workspaces` · `GET /workspaces/{id}` · `PATCH /workspaces/{id}` ·
`DELETE /workspaces/{id}` · `GET /workspaces/{id}/dashboard` · `GET /workspaces/{id}/timeline`

## Conversation API
`GET /workspaces/{id}/conversations` · `POST /workspaces/{id}/conversations` · `GET /conversations/{id}`
· `DELETE /conversations/{id}` · `POST /conversations/{id}/messages` · `GET /conversations/{id}/messages`

Streaming: Server-Sent Events (SSE) o WebSocket per le risposte AI.

## Document API
`POST /documents/upload` · `GET /documents/{id}` · `DELETE /documents/{id}` ·
`POST /documents/{id}/summarize` · `POST /documents/{id}/analyze` · `POST /documents/{id}/translate` ·
`POST /documents/{id}/compare`

## Task API
`GET /tasks` · `POST /tasks` · `PATCH /tasks/{id}` · `DELETE /tasks/{id}` · `POST /tasks/{id}/complete`

## Note API
`GET /notes` · `POST /notes` · `PATCH /notes/{id}` · `DELETE /notes/{id}`

## Memory API
`GET /memory` · `POST /memory` · `PATCH /memory/{id}` · `DELETE /memory/{id}` · `GET /memory/search`

## Search API
`POST /search` — ricerca unificata su Workspace, Conversazioni, Documenti, Note, Task, Memorie.

## AI API
`POST /ai/chat` · `POST /ai/actions` · `POST /ai/summarize` · `POST /ai/explain` · `POST /ai/rewrite` ·
`POST /ai/agent`

Orchestrati dall'AI Engine, nascondono al frontend il modello AI effettivamente utilizzato.

> ⚠️ `POST /ai/agent` sembra sovrapporsi a `POST /agents/{id}/run` (Agent API) — chiarire se sono
> davvero endpoint distinti o vanno consolidati.

## Agent API
`GET /agents` · `POST /agents` · `PATCH /agents/{id}` · `DELETE /agents/{id}` · `POST /agents/{id}/run`

## Timeline API
`GET /timeline` · `GET /workspaces/{id}/timeline`

## Notification API
`GET /notifications` · `PATCH /notifications/{id}/read` · `POST /notifications/preferences`

## Billing API
`GET /subscription` · `POST /subscription/checkout` · `POST /subscription/cancel` · `GET /usage`

## Webhook
Endpoint dedicati per integrazioni esterne (pagamento completato, documento sincronizzato, calendario aggiornato).

## Versionamento

Ogni breaking change introduce una nuova versione delle API. Le versioni precedenti rimangono supportate
per un periodo definito.

## Regola Finale

Le API non devono riflettere la struttura del database. Devono riflettere il linguaggio del dominio e i
bisogni del frontend.

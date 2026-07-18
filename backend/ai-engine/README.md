# backend/ai-engine

Unico punto di contatto con i provider AI (Claude). Responsabilita: selezione modello,
orchestrazione prompt, RAG, memoria, orchestrazione agenti, streaming.
Nessun altro modulo deve chiamare direttamente un provider LLM (vedi AGENTS.md paragrafo 4).

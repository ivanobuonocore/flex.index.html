// Genera le Transazioni pending dovute per i modelli ricorrenti (Fase 3, "spese
// ricorrenti automatiche" — richiesta esplicita dell'utente, stesso motore già
// costruito per i Promemoria ricorrenti). Invocata da un cron job Postgres
// (`pg_cron`, una volta al giorno — vedi
// infrastructure/supabase/migrations/20260723110000_recurring_transaction_templates.sql),
// non da una richiesta di un utente autenticato: non esiste un JWT da inoltrare.
//
// A differenza di ai-chat e send-test-push, questa è (con send-due-reminders) una delle
// poche function del progetto che usa la service role, non il JWT di chi chiama —
// giustificato esplicitamente: deve leggere/scrivere i modelli ricorrenti di TUTTI gli
// utenti (per trovare quelli dovuti), non solo quelli di uno specifico chiamante. Le RLS
// di recurring_transaction_templates/transactions restano intatte per ogni altro accesso
// (client mobile, ai-chat) — qui vengono bypassate by design, non aggirate per errore.
//
// A differenza dei Promemoria ricorrenti (tutte le occorrenze pre-generate subito alla
// creazione), qui si genera UNA Transaction pending alla volta, solo quando dovuta: un
// elenco "in attesa di conferma" con mesi di spese future già presenti confonderebbe la
// sezione, oltre a non avere senso finanziariamente (non si "deve" ancora nulla per un
// mese futuro) — coerente con AI Constitution, Principio 1 ("l'AI suggerisce, l'utente
// decide"), un suggerimento alla volta, non un blocco di dodici.

import { createClient } from "npm:@supabase/supabase-js@2";

// Limite di sicurezza sul numero di occorrenze generate in un'unica esecuzione per
// modello: se il cron non gira per molto tempo (es. progetto in pausa), un modello
// mensile "arretrato" di anni non deve generare centinaia di transazioni in un colpo
// solo — si allinea comunque a next_occurrence_at, semplicemente in più esecuzioni
// successive del cron.
const MAX_OCCURRENCES_PER_RUN = 24;

interface RecurringTemplate {
  id: string;
  workspace_id: string;
  type: "income" | "expense";
  description: string;
  amount_cents: number;
  category: string;
  frequency: "weekly" | "monthly";
  next_occurrence_at: string;
  anchor_day: number;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonError("Metodo non supportato.", 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error(
        "create-due-recurring-transactions: variabili d'ambiente mancanti " +
          "(SUPABASE_URL/SERVICE_ROLE_KEY)",
      );
      return jsonError("Servizio non configurato.", 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const todayIso = new Date().toISOString().slice(0, 10);

    const { data: templates, error: templatesError } = await supabase
      .from("recurring_transaction_templates")
      .select(
        "id, workspace_id, type, description, amount_cents, category, frequency, " +
          "next_occurrence_at, anchor_day",
      )
      .is("deleted_at", null)
      .lte("next_occurrence_at", todayIso);

    if (templatesError) {
      console.error(
        "create-due-recurring-transactions: errore lettura modelli",
        templatesError,
      );
      return jsonError("Non è stato possibile leggere i modelli ricorrenti.", 500);
    }

    const due = (templates ?? []) as RecurringTemplate[];
    if (due.length === 0) {
      return new Response(JSON.stringify({ ok: true, created: 0 }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    const newTransactions: {
      workspace_id: string;
      type: string;
      description: string;
      amount_cents: number;
      category: string;
      occurred_at: string;
      status: string;
      created_by_ai: boolean;
    }[] = [];
    const templateUpdates: { id: string; next_occurrence_at: string }[] = [];

    for (const template of due) {
      let occurrence = template.next_occurrence_at;
      let count = 0;
      while (occurrence <= todayIso && count < MAX_OCCURRENCES_PER_RUN) {
        newTransactions.push({
          workspace_id: template.workspace_id,
          type: template.type,
          description: template.description,
          amount_cents: template.amount_cents,
          category: template.category,
          occurred_at: occurrence,
          status: "pending",
          created_by_ai: true,
        });
        occurrence = advanceOccurrence(
          occurrence,
          template.frequency,
          template.anchor_day,
        );
        count += 1;
      }
      templateUpdates.push({ id: template.id, next_occurrence_at: occurrence });
    }

    if (newTransactions.length > 0) {
      const { error: insertError } = await supabase.from("transactions").insert(
        newTransactions,
      );
      if (insertError) {
        console.error(
          "create-due-recurring-transactions: errore insert transactions",
          insertError,
        );
        return jsonError("Non è stato possibile generare le transazioni.", 500);
      }
    }

    for (const update of templateUpdates) {
      const { error: updateError } = await supabase
        .from("recurring_transaction_templates")
        .update({ next_occurrence_at: update.next_occurrence_at })
        .eq("id", update.id);
      if (updateError) {
        console.error(
          "create-due-recurring-transactions: errore update modello",
          update.id,
          updateError,
        );
      }
    }

    return new Response(
      JSON.stringify({ ok: true, created: newTransactions.length }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (error) {
    console.error("create-due-recurring-transactions: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

// Avanza una data (formato YYYY-MM-DD) di un periodo — stessa logica di clamp sui mesi
// più corti già verificata per expandOccurrences (ai-chat/index.ts, promemoria
// ricorrenti): il 31 gennaio + 1 mese diventa il 28 febbraio, non il 3 marzo.
//
// `anchorDay` è il giorno "vero" della ricorrenza, fissato alla creazione del modello e
// passato esplicitamente ad ogni chiamata — MAI derivato da `dateIso` (che dopo un mese
// corto potrebbe già essere stato clampato a un giorno più basso): usare
// `date.getUTCDate()` al posto di `anchorDay` farebbe scivolare la scadenza al giorno
// clampato per sempre, invece di tornare al giorno originale nei mesi più lunghi.
function advanceOccurrence(
  dateIso: string,
  frequency: "weekly" | "monthly",
  anchorDay: number,
): string {
  const date = new Date(`${dateIso}T00:00:00Z`);

  if (frequency === "weekly") {
    date.setUTCDate(date.getUTCDate() + 7);
    return date.toISOString().slice(0, 10);
  }

  const firstOfNextMonth = new Date(date);
  firstOfNextMonth.setUTCDate(1);
  firstOfNextMonth.setUTCMonth(firstOfNextMonth.getUTCMonth() + 1);
  const daysInNextMonth = new Date(
    Date.UTC(
      firstOfNextMonth.getUTCFullYear(),
      firstOfNextMonth.getUTCMonth() + 1,
      0,
    ),
  ).getUTCDate();
  firstOfNextMonth.setUTCDate(Math.min(anchorDay, daysInNextMonth));
  return firstOfNextMonth.toISOString().slice(0, 10);
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

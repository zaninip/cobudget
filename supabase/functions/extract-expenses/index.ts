// Edge Function: estrae le voci di spesa/entrata da uno screenshot via Claude Vision.
//
// L'immagine arriva in base64, viene inviata a Claude e subito scartata: nessuno
// storage permanente (vedi DATABASE_SCHEMA.md - "Note di design"). La chiave
// ANTHROPIC_API_KEY e' un segreto della Edge Function, mai esposta al client.
//
// Source of truth: questo file nel repo. Per il deploy: incollare nell'editor
// Edge Functions della dashboard Supabase (oppure, in futuro,
// `supabase functions deploy extract-expenses`).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Mappa il "tier" scelto dall'utente in Impostazioni sul modello Claude.
const MODELS: Record<string, string> = {
  standard: "claude-sonnet-4-6",
  performante: "claude-opus-4-8",
};

interface SubcategoryIn {
  id: string;
  name: string;
}
interface CategoryIn {
  id: string;
  name: string;
  subcategories: SubcategoryIn[];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Metodo non consentito" }, 405);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return json({ error: "ANTHROPIC_API_KEY non configurata sul server" }, 500);
  }

  let payload: {
    image?: string;
    mediaType?: string;
    modelTier?: string;
    categories?: CategoryIn[];
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Body JSON non valido" }, 400);
  }

  const { image, mediaType, modelTier, categories } = payload;
  if (!image || !mediaType) {
    return json({ error: "Immagine mancante" }, 400);
  }

  const model = MODELS[modelTier ?? "standard"] ?? MODELS.standard;
  const cats = categories ?? [];
  const currentYear = new Date().getFullYear();

  // Catalogo categorie/sottocategorie offerto a Claude per il suggerimento.
  const categoryCatalog = cats
    .map((c) => {
      const subs = c.subcategories
        .map((s) => `    - ${s.name} (subcategoryId: ${s.id})`)
        .join("\n");
      return `- ${c.name} (categoryId: ${c.id})${subs ? `\n${subs}` : ""}`;
    })
    .join("\n");

  const systemPrompt =
    "Sei un assistente che estrae le voci di spesa ed entrata da uno screenshot " +
    "di un estratto conto, lista movimenti o scontrino. " +
    "Estrai SOLO le righe che rappresentano un movimento di denaro: ignora saldi, " +
    "totali, intestazioni, date di stampa e righe riepilogative. " +
    "Per ogni voce indica: 'title' (descrizione breve), 'amount' (numero positivo, " +
    "punto come separatore decimale), 'date' in formato ISO YYYY-MM-DD, 'type' " +
    "('expense' per le uscite, 'income' per entrate/accrediti). " +
    `Per la data: se lo screenshot riporta solo giorno e mese (anno non indicato), usa ` +
    `l'anno corrente ${currentYear}. Metti 'date' a null SOLO se non riesci a leggere ` +
    "neppure giorno e mese. " +
    "Assegna 'categoryId' e 'subcategoryId' SOLO scegliendo tra gli ID elencati qui " +
    "sotto; se non sei ragionevolmente sicuro lasciali null. Non inventare ID e non " +
    "usare una sottocategoria che non appartenga alla categoria scelta.\n\n" +
    "Categorie disponibili:\n" +
    (categoryCatalog || "(nessuna categoria fornita)");

  // Structured outputs: output JSON garantito e parsabile.
  const schema = {
    type: "object",
    properties: {
      expenses: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            amount: { type: "number" },
            date: { type: ["string", "null"] },
            type: { type: "string", enum: ["expense", "income"] },
            categoryId: { type: ["string", "null"] },
            subcategoryId: { type: ["string", "null"] },
          },
          required: ["title", "amount", "date", "type", "categoryId", "subcategoryId"],
          additionalProperties: false,
        },
      },
    },
    required: ["expenses"],
    additionalProperties: false,
  };

  const anthropicReq = {
    model,
    max_tokens: 4000,
    system: systemPrompt,
    output_config: { format: { type: "json_schema", schema } },
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: mediaType, data: image },
          },
          {
            type: "text",
            text: "Estrai tutte le voci di spesa/entrata da questa immagine seguendo le istruzioni.",
          },
        ],
      },
    ],
  };

  let res: Response;
  try {
    res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(anthropicReq),
    });
  } catch (e) {
    return json({ error: `Errore di rete verso Claude: ${e}` }, 502);
  }

  if (!res.ok) {
    const detail = await res.text();
    return json({ error: `Claude API ${res.status}: ${detail}` }, 502);
  }

  const data = await res.json();
  const textBlock = (data.content ?? []).find(
    (b: { type?: string }) => b.type === "text",
  );
  if (!textBlock?.text) {
    return json({ error: "Risposta di Claude senza contenuto testuale" }, 502);
  }

  let parsed: { expenses?: unknown };
  try {
    parsed = JSON.parse(textBlock.text);
  } catch {
    return json({ error: "Output di Claude non in formato JSON valido" }, 502);
  }

  return json({ expenses: parsed.expenses ?? [] });
});

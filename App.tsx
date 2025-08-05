import React, { useMemo, useRef, useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Stethoscope, AlertTriangle, CheckCircle2, Info, RotateCcw, Sparkles } from "lucide-react";

const ease = [0.16, 1, 0.3, 1];
const fadeUp = {
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0, transition: { duration: 0.5, ease } },
};
const fadeIn = {
  initial: { opacity: 0 },
  animate: { opacity: 1, transition: { duration: 0.5, ease } },
};

const ALL_MEDICATIONS = [
  "Paracétamol","Ibuprofène","Aspirine","Doliprane","Spifen","Nurofen","Kétoprofène",
  "Codéine","Amoxicilline","Tramadol","Prednisone","Lévothyrox","Oméprazole","Isotrétinoïne",
];

type Level =
  | "Contre-indiqué"
  | "Déconseillé"
  | "Précaution"
  | "À prendre en compte"
  | "Aucune connue"
  | "Inconnu";

const LEVEL_ORDER: Record<Level, number> = {
  "Contre-indiqué": 5, "Déconseillé": 4, "Précaution": 3, "À prendre en compte": 2, "Aucune connue": 1, "Inconnu": 0,
};

const INTERACTION_DB: Record<string, { level: Level; message: string; sources: string[] }> = {
  "Ibuprofène+Aspirine": { level: "Déconseillé", message: "Risque accru de saignement digestif; éviter l'association.", sources: ["Démo"] },
  "Paracétamol+Codéine": { level: "À prendre en compte", message: "Association possible; surveiller somnolence/nausées.", sources: ["Démo"] },
  "Tramadol+Oméprazole": { level: "À prendre en compte", message: "Possible modification d'exposition; prudence.", sources: ["Démo"] },
  "Amoxicilline+Lévothyrox": { level: "À prendre en compte", message: "Espacer la prise du Lévothyrox.", sources: ["Démo"] },
  "Paracétamol+Ibuprofène": { level: "Aucune connue", message: "Peut être combiné ponctuellement aux doses usuelles.", sources: ["Démo"] },
  "Tramadol+Codéine": { level: "Déconseillé", message: "Addition d'opioïdes; risque de dépression respiratoire.", sources: ["Démo"] },
  "Prednisone+Ibuprofène": { level: "Précaution", message: "Risque d'ulcère/hémorragie digestive.", sources: ["Démo"] },
  "Kétoprofène+Prednisone": { level: "Déconseillé", message: "Risque ulcérogène majoré.", sources: ["Démo"] },
  "Oméprazole+Lévothyrox": { level: "Précaution", message: "Altère l'absorption du Lévothyrox; prendre à distance.", sources: ["Démo"] },
  "Spifen+Ibuprofène": { level: "Déconseillé", message: "Double emploi d'AINS.", sources: ["Démo"] },
  "Nurofen+Ibuprofène": { level: "Déconseillé", message: "Même molécule → surdosage.", sources: ["Démo"] },
  "Doliprane+Paracétamol": { level: "Déconseillé", message: "Même molécule → toxicité hépatique.", sources: ["Démo"] },
};

const ALCOHOL_RULES: Record<string, { level: Level; message: string; sources: string[] }> = {
  Paracétamol: { level: "Déconseillé", message: "Risque hépatique majoré, surtout à forte dose/alcool chronique.", sources: ["Démo"] },
  Doliprane: { level: "Déconseillé", message: "Équivalent paracétamol : risque hépatique.", sources: ["Démo"] },
  Ibuprofène: { level: "Déconseillé", message: "Risque d'irritation/saignement digestif accru.", sources: ["Démo"] },
  Kétoprofène: { level: "Déconseillé", message: "Majore le risque digestif.", sources: ["Démo"] },
  Aspirine: { level: "Déconseillé", message: "Risque hémorragique digestif augmenté.", sources: ["Démo"] },
  Nurofen: { level: "Déconseillé", message: "Marque d'ibuprofène : mêmes risques.", sources: ["Démo"] },
  Spifen: { level: "Déconseillé", message: "Marque d'ibuprofène : mêmes risques.", sources: ["Démo"] },
  Tramadol: { level: "Déconseillé", message: "Sédation et dépression respiratoire majorées.", sources: ["Démo"] },
  Codéine: { level: "Déconseillé", message: "Sédation accrue, risque respiratoire.", sources: ["Démo"] },
  Prednisone: { level: "Précaution", message: "Irritation digestive; éviter l'excès.", sources: ["Démo"] },
  Lévothyrox: { level: "À prendre en compte", message: "Pas d'interaction PK majeure; attention à l'observance.", sources: ["Démo"] },
  Oméprazole: { level: "À prendre en compte", message: "Alcool irrite la muqueuse; éviter l'excès.", sources: ["Démo"] },
  Amoxicilline: { level: "À prendre en compte", message: "Pas d'interaction majeure; nausées possibles.", sources: ["Démo"] },
  Isotrétinoïne: { level: "Déconseillé", message: "Hépatotoxicité potentielle; éviter strictement.", sources: ["Démo"] },
};

const PATIENT_RULES = {
  pregnancy: (meds: string[]) => {
    const out: Array<{ level: Level; message: string; target?: string; sources: string[] }> = [];
    if (meds.includes("Isotrétinoïne"))
      out.push({ level: "Contre-indiqué", message: "Grossesse: isotrétinoïne formellement contre-indiquée.", target: "Isotrétinoïne", sources: ["Démo"] });
    const ains = ["Ibuprofène", "Kétoprofène", "Aspirine"];
    if (meds.some((m) => ains.includes(m)))
      out.push({ level: "Déconseillé", message: "Grossesse: éviter les AINS.", sources: ["Démo"] });
    return out;
  },
  pediatric: (age: number, meds: string[]) => {
    const out: Array<{ level: Level; message: string; target?: string; sources: string[] }> = [];
    if (age < 15 && meds.includes("Ibuprofène"))
      out.push({ level: "Déconseillé", message: "< 15 ans: ibuprofène déconseillé (exemple simplifié).", target: "Ibuprofène", sources: ["Démo"] });
    return out;
  },
};

const normalizePair = (a: string, b: string) => [a, b].sort((x, y) => x.localeCompare(y)).join("+");
const NORMALIZED_DB = Object.fromEntries(
  Object.entries(INTERACTION_DB).map(([k, v]) => [normalizePair(...k.split("+")), v])
) as typeof INTERACTION_DB;

const normalizeStr = (s: string) => s.normalize("NFD").replace(/[\\u0300-\\u036f]/g, "").toLowerCase().trim();
const findMedication = (input: string) => {
  const n = normalizeStr(input);
  const exact = ALL_MEDICATIONS.find((m) => normalizeStr(m) === n);
  return exact || null;
};

function evaluateInteractions(meds: string[], patient: { age?: number; pregnant?: boolean }) {
  const unique = Array.from(new Set(meds.filter(Boolean)));
  const pairKeys = new Set<string>();
  for (let i = 0; i < unique.length; i++)
    for (let j = i + 1; j < unique.length; j++) pairKeys.add(normalizePair(unique[i], unique[j]));

  const byPairs = Array.from(pairKeys).map((k) => {
    const rule = (NORMALIZED_DB as any)[k] as { level: Level; message: string; sources: string[] } | undefined;
    const [a, b] = k.split("+") as [string, string];
    if (rule) return { pair: [a, b] as [string, string], level: rule.level, message: rule.message, sources: rule.sources };
    return { pair: [a, b] as [string, string], level: "Aucune connue" as Level, message: "Aucune interaction significative connue dans notre base.", sources: [] };
  });

  const patientFindings: Array<{ level: Level; message: string; target?: string; sources: string[] }> = [];
  if (patient.pregnant) patientFindings.push(...PATIENT_RULES.pregnancy(unique));
  if (typeof patient.age === "number") patientFindings.push(...PATIENT_RULES.pediatric(patient.age, unique));

  const alcoholFindings: Array<{ drug: string; level: Level; message: string; sources: string[] }> = unique.map((m) => {
    const rule = ALCOHOL_RULES[m];
    if (rule) return { drug: m, level: rule.level, message: rule.message, sources: rule.sources };
    return { drug: m, level: "À prendre en compte" as Level, message: "Éviter l'alcool : peut majorer les effets indésirables/ somnolence.", sources: [] };
  });

  const worst = [...byPairs.map((x) => x.level), ...patientFindings.map((x) => x.level), ...alcoholFindings.map((x) => x.level)].reduce<Level>(
    (acc, cur) => (LEVEL_ORDER[cur] > LEVEL_ORDER[acc] ? cur : acc),
    "Aucune connue"
  );

  return { pairs: byPairs, patient: patientFindings, alcohol: alcoholFindings, worst };
}

const BadgeLevel: React.FC<{ level: Level }> = ({ level }) => {
  const cls =
    level === "Contre-indiqué" ? "bg-red-100 text-red-800 border-red-200"
    : level === "Déconseillé" ? "bg-amber-100 text-amber-800 border-amber-200"
    : level === "Précaution" ? "bg-yellow-100 text-yellow-800 border-yellow-200"
    : level === "À prendre en compte" ? "bg-sky-100 text-sky-800 border-sky-200"
    : level === "Aucune connue" ? "bg-emerald-100 text-emerald-800 border-emerald-200"
    : "bg-slate-100 text-slate-800 border-slate-200";
  const Icon = level === "Contre-indiqué" ? AlertTriangle : level === "Aucune connue" ? CheckCircle2 : Info;
  return <span className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-sm font-medium ${cls}`}><Icon size={16} /> {level}</span>;
};

const Pill: React.FC<{ label: string; onRemove?: () => void }> = ({ label, onRemove }) => (
  <motion.span layout initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1, transition: { duration: 0.35, ease } }} exit={{ opacity: 0, scale: 0.9, transition: { duration: 0.25, ease } }} className="inline-flex items-center gap-1 rounded-full bg-white/70 backdrop-blur px-2.5 py-1 text-sm text-slate-800 shadow-sm border">
    {label}
    {onRemove && <button onClick={onRemove} className="ml-1 rounded-full p-0.5 hover:bg-slate-100 active:scale-95 transition" aria-label={`Retirer ${label}`}><X size={14} /></button>}
  </motion.span>
);

function Section({ title, tone, items }: { title: string; tone: "red" | "amber" | "yellow" | "emerald"; items: Array<{ pair: [string, string]; level: Level; message: string; sources: string[] }> }) {
  const toneCls: Record<string, string> = { red: "border-red-200 bg-red-50", amber: "border-amber-200 bg-amber-50", yellow: "border-yellow-200 bg-yellow-50", emerald: "border-emerald-200 bg-emerald-50" };
  return (
    <motion.div {...fadeUp} className={`rounded-2xl border ${toneCls[tone]} p-4`}>
      <div className="mb-2 text-sm font-semibold text-slate-700">{title}</div>
      <ul className="space-y-2">
        {items.map((it, i) => (
          <motion.li key={i} {...fadeIn} className="rounded-xl border bg-white p-4 text-sm shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="font-medium text-slate-900">{it.pair[0]} <span className="text-slate-400">+</span> {it.pair[1]}</div>
              <BadgeLevel level={it.level} />
            </div>
            <div className="mt-1 text-slate-800 leading-relaxed">{it.message}</div>
            {it.sources?.length ? <div className="mt-1 text-xs text-slate-500">Sources: {it.sources.join(", ")}</div> : null}
          </motion.li>
        ))}
      </ul>
    </motion.div>
  );
}

export default function App() {
  const [entry, setEntry] = useState("");
  const [meds, setMeds] = useState<string[]>([]);
  const [age, setAge] = useState<number | undefined>(undefined);
  const [pregnant, setPregnant] = useState(false);
  const [view, setView] = useState<"all" | "ci" | "cons" | "ok" | "alc">("all");
  const inputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  const result = useMemo(() => evaluateInteractions(meds, { age, pregnant }), [meds, age, pregnant]);

  const addIfMatch = (v: string) => {
    const match = findMedication(v);
    if (match && !meds.includes(match)) { setMeds((prev) => [...prev, match]); return true; }
    return False;
  };

  const reset = () => { setMeds([]); setEntry(""); setAge(undefined); setPregnant(False); };

  const groups = useMemo(() => {
    const g: Record<string, typeof result.pairs> = { "Contre-indiqué": [], "Déconseillé": [], "Précaution": [], "À prendre en compte": [], "Aucune connue": [] };
    result.pairs.forEach((p) => g[p.level]?.push(p));
    return g;
  }, [result]);

  const alcoholGroups = useMemo(() => {
    const g: Record<string, typeof result.alcohol> = { "Contre-indiqué": [], "Déconseillé": [], "Précaution": [], "À prendre en compte": [], "Aucune connue": [] };
    result.alcohol.forEach((a) => g[a.level]?.push(a));
    return g;
  }, [result]);

  return (
    <div className="min-h-[100vh] w-full bg-gradient-to-b from-slate-50 via-white to-white">
      <section className="relative overflow-hidden">
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.6, ease }} className="pointer-events-none absolute inset-0">
          <div className="absolute -top-24 -left-24 h-72 w-72 rounded-full bg-emerald-100 blur-3xl opacity-60" />
          <div className="absolute -bottom-32 -right-24 h-72 w-72 rounded-full bg-sky-100 blur-3xl opacity-60" />
        </motion.div>
        <div className="mx-auto max-w-4xl px-6 pt-10">
          <motion.h1 initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, ease }} className="text-4xl sm:text-5xl font-extrabold tracking-tight text-slate-900">Vérificateur d'interactions</motion.h1>
          <motion.p {...fadeUp} className="mt-3 text-slate-600 max-w-2xl">Saisis tes médicaments, ajoute ton contexte patient, et obtiens une synthèse claire des risques, y compris l'association à l'alcool.</motion.p>
          <motion.div {...fadeIn} className="mt-4 inline-flex items-center gap-2 rounded-full border bg-white/70 backdrop-blur px-3 py-1 shadow-sm"><Sparkles size={16} className="text-emerald-600" /><span className="text-sm text-slate-700">Évaluation en temps réel • Animations fluides</span></motion.div>
        </div>
      </section>

      <div className="mx-auto max-w-4xl p-6">
        <motion.div {...fadeUp} className="rounded-2xl border bg-white/80 backdrop-blur p-5 shadow-md">
          <div className="flex flex-col gap-3 sm:flex-row">
            <input ref={inputRef} className="w-full rounded-xl border px-3 py-2 outline-none ring-0 transition focus:border-emerald-300 focus:ring-2 focus:ring-emerald-100" placeholder="Ajouter un médicament (ex: Paracétamol)" value={entry}
              onChange={(e) => { const v = e.target.value; setEntry(v); if (addIfMatch(v)) setEntry(""); }}
              onBlur={() => { if (entry && addIfMatch(entry)) setEntry(""); }}
              onKeyDown={(e) => { if (e.key === "Enter" && entry) { if (addIfMatch(entry)) setEntry(""); } }}
              list="meds" />
            <datalist id="meds">{ALL_MEDICATIONS.map((m) => (<option key={m} value={m} />))}</datalist>
            <motion.button whileTap={{ scale: 0.98 }} onClick={reset} className="inline-flex items-center gap-2 rounded-xl border px-4 py-2 text-slate-700 hover:bg-slate-50 active:scale-[.99]"><RotateCcw size={16} /> Réinitialiser</motion.button>
          </div>

          <div className="mt-3 flex flex-wrap gap-2">
            <AnimatePresence initial={false}>
              {meds.map((m) => (<Pill key={m} label={m} onRemove={() => setMeds((arr) => arr.filter((x) => x !== m))} />))}
            </AnimatePresence>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
            <div>
              <label className="block text-sm text-slate-600">Âge (années)</label>
              <input type="number" min={0} placeholder="ex: 32" value={age ?? ""} onChange={(e) => setAge(e.target.value ? Number(e.target.value) : undefined)} className="mt-1 w-full rounded-xl border px-3 py-2 focus:border-emerald-300 focus:ring-2 focus:ring-emerald-100" />
            </div>
            <div className="flex items-end gap-2"><input id="preg" type="checkbox" checked={pregnant} onChange={(e) => setPregnant(e.target.checked)} /><label htmlFor="preg" className="text-sm text-slate-700">Grossesse</label></div>
            <div className="flex items-end gap-2"><BadgeLevel level={result.worst} /></div>
          </div>

          <div className="mt-3 flex flex-wrap gap-2">
            {[{ id: "all", label: "Tout" },{ id: "ci", label: "Contre-indications" },{ id: "cons", label: "Déconseillé / Précautions" },{ id: "ok", label: "Aucune connue" },{ id: "alc", label: "Alcool" }].map((f: any) => (
              <motion.button key={f.id} whileTap={{ scale: 0.98 }} onClick={() => setView(f.id)} className={`rounded-full border px-3 py-1 text-sm transition ${view === f.id ? "bg-slate-900 text-white" : "bg-white hover:bg-slate-50"}`}>{f.label}</motion.button>
            ))}
          </div>
        </motion.div>

        <div className="mt-6 space-y-4">
          <AnimatePresence>
            {result.patient.length > 0 && (view === "all" || view === "ci" || view === "cons") && (
              <motion.div {...fadeUp} exit={{ opacity: 0, y: 8 }} className="rounded-2xl border-l-4 border-slate-200 bg-slate-50 p-4">
                <div className="mb-2 text-sm font-semibold text-slate-700">Facteurs patient</div>
                <ul className="list-disc pl-5 text-sm text-slate-800">
                  {result.patient.map((p, idx) => (<li key={idx}><span className="font-medium">{p.level}</span> — {p.message}</li>))}
                </ul>
              </motion.div>
            )}
          </AnimatePresence>

          <AnimatePresence>
            {(view === "all" || view === "alc") && result.alcohol.length > 0 && (
              <motion.div {...fadeUp} exit={{ opacity: 0, y: 8 }} className="rounded-2xl border border-rose-200 bg-rose-50 p-4">
                <div className="mb-2 text-sm font-semibold text-rose-700">Alcool — éviter l'association</div>
                {(["Contre-indiqué", "Déconseillé", "Précaution", "À prendre en compte", "Aucune connue"] as Level[]).map((lvl) => {
                  const items = (result.alcohol as any[]).filter(a => a.level === lvl);
                  if (!items.length) return null;
                  return (
                    <div key={lvl} className="mb-3">
                      <div className="mb-1 flex items-center gap-2 text-sm font-medium text-rose-800"><BadgeLevel level={lvl} /></div>
                      <ul className="space-y-2">
                        {items.map((a, i) => (<motion.li key={i} {...fadeIn} className="rounded-xl border bg-white p-3 text-sm shadow-sm"><div className="font-medium text-slate-900">{a.drug} + Alcool</div><div className="mt-1 text-slate-800">{a.message}</div></motion.li>))}
                      </ul>
                    </div>
                  );
                })}
              </motion.div>
            )}
          </AnimatePresence>

          {(view === "all" || view === "ci") && (result.pairs as any[]).filter(p => p.level === "Contre-indiqué").length > 0 && (
            <Section title="Contre‑indication" tone="red" items={(result.pairs as any[]).filter(p => p.level === "Contre-indiqué")} />
          )}

          {(view === "all" || view === "cons") && (
            <>
              {(result.pairs as any[]).filter(p => p.level === "Déconseillé").length > 0 && (
                <Section title="Déconseillé" tone="amber" items={(result.pairs as any[]).filter(p => p.level === "Déconseillé")} />
              )}
              {(result.pairs as any[]).filter(p => p.level === "Précaution").length > 0 && (
                <Section title="Précautions / Surveillance" tone="yellow" items={(result.pairs as any[]).filter(p => p.level === "Précaution")} />
              )}
            </>
          )}

          {(view === "all" || view === "ok") && (result.pairs as any[]).filter(p => p.level === "Aucune connue").length > 0 && (
            <Section title="Aucune interaction significative connue" tone="emerald" items={(result.pairs as any[]).filter(p => p.level === "Aucune connue")} />
          )}
        </div>

        <motion.p {...fadeIn} className="mt-6 text-xs text-slate-500">⚠️ Démonstrateur: ne remplace pas l'avis d'un professionnel. Données simplifiées pour l'aperçu.</motion.p>
      </div>
    </div>
  );
}
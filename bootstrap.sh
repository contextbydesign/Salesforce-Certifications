set -euo pipefail
npm create vite@latest . -- --template react-ts >/dev/null 2>&1 || true
npm pkg set name="sf-admin-exam-slds" private=true
npm pkg set scripts.dev="vite" scripts.build="vite build" scripts.preview="vite preview"
npm i @salesforce-ux/design-system react react-dom
mkdir -p public/assets/icons
cp -R node_modules/@salesforce-ux/design-system/assets/icons/* public/assets/icons/
cat > index.html <<'EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8"/><title>Salesforce Admin Practice (2025)</title><meta name="viewport" content="width=device-width,initial-scale=1"/><link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@salesforce-ux/design-system@2.28.0/assets/styles/salesforce-lightning-design-system.min.css"></head><body class="slds-theme_default slds-scope"><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
mkdir -p src
cat > src/main.tsx <<'EOF'
import React from "react"; import { createRoot } from "react-dom/client"; import App from "./App";
createRoot(document.getElementById("root")!).render(<App />); EOF
cat > src/engine.ts <<'EOF'
export type Question={id:string;domain:string;subtopic?:string;type:"single"|"multi";stem:string;options:string[];answers:string[];explanation?:string;rationale?:Record<string,string>;refs?:string[];release?:string;};
export const QUOTAS:Record<string,number>={"Configuration & Setup":12,"Object Manager & Lightning App Builder":12,"Sales & Marketing Applications":7,"Service & Support Applications":7,"Productivity & Collaboration":4,"Data & Analytics Management":8,"Workflow/Process Automation":10};
export function shuffle<T>(a:T[]){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
export function buildExam(bank:Question[],releaseTag="Current",wanted=60){const by:Record<string,Question[]>= {}; bank.forEach(q=>{(by[q.domain]??=[]).push(q);}); const out:Question[]=[]; for(const [d,n] of Object.entries(QUOTAS)){const pool=shuffle((by[d]||[]).filter(q=>releaseTag==="Current"? (q.release??"Current")!=="Legacy":(q.release??"Current")===releaseTag)); if(pool.length<n) throw new Error(`Not enough questions for "${d}" in "${releaseTag}" (need ${n}, have ${pool.length}).`); out.push(...pool.slice(0,n));} return shuffle(out).slice(0,Math.min(wanted,out.length));}
EOF
cat > src/App.tsx <<'EOF'
import React,{useEffect,useMemo,useState}from"react";import{buildExam,QUOTAS,Question}from"./engine";
type ExamState="config"|"running"|"review";
export default function App(){const[bank,setBank]=useState<Question[]>([]);const[state,setState]=useState<ExamState>("config");const[release,setRelease]=useState<"Current"|"Winter '24">("Current");const[count,setCount]=useState(60);const[exam,setExam]=useState<Question[]>([]);const[idx,setIdx]=useState(0);const[ans,setAns]=useState<Record<string,string[]>>({});const[sub,setSub]=useState<Record<string,boolean>>({});const[flag,setFlag]=useState<Record<string,boolean>>({});const[secs,setSecs]=useState(0);useEffect(()=>{(async()=>{const r=await fetch("/data/admin_current.json");const j=await r.json();setBank(j.questions as Question[]);})();},[]);useEffect(()=>{if(state!=="running")return;const t=setInterval(()=>setSecs(s=>s+1),1e3);return()=>clearInterval(t);},[state]);const cur=exam[idx];function start(){const built=buildExam(bank,release,count);setExam(built);setIdx(0);setAns({});setSub({});setFlag({});setSecs(0);setState("running");}function pick(L:string){if(!cur)return;setAns(a=>{const p=new Set(a[cur.id]||[]);if(cur.type==="multi"){p.has(L)?p.delete(L):p.add(L);return{...a,[cur.id]:Array.from(p).sort()};}return{...a,[cur.id]:[L]};});}function submit(){if(!cur)return;setSub(s=>({...s,[cur.id]:true}));}
const results=useMemo(()=>exam.map((q,i)=>{const p=ans[q.id]||[];const ok=p.length===q.answers.length&&p.every(x=>q.answers.includes(x));return{index:i,id:q.id,picked:p,correct:ok,q};}),[ans,exam]);
const score=useMemo(()=>{const ok=results.filter(r=>r.correct).length;return exam.length?Math.round(ok/exam.length*100):0;},[results,exam]);
const time=`${String(Math.floor(secs/60)).padStart(2,"0")}:${String(secs%60).padStart(2,"0")}`;
return(<div className="slds-p-around_medium">
<header className="slds-global-header slds-grid slds-grid_vertical-align-center slds-p-around_small">
  <div className="slds-global-header__item slds-global-header__logo"><span className="slds-text-title_caps">Admin Practice (2025)</span></div>
  <div className="slds-global-header__item slds-grid slds-grid_align-spread slds-col_bump-left">
    <span className="slds-badge slds-theme_info">Time: {time}</span>
    {state!=="config"&&<span className="slds-badge">Q {idx+1} / {exam.length}</span>}
    {state==="running"&&<button className="slds-button slds-button_brand" onClick={()=>setState("review")}>Finish</button>}
  </div>
</header>
{state==="config"&&(<section className="slds-card slds-m-bottom_large"><div className="slds-card__header slds-grid"><header className="slds-media slds-media_center slds-has-flexi-truncate"><div className="slds-media__body"><h2 className="slds-card__header-title">Exam Configuration</h2></div></header></div><div className="slds-card__body slds-card__body_inner"><div className="slds-form slds-form_stacked">
  <div className="slds-form-element"><label className="slds-form-element__label" htmlFor="rel">Release</label><div className="slds-form-element__control"><div className="slds-select_container"><select id="rel" className="slds-select" value={release} onChange={e=>setRelease(e.target.value as any)}><option>Current</option><option>Winter '24</option></select></div></div></div>
  <div className="slds-form-element"><label className="slds-form-element__label" htmlFor="cnt">Number of Questions</label><div className="slds-form-element__control"><input id="cnt" className="slds-input" type="number" min={10} max={65} value={count} onChange={e=>setCount(parseInt(e.target.value||"60",10))}/></div></div>
  <button className="slds-button slds-button_brand" onClick={start}>Start Exam</button>
  <p className="slds-text-color_weak slds-m-top_small">Quotas enforced: {Object.entries(QUOTAS).map(([k,v])=>`${k} ${v}`).join(" · ")}</p>
</div></div></section>)}
{state==="running"&&cur&&(<section className="slds-card"><div className="slds-card__header slds-grid"><header className="slds-media slds-media_center slds-has-flexi-truncate"><div className="slds-media__body"><h2 className="slds-card__header-title">Question {idx+1}{cur.type==="multi"&&<span className="slds-badge slds-m-left_x-small">Choose {cur.answers.length}</span>}</h2></div><div className="slds-no-flex"><button className="slds-button slds-button_outline-brand" onClick={()=>setFlag(f=>({...f,[cur.id]:!f[cur.id]}))}>{flag[cur.id]?"Unflag":"Flag"}</button></div></header></div>
<div className="slds-card__body slds-card__body_inner">
  <p className="slds-text-heading_small slds-m-bottom_small">{cur.stem}</p>
  <div className="slds-form slds-form_compact" role="group" aria-label="answers">
    {cur.options.map((opt,i)=>{const L=String.fromCharCode(65+i);const picked=(ans[cur.id]||[]).includes(L);const name=`q-${cur.id}`;const isMulti=cur.type==="multi";return(
      <div className="slds-form-element slds-m-bottom_x-small" key={L}><div className="slds-form-element__control">
        <span className={isMulti?"slds-checkbox":"slds-radio"}>
          <input type={isMulti?"checkbox":"radio"} id={`${name}-${L}`} name={name} checked={picked} onChange={()=>pick(L)}/>
          <label className={isMulti?"slds-checkbox__label":"slds-radio__label"} htmlFor={`${name}-${L}`}>
            <span className={isMulti?"slds-checkbox_faux":"slds-radio_faux"}></span>
            <span className="slds-form-element__label">{L}. {opt}</span>
          </label>
        </span>
      </div></div>);})}
  </div>
  <div className="slds-m-top_small">
    <button className="slds-button slds-button_brand slds-m-right_small" onClick={submit}>Submit</button>
    <button className="slds-button slds-button_neutral" onClick={()=>setIdx(i=>Math.min(i+1,exam.length-1))}>Next</button>
    {idx>0&&<button className="slds-button slds-button_neutral slds-m-left_x-small" onClick={()=>setIdx(i=>Math.max(i-1,0))}>Prev</button>}
  </div>
  {sub[cur.id]&&(<article className="slds-m-top_medium"><div className="slds-text-title_caps">Explanation</div><p className="slds-text-body_regular">{cur.explanation||"—"}</p>{cur.rationale&&Object.keys(cur.rationale).length>0&&(<><div className="slds-text-title_caps slds-m-top_small">Why others are wrong</div><ul className="slds-list_dotted">{Object.entries(cur.rationale).map(([k,t])=>(<li key={k}><strong>{k}.</strong> {t}</li>))}</ul></>)}{cur.refs&&cur.refs.length>0&&(<><div className="slds-text-title_caps slds-m-top_small">References</div><ul className="slds-list_dotted">{cur.refs.map((u,i)=>(<li key={i}><a href={u} target="_blank" rel="noopener">{u}</a></li>))}</ul></>)}</article>)}
</div></section>)}
{state==="review"&&(<section className="slds-card slds-m-top_large"><div className="slds-card__header slds-grid"><header className="slds-media slds-media_center slds-has-flexi-truncate"><div className="slds-media__body"><h2 className="slds-card__header-title">Results</h2></div></header></div><div className="slds-card__body slds-card__body_inner"><p><span className="slds-text-title">Score:</span> {score}%</p><p><span className="slds-text-title">Time Taken:</span> {time}</p></div></section>)}
</div>);}
EOF

# seed data
mkdir -p public/data
cat > public/data/admin_current.json <<'EOF'
{ "meta": { "cert": "Platform Administrator", "version": "Current" },
  "questions": [
    { "id":"ADM-25-0001","domain":"Object Manager & Lightning App Builder","type":"single",
      "stem":"Reps need stage-by-stage tips on Opportunities with visual cues. What should you enable?",
      "options":["Kanban View","Path","Lightning Record Page","Sales Console"],"answers":["B"],
      "explanation":"Path shows stages + Guidance for Success inline for reps.",
      "rationale":{"A":"Kanban visualizes records but not stage guidance.","C":"Record pages are layout only.","D":"Console is a workspace, not a stage coach."},
      "refs":["https://trailhead.salesforce.com/content/learn/trails/administrator-certification-prep"],"release":"Current" },
    { "id":"ADM-25-0002","domain":"Workflow/Process Automation","type":"single",
      "stem":"A team must transform a collection in Flow without loops/assignments. Which element should the admin use?",
      "options":["Apex action","Subflow","Transform","Assignment"],"answers":["C"],
      "explanation":"Winter ’24 introduced the Transform element to reshape collections.",
      "refs":["https://help.salesforce.com/s/articleView?id=release-notes.rn_automate_flow_builder_transform.htm&type=5&release=246"],
      "release":"Winter '24" }
  ] }
EOF

# migration script
mkdir -p scripts old
cat > scripts/migrate-admin.mjs <<'EOF'
import fs from "fs";
const IN="old/admin.json", OUT="public/data/admin_migrated.json";
const legacy=[/mobile\s+lite/i,/chatter\s+(desktop|messenger)/i,/\bideas?\b/i,/\banswers\b/i,/sales\s*cloud2|service\s*cloud2/i];
const isLegacy=s=>legacy.some(r=>r.test(s||""));
function norm(raw,idx){
  const stem=raw.question||raw.stem||raw.text||""; const opts=raw.options||raw.choices||[raw.A,raw.B,raw.C,raw.D,raw.E].filter(Boolean);
  let answers=[]; if(Array.isArray(raw.answers)){answers=raw.answers.map(x=>typeof x==="number"?String.fromCharCode(65+x):String(x));
  }else if(typeof raw.answer==="string"){const m=raw.answer.trim().toUpperCase(); answers=/^[A-E]$/.test(m)?[m]:["A"];
  }else if(typeof raw.correct==="number"){answers=[String.fromCharCode(65+raw.correct)];} else {answers=["A"];}
  const domain=raw.domain||raw.category||raw.section||"Uncategorized"; const type=(answers.length>1||/choose\s+\d+/i.test(stem))?"multi":"single";
  const explanation=raw.explanation||raw.reason||""; const rationale={}; ["A","B","C","D","E"].forEach(L=>{if(raw[`rationale_${L}`]) rationale[L]=raw[`rationale_${L}`];});
  const legacyFlag=isLegacy([stem,explanation,...(opts||[])].join(" "));
  return {id:raw.id?String(raw.id):`LEG-${idx+1}`,domain,type,stem,options:opts,answers:answers.map(x=>x.toUpperCase()),explanation,rationale,refs:raw.refs||[],release:legacyFlag?"Legacy":"Current",tags:legacyFlag?["legacy-flag"]:[]};
}
if(!fs.existsSync(IN)){console.error(`Put your old admin.json at ${IN}`);process.exit(1);}
const src=JSON.parse(fs.readFileSync(IN,"utf8")); const list=Array.isArray(src)?src:(src.questions||[]);
const questions=list.map(norm); fs.mkdirSync("public/data",{recursive:true});
fs.writeFileSync(OUT,JSON.stringify({meta:{cert:"Platform Administrator",version:"Migrated"},questions},null,2));
console.log(`Wrote ${OUT} with ${questions.length} items. Legacy flagged: ${questions.filter(q=>q.release==="Legacy").length}`);
EOF

# Pages workflow
mkdir -p .github/workflows
cat > .github/workflows/pages.yml <<'EOF'
name: Deploy to GitHub Pages
on: { push: { branches: [ main ] } }
permissions: { contents: read, pages: write, id-token: write }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 18 }
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-pages-artifact@v3
        with: { path: dist }
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-pages@v4
EOF

npm i
echo "Bootstrap complete."

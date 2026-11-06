const supabaseClient = window.supabase.createClient(window.ATI_SUPABASE_URL, window.ATI_SUPABASE_PUBLISHABLE_KEY);
const demoTrades=[["DEMO-804291","XAUUSD","Buy","Nov 06 10:14","2742.60","2751.40",176,"Win"],["DEMO-804277","EURUSD","Sell","Nov 06 08:42","1.08742","1.08810",-20.4,"Loss"],["DEMO-804251","GBPUSD","Buy","Nov 05 14:06","1.29410","1.29720",46.5,"Win"],["DEMO-804209","XAUUSD","Sell","Nov 05 09:22","2758.30","2761.10",-28,"Loss"]];
let journalRows=demoTrades,authMode="signin";
function setAuthMessage(message){document.getElementById("authMessage").textContent=message}
function showAuth(show){document.getElementById("authGate").classList.toggle("hidden",!show)}
function setAuthMode(mode){authMode=mode;document.getElementById("authTitle").textContent=mode==="signup"?"Create your account":"Welcome back";document.getElementById("authDescription").textContent=mode==="signup"?"Create a secure account for your private trading records.":"Sign in to access your personal trading workspace.";document.getElementById("authSubmit").textContent=mode==="signup"?"Create account":"Sign in";document.getElementById("authSwitch").textContent=mode==="signup"?"Already registered? Sign in":"New here? Create an account";document.getElementById("authPassword").autocomplete=mode==="signup"?"new-password":"current-password";setAuthMessage("")}
async function ensureProfile(user){const {error}=await supabaseClient.from("profiles").upsert({id:user.id,display_name:user.email?.split("@")[0]||"Trader"},{onConflict:"id"});if(error)console.warn("Profile initialization:",error.message)}
async function onSession(session){if(session?.user){showAuth(false);document.getElementById("userEmail").textContent=session.user.email||"Signed in";await ensureProfile(session.user);await loadUserTrades();await loadAnalytics(session)}else{showAuth(true);document.getElementById("userEmail").textContent=""}}
document.getElementById("authSwitch").addEventListener("click",()=>setAuthMode(authMode==="signin"?"signup":"signin"));
document.getElementById("authForm").addEventListener("submit",async e=>{e.preventDefault();const email=document.getElementById("authEmail").value.trim(),password=document.getElementById("authPassword").value;const button=document.getElementById("authSubmit");button.disabled=true;setAuthMessage("Please wait…");try{if(authMode==="signup"){const {data,error}=await supabaseClient.auth.signUp({email,password,options:{emailRedirectTo:window.location.origin+"/"}});if(error)throw error;if(data.session){await onSession(data.session)}else{setAuthMessage("Account created. Check your email to confirm your address, then return here to sign in.")}}else{const {data,error}=await supabaseClient.auth.signInWithPassword({email,password});if(error)throw error;await onSession(data.session)}}catch(err){setAuthMessage(err.message||"Authentication failed. Please try again.")}finally{button.disabled=false}});
document.getElementById("signOut").addEventListener("click",async()=>{const {error}=await supabaseClient.auth.signOut();if(error)alert(error.message);else{journalRows=demoTrades;render();showAuth(true)}});
async function loadUserTrades(){const {data,error}=await supabaseClient.from("trades").select("id,symbol,side,opened_at,entry_price,exit_price,net_profit,result").order("opened_at",{ascending:false}).limit(250);if(error){console.warn("Trade sync read:",error.message);return}if(data?.length){journalRows=data.map(t=>[t.id,t.symbol,t.side,t.opened_at?new Date(t.opened_at).toLocaleString():"",t.entry_price??"",t.exit_price??"",Number(t.net_profit||0),t.result||"Open"]);}else{journalRows=demoTrades}render()}
function render(){const q=(document.getElementById("search")?.value||"").toLowerCase();const rows=journalRows.filter(t=>(String(t[0])+String(t[1])).toLowerCase().includes(q));document.getElementById("rows").innerHTML=rows.map(t=>"<tr>"+t.map((v,i)=>"<td>"+(i===6?(Number(v)>=0?"+$":"-$")+Math.abs(Number(v)).toFixed(2):String(v))+"</td>").join("")+"</tr>").join("")||'<tr><td colspan="8">No trades recorded yet</td></tr>'}
document.querySelectorAll("[data-tab]").forEach(b=>b.onclick=()=>{const target=b.dataset.tab;document.querySelectorAll(".page").forEach(p=>p.classList.toggle("active",p.id===target));document.querySelectorAll(".sidebar nav [data-tab]").forEach(x=>x.classList.toggle("active",x.dataset.tab===target));const navLabel=document.querySelector(".sidebar nav [data-tab=\""+target+"\"]");document.getElementById("crumb").textContent=navLabel?navLabel.textContent.trim():b.textContent.trim()});
document.getElementById("search").oninput=render;
document.getElementById("csv").onclick=()=>{const csv=["Ticket,Symbol,Side,Opened,Entry,Exit,NetPL,Result",...journalRows.map(t=>t.join(","))].join("\n");const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([csv],{type:"text/csv"}));a.download="trading-journal.csv";a.click();URL.revokeObjectURL(a.href)};
supabaseClient.auth.onAuthStateChange((_event,session)=>{onSession(session)});
supabaseClient.auth.getSession().then(({data})=>onSession(data.session));
render();
async function loadAnalytics(session){
  try{
    const response=await fetch(window.ATI_API_URL+"/analytics/summary",{headers:{Authorization:"Bearer "+session.access_token,"X-Timezone":"Asia/Kolkata"}});
    if(!response.ok)throw new Error("Analytics service unavailable");
    const m=await response.json();
    const money=v=>new Intl.NumberFormat("en-US",{style:"currency",currency:"USD",maximumFractionDigits:2}).format(v||0);
    document.getElementById("netProfitMetric").textContent=money(m.net_profit);
    document.getElementById("winRateMetric").textContent=(m.win_rate_pct||0).toFixed(1)+"%";
    document.getElementById("profitFactorMetric").textContent=m.profit_factor===null?"—":m.profit_factor==="infinite"?"∞":Number(m.profit_factor).toFixed(2);
    document.getElementById("drawdownMetric").textContent=money(m.max_drawdown_currency);
    document.getElementById("dataNotice").textContent=m.closed_trades+" closed trades loaded from your private journal. All metrics are calculated from your authenticated records.";
    document.getElementById("dataNotice").classList.add("verified");
  }catch(err){console.warn("Analytics summary:",err.message)}
}

document.addEventListener("DOMContentLoaded",()=>{
  const enroll=document.getElementById("enrollMt5");
  if(!enroll)return;
  const status=document.getElementById("mt5EnrollStatus");
  const list=document.getElementById("mt5Connections");
  const tokenPanel=document.getElementById("mt5TokenPanel");
  const api=window.ATI_API_URL;

  async function signedInSession(){
    const result=await supabaseClient.auth.getSession();
    if(result.error)throw result.error;
    if(!result.data.session)throw new Error("Please sign in again.");
    return result.data.session;
  }
  async function apiRequest(path,options={}){
    const session=await signedInSession();
    const response=await fetch(api+path,{
      ...options,
      headers:{
        "Authorization":"Bearer "+session.access_token,
        ...(options.body?{"Content-Type":"application/json"}:{}),
        ...(options.headers||{})
      }
    });
    const result=await response.json().catch(()=>({}));
    if(!response.ok)throw new Error(result.detail||"Request failed.");
    return result;
  }
  function escapeHtml(value){
    return String(value).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#39;");
  }
  function dateLabel(value){
    if(!value)return "Never";
    const date=new Date(value);
    return Number.isNaN(date.getTime())?"—":date.toLocaleString();
  }
  async function loadConnections(){
    if(!list)return;
    list.innerHTML='<p class="muted">Loading connected devices…</p>';
    try{
      const result=await apiRequest("/connector/connections");
      const connections=result.connections||[];
      if(!connections.length){
        list.innerHTML='<p class="muted">No MT5 devices enrolled yet.</p>';
        return;
      }
      list.innerHTML=connections.map(c=>{
        const active=c.status==="active"&&!c.revoked_at;
        const state=active?"Active":"Revoked";
        return '<article class="connector-device"><div><b>'+escapeHtml(c.device_label||"Windows PC")+'</b><span class="connector-state '+(active?"is-active":"")+'">'+state+'</span><p class="muted">Enrolled: '+escapeHtml(dateLabel(c.enrolled_at))+'</p><p class="muted">Last sync: '+escapeHtml(dateLabel(c.last_seen_at))+'</p></div>'+(active?'<button type="button" class="revoke-device" data-id="'+escapeHtml(c.id)+'">Revoke</button>':'')+'</article>';
      }).join("");
    }catch(error){list.innerHTML='<p class="muted">'+escapeHtml(error.message)+'</p>'}
  }

  enroll.addEventListener("click",async()=>{
    enroll.disabled=true;
    status.textContent="Creating secure connector…";
    try{
      const result=await apiRequest("/connector/enroll",{
        method:"POST",
        body:JSON.stringify({
          account_label:document.getElementById("mt5AccountLabel").value.trim()||"My MT5 account",
          device_label:document.getElementById("mt5DeviceLabel").value.trim()||"My Windows PC",
          connector_version:"1.2.0"
        })
      });
      document.getElementById("mt5Token").value=result.connector_token;
      document.getElementById("mt5SetupCommand").textContent='[Environment]::SetEnvironmentVariable("ATI_CONNECTOR_TOKEN", "'+result.connector_token+'", "User")';
      tokenPanel.classList.remove("hidden");
      status.textContent="Connector enrolled. Copy and store the token securely; it will not be shown again.";
      await loadConnections();
    }catch(error){status.textContent=error.message||"Could not enroll connector."}
    finally{enroll.disabled=false}
  });

  list?.addEventListener("click",async event=>{
    const button=event.target.closest(".revoke-device");
    if(!button)return;
    const id=button.dataset.id;
    if(!id||!confirm("Revoke this connector? Future uploads from this computer will be rejected."))return;
    button.disabled=true;
    try{
      await apiRequest("/connector/revoke/"+encodeURIComponent(id),{method:"POST"});
      status.textContent="Connector revoked successfully.";
      await loadConnections();
    }catch(error){
      status.textContent=error.message||"Could not revoke connector.";
      button.disabled=false;
    }
  });

  document.getElementById("revokeMt5").addEventListener("click",async()=>{
    status.textContent="Use the connected devices list below to revoke a computer.";
    await loadConnections();
  });
  document.getElementById("copyMt5Token").addEventListener("click",async()=>{
    try{
      await navigator.clipboard.writeText(document.getElementById("mt5Token").value);
      status.textContent="Connector token copied.";
    }catch(error){status.textContent="Select and copy the token manually."}
  });

  supabaseClient.auth.getSession().then(({data})=>{if(data.session)loadConnections()});
  supabaseClient.auth.onAuthStateChange((_event,session)=>{if(session)loadConnections();else if(list)list.innerHTML=""});
});
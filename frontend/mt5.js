document.addEventListener("DOMContentLoaded",()=>{
  const enroll=document.getElementById("enrollMt5");
  if(!enroll)return;
  const status=document.getElementById("mt5EnrollStatus");
  let activeConnectionId=null;
  enroll.addEventListener("click",async()=>{
    enroll.disabled=true;
    status.textContent="Creating secure connector…";
    try{
      const sessionResult=await supabaseClient.auth.getSession();
      const session=sessionResult.data.session;
      if(!session)throw new Error("Please sign in again.");
      const response=await fetch(window.ATI_API_URL+"/connector/enroll",{
        method:"POST",
        headers:{"Authorization":"Bearer "+session.access_token,"Content-Type":"application/json"},
        body:JSON.stringify({
          account_label:document.getElementById("mt5AccountLabel").value.trim()||"My MT5 account",
          device_label:document.getElementById("mt5DeviceLabel").value.trim()||"My Windows PC",
          connector_version:"1.1.0"
        })
      });
      const result=await response.json();
      if(!response.ok)throw new Error(result.detail||"Connector enrollment failed.");
      activeConnectionId=result.connection_id;
      document.getElementById("mt5Token").value=result.connector_token;
      document.getElementById("mt5SetupCommand").textContent='[Environment]::SetEnvironmentVariable("ATI_CONNECTOR_TOKEN", "'+result.connector_token+'", "User")';
      document.getElementById("mt5TokenPanel").classList.remove("hidden");
      status.textContent="Connector enrolled. Save the token securely; it is displayed only once.";
    }catch(error){status.textContent=error.message||"Could not enroll connector."}
    finally{enroll.disabled=false}
  });
  document.getElementById("revokeMt5").addEventListener("click",async()=>{
    if(!activeConnectionId){status.textContent="Revoke is available immediately after enrollment.";return}
    if(!confirm("Revoke this connector? Future uploads from this Windows computer will be rejected."))return;
    try{
      const session=(await supabaseClient.auth.getSession()).data.session;
      const response=await fetch(window.ATI_API_URL+"/connector/revoke/"+encodeURIComponent(activeConnectionId),{method:"POST",headers:{"Authorization":"Bearer "+session.access_token}});
      const result=await response.json();
      if(!response.ok)throw new Error(result.detail||"Could not revoke connector.");
      status.textContent="Connector revoked. Its token can no longer upload trading history.";
      activeConnectionId=null;
    }catch(error){status.textContent=error.message||"Could not revoke connector."}
  });
  document.getElementById("copyMt5Token").addEventListener("click",async()=>{
    try{
      await navigator.clipboard.writeText(document.getElementById("mt5Token").value);
      status.textContent="Connector token copied.";
    }catch(error){status.textContent="Select and copy the token manually."}
  });
});

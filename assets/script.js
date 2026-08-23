dil=()=>{if(!localStorage.in&&localStorage.xrl){document.querySelectorAll('img').forEach(a=>{a.style.filter='blur(50px)'})}};dil()

if(!localStorage.xrl){
  (async()=>{
    let aa=await(await(await fetch('https://ipapi.co/json')).json());
    localStorage.xrl=JSON.stringify(aa);
    if(aa.country_name=='India'){localStorage.in=1}
    dil()
  })();
}


jdfo.onsubmit = (e) => {
  e.preventDefault();
  location.href =  fiwu.value;
}


let no
(async()=>{
  no=await(await(await fetch('/assets/num.json')).json());

  document.querySelectorAll('.call').forEach(a=>{
      a.href='tel:+91'+no[scrt.dataset.title]
  });
  document.querySelectorAll('.wapp').forEach(a=>{
      a.href=`https://wa.me/+91${no[scrt.dataset.title]}?text=Hello,+I+saw+your+profile+in+${scrt.dataset.title}+(${location.host}).`
  });
})();







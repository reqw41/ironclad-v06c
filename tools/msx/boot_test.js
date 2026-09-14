// проба: WebMSX (headless, из knightmare-v06c/tools/msxjs) грузит IRONCLAD.DSK оригинала
const fs=require('fs');
const B='/Users/boris/projects/knightmare-v06c/tools/msxjs';
console.log=(...a)=>process.stderr.write(a.join(' ')+'\n'); console.info=console.log; console.warn=console.log;
require(B+'/env.js');
const loc={href:"http://localhost/",origin:"http://localhost",protocol:"http:",host:"localhost",hostname:"localhost",port:"",pathname:"/",search:"",hash:""};
global.window.location=loc; global.location=loc;
global.setInterval=()=>0; global.clearInterval=()=>{};
global.setTimeout=(f)=>{ if(typeof f==="function"){ try{f()}catch(e){} } return 0; };
global.window.setInterval=()=>0; global.window.clearInterval=()=>{}; global.window.setTimeout=global.setTimeout;
global.JSZip=require(B+'/../../node_modules/jszip');
const se=global.document.createElement('div'); global.document.getElementById=()=>se;
global.WMSX={SCREEN_ELEMENT_ID:'s',screenElement:se,MACHINE:process.env.MSX_MACHINE||'MSX2E',AUTO_POWER_ON:true};
require(B+'/wmsx.js');
const W=global.WMSX; W.start();
const dsk=new Uint8Array(fs.readFileSync('/Users/boris/projects/ironclad-v06c/ref/ironclad-msx/release/IRONCLAD.DSK'));
W.fileLoader.loadFromContent('IRONCLAD.DSK',dsk,undefined,0,false,false);
const m=W.room.machine; m.powerOff&&m.powerOff(); m.powerOn();
function frames(n){for(let i=0;i<n;i++)m.videoClockPulse();}
for(let t=0;t<40;t++){frames(100); const v=m.vdp; const r2=(v.register||[])[2]; console.error('кадр',(t+1)*100,'PC',(m.cpu.saveState().PC&0xffff).toString(16),'SCRMOD',m.bus.read(0xFCAF));}

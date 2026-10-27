/* Calendar-day math and the portable iOS v1/v2 JSON backup contract. */
(function (root) {
  'use strict';
  const GROUPS = ['Family', 'Friend', 'Partner', 'Work', 'School', 'Other'];
  const OFFSETS = [0, 1, 3, 7, 14, 30];
  const DEFAULTS = {hasCompletedOnboarding:false, defaultReminderDays:[7,1,0], notificationHour:9, notificationMinute:0, accentIndex:0, showAge:true, showZodiac:false, showDaysRemaining:true, showBackgroundArt:true, smartRemindersEnabled:true};
  const uid = () => globalThis.crypto?.randomUUID?.() || 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c => { const r=Math.random()*16|0;return (c==='x'?r:(r&3|8)).toString(16); });
  const today = (now=new Date()) => new Date(now.getFullYear(),now.getMonth(),now.getDate());
  const resolved = (year,month,day) => new Date(year,month-1,Math.min(day,new Date(year,month,0).getDate()));
  function next(p,now=new Date()) {let date=resolved(now.getFullYear(),p.birthMonth,p.birthDay);if(date<today(now))date=resolved(now.getFullYear()+1,p.birthMonth,p.birthDay);return date;}
  const dayNumber = d => Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())/86400000;
  const days = (p,now=new Date()) => dayNumber(next(p,now))-dayNumber(today(now));
  const turning = (p,now=new Date()) => p.birthYear==null?null:Math.max(0,next(p,now).getFullYear()-p.birthYear);
  function age(p,now=new Date()) {if(p.birthYear==null)return null;const d=resolved(now.getFullYear(),p.birthMonth,p.birthDay);return Math.max(0,now.getFullYear()-p.birthYear-(today(now)<d?1:0));}
  const month = (m,short=false) => new Date(2000,m-1,1).toLocaleDateString(undefined,{month:short?'short':'long'});
  const shortDate = p => resolved(2000,p.birthMonth,p.birthDay).toLocaleDateString(undefined,{month:'short',day:'numeric'});
  const fullDate = p => resolved(p.birthYear||2000,p.birthMonth,p.birthDay).toLocaleDateString(undefined,{month:'long',day:'numeric',...(p.birthYear?{year:'numeric'}:{})});
  function countdown(n) {if(n===0)return 'Today';if(n===1)return 'Tomorrow';if(n<14)return n+' days';if(n<60)return Math.round(n/7)+' weeks';return Math.max(1,Math.round(n/30.44))+' month'+(Math.round(n/30.44)>1?'s':'');}
  const name = p => [p.firstName,p.lastName].filter(Boolean).join(' ').trim()||'Unnamed';
  const first = p => p.firstName||name(p);
  const initials = p => ((p.firstName||'').trim().charAt(0)+(p.lastName||'').trim().charAt(0)).toUpperCase()||'?';
  function zodiac(p) {const cuts=[20,19,21,20,21,21,23,23,23,23,22,22],names=['Capricorn','Aquarius','Pisces','Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn'];return names[p.birthMonth-1+(p.birthDay>=cuts[p.birthMonth-1]?1:0)];}
  const ordinal = n => n+(['th','st','nd','rd'][(n%100>10&&n%100<14)?0:(n%10>3?0:n%10)]);
  const message = p => `Happy ${turning(p)==null?'':ordinal(turning(p))+' '}birthday, ${first(p)}! 🎂 Wishing you a wonderful day.`;
  const sorted = (people,now=new Date()) => [...people].sort((a,b)=>days(a,now)-days(b,now)||name(a).localeCompare(name(b)));
  function person(fields={}) {return {uuid:uid(),firstName:'',lastName:'',birthMonth:1,birthDay:1,birthYear:null,relationshipRaw:null,isFavorite:false,notes:'',celebrationIntent:'',celebrationBudget:0,celebrationChecklist:[],completedCelebrationSteps:[],connectionCadence:0,lastConnectionDate:null,connectionJournal:[],photoData:null,contactIdentifier:null,phone:'',email:'',usesCustomReminders:false,customReminderDays:[],acknowledgedYear:null,createdAt:new Date().toISOString(),giftIdeas:[],giftHistory:[],...fields};}
  const empty = () => ({schemaVersion:1,revision:0,people:[],settings:{...DEFAULTS,defaultReminderDays:[...DEFAULTS.defaultReminderDays]}});
  function read(raw) {if(!raw)return empty();const s=JSON.parse(raw);if(s.schemaVersion!==1||!Array.isArray(s.people)||!Number.isInteger(s.revision)||!s.settings)throw Error('The saved birthday database could not be read. Your original data has been kept.');return {...s,settings:{...DEFAULTS,...s.settings}};}
  function validDate(m,d,y) {return Number.isInteger(m)&&m>=1&&m<=12&&Number.isInteger(d)&&d>=1&&d<=new Date(y||2000,m,0).getDate()&&(y==null||(Number.isInteger(y)&&y>=1&&y<=new Date().getFullYear()));}
  function validate(p) {
    if(typeof p.firstName!=='string'||typeof p.lastName!=='string'||!name(p).trim()||name(p)==='Unnamed')throw Error('Enter a first or last name.');
    if(!validDate(p.birthMonth,p.birthDay,p.birthYear))throw Error('Choose a valid birthday.');
    if(!Number.isFinite(p.celebrationBudget)||p.celebrationBudget<0)throw Error('Enter a budget of zero or more.');
    return p;
  }
  function backup(state) {return {app:'Next Birthday',version:2,exportedAt:new Date().toISOString(),people:state.people.map(p=>({firstName:p.firstName,lastName:p.lastName,month:p.birthMonth,day:p.birthDay,year:p.birthYear,relationship:p.relationshipRaw,isFavorite:p.isFavorite,notes:p.notes,usesCustomReminders:p.usesCustomReminders,customReminderDays:p.customReminderDays,giftIdeas:p.giftIdeas.filter(g=>!g.isPurchased).map(g=>g.title),giftedIdeas:p.giftIdeas.filter(g=>g.isPurchased).map(g=>g.title),giftHistory:p.giftHistory.map(g=>({year:g.year,item:g.item})),celebrationIntent:p.celebrationIntent,celebrationBudget:p.celebrationBudget,celebrationChecklist:p.celebrationChecklist,completedCelebrationSteps:p.completedCelebrationSteps,connectionCadence:p.connectionCadence,lastConnectionDate:p.lastConnectionDate,connectionJournal:p.connectionJournal,photoData:p.photoData,phone:p.phone,email:p.email}))};}
  const text = (v,fallback='') => typeof v==='string'?v:fallback;
  function stringList(v,key) {if(v==null)return [];if(!Array.isArray(v)||v.some(x=>typeof x!=='string'))throw Error('Invalid '+key+' in backup.');return v.slice();}
  function mergeBackup(state,raw) {
    const b=typeof raw==='string'?JSON.parse(raw):raw;
    if(!b||b.app!=='Next Birthday'||![1,2].includes(b.version)||!Array.isArray(b.people)||b.people.length>20000)throw Error("That file isn't a Next Birthday backup.");
    // Validate the entire input before changing any saved state.
    const imported=b.people.map(e=>{
      if(!e||typeof e.firstName!=='string'||typeof e.lastName!=='string'||!validDate(e.month,e.day,e.year??null))throw Error('A birthday in the backup is invalid. Nothing was imported.');
      const p=person({firstName:e.firstName.trim(),lastName:e.lastName.trim(),birthMonth:e.month,birthDay:e.day,birthYear:e.year??null,relationshipRaw:typeof e.relationship==='string'?e.relationship:null,isFavorite:e.isFavorite===true,notes:text(e.notes),usesCustomReminders:e.usesCustomReminders===true,customReminderDays:[]});
      if(e.customReminderDays!=null&&(!Array.isArray(e.customReminderDays)||e.customReminderDays.some(x=>!OFFSETS.includes(x))))throw Error('Invalid reminder offsets in backup.');
      p.customReminderDays=[...new Set(e.customReminderDays||[])];
      p.giftIdeas=[...stringList(e.giftIdeas,'gift ideas').map(title=>({uuid:uid(),title,isPurchased:false,createdAt:new Date().toISOString()})),...stringList(e.giftedIdeas,'gifted ideas').map(title=>({uuid:uid(),title,isPurchased:true,createdAt:new Date().toISOString()}))];
      if(e.giftHistory!=null&&(!Array.isArray(e.giftHistory)||e.giftHistory.some(g=>!g||!Number.isInteger(g.year)||typeof g.item!=='string')))throw Error('Invalid gift history in backup.');
      p.giftHistory=(e.giftHistory||[]).map(g=>({...g,uuid:uid()}));
      p.celebrationIntent=text(e.celebrationIntent);p.celebrationBudget=typeof e.celebrationBudget==='number'?Math.max(0,e.celebrationBudget):0;
      for(const k of ['celebrationChecklist','completedCelebrationSteps','connectionJournal'])p[k]=stringList(e[k],k);
      if(e.connectionCadence!=null&&![0,7,14,30,90].includes(e.connectionCadence))throw Error('Invalid connection cadence in backup.');
      p.connectionCadence=e.connectionCadence||0;
      if(e.lastConnectionDate!=null&&(!Number.isFinite(Date.parse(e.lastConnectionDate))))throw Error('Invalid connection date in backup.');
      p.lastConnectionDate=e.lastConnectionDate||null;
      p.photoData=typeof e.photoData==='string'&&/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(e.photoData)?e.photoData:null;
      p.phone=text(e.phone);p.email=text(e.email);return validate(p);
    });
    const key=p=>name(p).toLocaleLowerCase()+'|'+p.birthMonth+'-'+p.birthDay,keys=new Set(state.people.map(key));
    const result=structuredClone(state);let added=0,skipped=0;
    for(const p of imported){if(keys.has(key(p))){skipped++;continue;}keys.add(key(p));result.people.push(p);added++;}
    return {state:result,added,skipped};
  }
  function toggleGift(p,id,now=new Date()) {const g=p.giftIdeas.find(g=>g.uuid===id);if(!g)return;g.isPurchased=!g.isPurchased;const year=next(p,now).getFullYear();if(g.isPurchased){if(!p.giftHistory.some(r=>r.year===year&&r.item===g.title))p.giftHistory.push({uuid:uid(),year,item:g.title});}else{const i=p.giftHistory.findIndex(r=>r.year===year&&r.item===g.title);if(i>=0)p.giftHistory.splice(i,1);}}
  function due(people,now=new Date()) {return people.filter(p=>p.connectionCadence>0&&dayNumber(now)-dayNumber(new Date(p.lastConnectionDate||p.createdAt))>=p.connectionCadence).sort((a,b)=>Date.parse(a.lastConnectionDate||a.createdAt)-Date.parse(b.lastConnectionDate||b.createdAt));}
  function section(p,now=new Date()) {const n=days(p,now);return n===0?'Today':n===1?'Tomorrow':n<=7?'This Week':n<=14?'Next Week':month(next(p,now).getMonth()+1);}
  function demo(now=new Date()) {const state=empty();state.settings.hasCompletedOnboarding=true;state.people=[['Emma','Johnson',1,1997,'Sister',true,'Loves coffee, sunsets, and little weekend trips.'],['James','Smith',0,1992,'Best Friend',true,'Call in the morning. Dinner booked for 7:30 PM.'],['Olivia','Davis',4,1999,'Friend',false,'Collects ceramics and loves botanical gardens.'],['Noah','Brown',9,1994,'Work',false,'Team card is hidden in the top drawer.'],['Ava','Williams',18,1996,'Family',true,'Favorite flowers: peonies.'],['Alex','Johnson',34,1991,'Friend',false,'Planning a hiking trip this autumn.']].map(s=>{const d=new Date(now.getFullYear(),now.getMonth(),now.getDate()+s[2]);return person({firstName:s[0],lastName:s[1],birthMonth:d.getMonth()+1,birthDay:d.getDate(),birthYear:s[3],relationshipRaw:s[4],isFavorite:s[5],notes:s[6]});});const e=state.people[0];e.celebrationIntent='A sunrise picnic, just the two of us.';e.celebrationBudget=40;e.celebrationChecklist=['Find a quiet spot','Bring her favorite coffee','Write a handwritten note'];e.completedCelebrationSteps=['Find a quiet spot'];e.connectionJournal=['September 24 — A long walk and a good conversation.'];e.lastConnectionDate=new Date(now-7*86400000).toISOString();e.giftIdeas=['Personalized necklace','Spa day','Weekend getaway'].map(title=>({uuid:uid(),title,isPurchased:false,createdAt:now.toISOString()}));e.giftHistory=[{uuid:uid(),year:2025,item:'Handmade photo album'}];return state;}
  const api={GROUPS,OFFSETS,DEFAULTS,uid,today,resolved,next,days,turning,age,month,shortDate,fullDate,countdown,name,first,initials,zodiac,message,sorted,person,empty,read,validDate,validate,backup,mergeBackup,toggleGift,due,section,demo};
  if(typeof module!=='undefined')module.exports=api;else root.Birthday=api;
})(globalThis);

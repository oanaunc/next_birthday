'use strict';
const B=Birthday, native=globalThis.Android;
let state, storageError=null;
try {state=B.read(native?native.read():localStorage.getItem('nextbirthday'));}catch(e){storageError=e.message;state=B.empty();}
let billing={isPro:native?native.isPro():false,plans:[],loading:!!native,busy:false};
let route={screen:'today'},historyStack=[],filter='All',sort='Next Birthday',search='',giftFilter='To consider',onboardingPage=0;
let editDraft=null,contactCandidates=[],selectedContacts=new Set(),contactsLoading=false,contactsDenied=false;
let calendarAnchor=new Date(),calendarMode='Month',selectedDay=null,modal=null;
const app=document.getElementById('app'),colors=['#245c49','#7fb8f0','#e7b89e','#ebcda5','#5ac8e8','#9fe0d0'],colorNames=['Forest','Sky','Clay','Sand','Lagoon','Mint'];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const attr=(action,id='')=>`data-action="${esc(action)}" data-id="${esc(id)}"`;
const button=(text,action,cls='text-button',id='',disabled=false)=>`<button type="button" class="${cls}" ${attr(action,id)}${text.replace(/<[^>]+>/g,'').trim()===''?` aria-label="${esc({'add':'Add person','person-menu':'Person actions','gift-delete':'Delete gift idea','calendar-prev':'Previous month','calendar-next':'Next month'}[action]||action)}"`:''}${disabled?' disabled':''}>${text}</button>`;
const arrow=()=>icon('chevron.right',14);
const person=()=>state.people.find(p=>p.uuid===route.id);
const pro=()=>billing.isPro;
const field=(label,control,iconName='')=>`<div class="form-row">${iconName?icon(iconName,20):''}<label>${label}</label>${control}</div>`;
const input=(name,value,placeholder='',type='text',extra='')=>`<input type="${type}" name="${name}" aria-label="${esc(placeholder||name)}" value="${esc(value)}" placeholder="${esc(placeholder)}" ${extra}>`;
const textarea=(name,value,placeholder='',rows=3)=>`<textarea name="${name}" rows="${rows}" aria-label="${esc(placeholder||name)}" placeholder="${esc(placeholder)}">${esc(value)}</textarea>`;
const toggle=(name,on,label)=>`<input type="checkbox" class="switch" name="${name}" aria-label="${esc(label)}" ${on?'checked':''}>`;
const section=(title,content,footer='')=>`<section class="form-section"><h3 class="form-label">${title}</h3><div class="form-body">${content}</div>${footer?`<p class="form-footer">${footer}</p>`:''}</section>`;
const title=(name,count)=>`<div class="section-title">${esc(name)}${count!=null?`<span class="badge">${count}</span>`:''}</div>`;
const navrow=(text,action,id='',ic='')=>button(`${ic?icon(ic,20):''}<span class="grow">${text}</span>${arrow()}`,action,'form-row accent',id);
const offsetLabel=n=>({0:'On the birthday',1:'1 day before',3:'3 days before',7:'1 week before',14:'2 weeks before',30:'1 month before'}[n]||`${n} days before`);
const offsetShort=n=>({0:'Day of',1:'1 day',3:'3 days',7:'1 week',14:'2 weeks',30:'1 month'}[n]||n+' days');
const timeLabel=()=>`${String(state.settings.notificationHour).padStart(2,'0')}:${String(state.settings.notificationMinute).padStart(2,'0')}`;
const reminderSummary=days=>days.length?[...days].sort((a,b)=>b-a).map(offsetShort).join(' · '):'None';
function avatar(p,big=false){let photo=typeof p.photoData==='string'&&/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(p.photoData)?p.photoData:null;return `<span class="avatar${big?' big':''}">${photo?`<img src="${photo}" alt="${esc(B.name(p))}">`:esc(B.initials(p))}</span>`;}
function persist(nextState){
  if(storageError){showMessage(storageError);return false;}
  try{const candidate=structuredClone(nextState);candidate.revision=state.revision+1;const raw=JSON.stringify(candidate);if(native){if(!native.save(raw,state.revision))throw Error('Could not save your changes. Your saved data has been kept. Please try again.');}else localStorage.setItem('nextbirthday',raw);state=candidate;return true;}
  catch(e){showMessage(e.message);return false;}
}
function change(fn,rerender=true){const draft=structuredClone(state);fn(draft);if(persist(draft)&&rerender)render(true);}
function updatePerson(id,fn,rerender=true){change(s=>{const p=s.people.find(p=>p.uuid===id);if(p)fn(p);},rerender);}
function showMessage(message){const t=document.getElementById('toast');t.textContent=message;t.classList.add('visible');clearTimeout(showMessage.timer);showMessage.timer=setTimeout(()=>t.classList.remove('visible'),6000);}
window.showMessage=showMessage;
function navigate(screen,id=null){historyStack.push({...route,scroll:scrollY});route={screen,id};modal=null;render();window.scrollTo(0,0);}
function switchTab(screen){route={screen};historyStack=[];modal=null;render();window.scrollTo(0,0);}
function goBack(){if(modal){modal=null;render(true);return;}if(editDraft&&route.screen==='edit')editDraft=null;if(historyStack.length){const previous=historyStack.pop();route=previous;render();window.scrollTo(0,previous.scroll||0);}else if(!state.settings.hasCompletedOnboarding&&onboardingPage){onboardingPage=0;render();}else if(route.screen!=='today')switchTab('today');else native?.quit();}
window.goBack=goBack;
function shell(content,name,{large=false,add=false,back=false,right='',pageClass='page'}={}){
  let top=`<header class="top"><div>${back?button(icon('chevron.left',21)+'Back','back','back'):''}</div><div class="title">${large?'':esc(name)}</div><div class="row">${right}${add?button(icon('plus',24),'add','circle',''):''}</div></header>`;
  const mainTabs=['today','birthdays','people','settings'];
  return `<div class="screen ${state.settings.showBackgroundArt?'wash':''}">${top}<main class="${pageClass}">${large?`<h1 class="large-title">${name}</h1>`:''}${content}</main>${mainTabs.includes(route.screen)?tabs():''}${modal?modalView():''}</div>`;
}
function tabs(){return `<nav class="tabs" aria-label="Main navigation">${[['today','Today','leaf'],['birthdays','Birthdays','gift'],['people','People','person.2'],['settings','Settings','gearshape']].map(([r,label,ic])=>`<button class="tab ${route.screen===r?'selected':''}" ${attr('tab',r)} aria-label="${label}" aria-current="${route.screen===r?'page':'false'}">${icon(ic,24)}<span>${label}</span></button>`).join('')}</nav>`;}
function render(keepScroll=false){
  const y=scrollY;
  document.documentElement.style.setProperty('--accent',colors[state.settings.accentIndex]||colors[0]);
  if(storageError){app.innerHTML=`<main class="page error"><h2>Your saved data needs attention</h2><p>${esc(storageError)}</p><p>The original database has been kept. Close and reopen the app to try again.</p></main>`;return;}
  if(!state.settings.hasCompletedOnboarding&&!['edit','contacts'].includes(route.screen)){app.innerHTML=onboarding();return;}
  const screens={today:todayScreen,birthdays:birthdaysScreen,people:peopleScreen,settings:settingsScreen,plan:planScreen,detail:detailScreen,gifts:giftsScreen,edit:editScreen,calendar:calendarScreen,pro:proScreen,privacy:privacyScreen,widgets:widgetScreen,reminders:remindersScreen,contacts:contactsScreen,quick:quickScreen};
  app.innerHTML=(screens[route.screen]||todayScreen)();
  if(keepScroll)window.scrollTo(0,y);
}
function onboarding(){
  if(onboardingPage===0)return `<main class="onboarding"><img class="welcome-art" src="CareGestures.png" alt="Small thoughtful gestures"><div><h1 class="serif">Next Birthday</h1><p class="tagline">Make people feel remembered.</p></div><div class="features">${feature('bell','From date to thoughtful plan','Plan a gesture, set a budget, make it happen.')}${feature('heart','A journal of showing up','Remember time together, not just birthdays.')}${feature('lock','Private by design','Your personal notes stay on your phone.')}</div><div class="stack">${button('Continue','continue','primary')}<div class="dots"><b>●</b>●</div></div></main>`;
  return `<main class="onboarding"><div class="spacer"></div><div class="center accent">${icon('gift',72)}</div><h2 class="center accent">How do you want to start?</h2><div class="stack">${button(icon('person',20)+'Import from Contacts','contacts','primary')}${button(icon('plus',20)+'Add a Birthday','add','secondary')}${button("I'll do this later",'finish','text-button center')}<p class="muted center"><small>Your data stays on your phone.</small></p></div><div class="spacer"></div><div class="dots">●<b>●</b></div></main>`;
}
function feature(ic,name,desc){return `<div class="feature"><span class="bubble">${icon(ic,18)}</span><div class="grow"><h3>${name}</h3><p>${desc}</p></div></div>`;}
function todayScreen(){
  const upcoming=B.sorted(state.people),next=upcoming[0];
  let content=`<p class="eyebrow">${esc(new Date().toLocaleDateString(undefined,{weekday:'long',month:'long',day:'numeric'}))}</p><h1 class="serif">Small gestures.<br>Lasting connections.</h1><p class="muted">Your space to remember, plan and show up.</p>`;
  if(next)content+=button(`<span class="eyebrow">${icon('sun',18)}THE NEXT OCCASION</span><h2>${esc(B.first(next))}</h2><span class="date">${esc(B.shortDate(next))} · ${B.countdown(B.days(next))}</span><hr><span class="intention">${esc(next.celebrationIntent||'What would make them feel seen?')}</span><span class="row cta">${icon('arrow.up.right',20)}Make a thoughtful plan</span>`,'plan','occasion',next.uuid);
  else content+=`<div class="empty">${icon('person',48)}<h2>Start with someone you love</h2><p>Add their birthday, then plan something personal.</p>${button('Add your first person','add','primary')}</div>`;
  const due=pro()?B.due(state.people):[];
  if(due.length)content+=`<section class="stack">${title('Time to reconnect',due.length)}${due.map(p=>button(`${avatar(p)}<div class="grow"><h3>${esc(B.name(p))}</h3><small>A little time together is due</small></div>${icon('arrow.up.right',18)}`,'plan','person-row',p.uuid)).join('')}</section>`;
  if(upcoming.length)content+=`<section class="stack">${title('On your horizon',Math.min(5,upcoming.length))}${upcoming.slice(0,5).map(p=>button(`<span class="date">${esc(B.shortDate(p))}</span><div class="grow"><div class="name">${esc(B.name(p))}</div><p>${esc(p.celebrationIntent||'An open invitation to be thoughtful')}</p></div>${arrow()}`,'plan','horizon',p.uuid)).join('')}</section>`;
  content+=`<article class="card stack"><img src="CarePicnic.png" alt="A picnic, coffee and time together"><p class="eyebrow accent">TRY A SMALL GESTURE</p><p class="serif gesture">Ask about something they were looking forward to. Remembering the little things can mean more than buying something.</p><small>No streaks. No scores. Just people.</small></article>${button(icon('leaf',18)+'Build your connection rhythm with Pro','pro')}`;
  return shell(content,'Today',{add:true});
}
function personRow(p,action='detail'){
  return button(`${avatar(p)}<div class="grow"><div class="name">${esc(B.name(p))}${p.isFavorite?' <span style="color:#d9ab35;font-size:11px">★</span>':''}${p.acknowledgedYear===B.next(p).getFullYear()?'<span style="color:var(--mint)"> ✓</span>':''}</div><div class="info">${esc(B.shortDate(p))}${state.settings.showAge&&B.turning(p)!=null?' · Turns '+B.turning(p):''}${state.settings.showZodiac?' · '+B.zodiac(p):''} ${p.relationshipRaw?`<span class="tag">${esc(p.relationshipRaw)}</span>`:''}</div></div>${state.settings.showDaysRemaining?`<span class="count">${B.countdown(B.days(p))}</span>`:''}<span class="accent">${icon(B.days(p)===0?'party.popper':'gift',16)}</span><span class="chevron">${arrow()}</span>` ,action,'person-row',p.uuid);
}
function countdownStrip(p){return `<div class="countdown" data-target="${B.next(p).toISOString()}">${countdownParts(p)}</div>`;}
function countdownParts(p){let seconds=Math.max(0,Math.floor((B.next(p)-new Date())/1000));const parts=[Math.floor(seconds/86400),Math.floor(seconds%86400/3600),Math.floor(seconds%3600/60),seconds%60];return parts.map((n,i)=>`<div><b>${String(n).padStart(2,'0')}</b><small>${['days','hrs','min','sec'][i]}</small></div>`).join('');}
function birthdaysScreen(){
  const sorted=B.sorted(state.people),next=sorted[0];
  if(!next)return shell(`<div class="empty"><img src="AppLogo.png" alt="Next Birthday" width="130" height="130"><h2>No birthdays yet</h2><p>Add someone, or bring in the birthdays already saved in your Contacts.</p>${button('Import from Contacts','contacts','primary')}${button('Add a Birthday','add','secondary')}</div>`,'Birthdays',{large:true,add:true,pageClass:'page tight'});
  const stats=[state.people.filter(p=>B.days(p)<=7).length,state.people.filter(p=>p.birthMonth===new Date().getMonth()+1).length,state.people.length];
  let content=`<article class="birthday-hero stack"><div class="row between"><span class="eyebrow accent row">${icon('sparkles',14)}NEXT CELEBRATION</span><small>${esc(B.shortDate(next))}</small></div><div class="row">${avatar(next).replace('class="avatar"','class="avatar hero-avatar"')}<div class="grow">${button(`<h3>${esc(B.first(next))}${next.isFavorite?' <span style="color:var(--rose)">♥</span>':''}</h3>`,'detail','text-button',next.uuid)}${button(`<h1 class="serif accent">${B.countdown(B.days(next))}</h1>`,'detail','text-button',next.uuid)}<p class="muted" style="font-size:15px">${B.turning(next)!=null&&state.settings.showAge?'Turning '+B.turning(next):esc(B.fullDate(next))}</p></div>${button(icon(B.days(next)===0?'party.popper':'message',20),'quick','hero-action',next.uuid)}</div>${countdownStrip(next)}</article><div class="stats">${stats.map((n,i)=>`<div><strong>${n}</strong> ${['this week','this month','people'][i]}</div>`).join('')}</div>`;
  let previous='';for(const p of sorted.slice(1)){const group=B.section(p);if(group!==previous){content+=title(group,sorted.slice(1).filter(x=>B.section(x)===group).length);previous=group;}content+=personRow(p);}
  content+=button(icon('calendar',18)+'Birthday calendar','calendar');
  return shell(content,'Birthdays',{large:true,add:true,pageClass:'page tight'});
}
function peopleScreen(){
  if(!state.people.length)return shell(`<div class="empty">${icon('person.2',54)}<h2>No people yet</h2><p>Add a birthday to start building your list.</p>${button('Add a Birthday','add','primary')}</div>`,'People',{large:true,add:true});
  const used=[...new Set(state.people.map(p=>p.relationshipRaw).filter(Boolean))],groups=[...B.GROUPS.filter(g=>used.includes(g)),...used.filter(g=>!B.GROUPS.includes(g)).sort()];
  let list=state.people.filter(p=>[B.name(p),p.notes,p.relationshipRaw,B.month(p.birthMonth),B.month(p.birthMonth,true),B.zodiac(p)].filter(Boolean).some(v=>v.toLocaleLowerCase().includes(search.trim().toLocaleLowerCase()))).filter(p=>filter==='All'||(filter==='Favorites'?p.isFavorite:p.relationshipRaw===filter));
  list=sort==='Name'?list.sort((a,b)=>B.name(a).localeCompare(B.name(b))):sort==='Age'?list.sort((a,b)=>(B.age(b)??-1)-(B.age(a)??-1)):sort==='Date'?list.sort((a,b)=>a.birthMonth-b.birthMonth||a.birthDay-b.birthDay):B.sorted(list);
  let content=`<div class="search">${icon('search',19)}${input('search',search,'Search name, note, month…','search')}</div><div class="chips">${['All','Favorites',...groups].map(g=>button(esc(g),'filter','chip '+(filter===g?'active':''),g)).join('')}</div><div class="row between"><small>${list.length} ${list.length===1?'person':'people'}</small><select name="sort" aria-label="Sort by">${['Next Birthday','Name','Age','Date'].map(v=>`<option ${sort===v?'selected':''}>${v}</option>`).join('')}</select></div><div id="people-results" class="stack">`;
  let letter='';for(const p of list){if(sort==='Name'){const l=B.name(p).charAt(0).toUpperCase();if(l!==letter){content+=title(l);letter=l;}}content+=personRow(p);}
  if(!list.length)content+='<div class="empty"><h2>No Results</h2><p>Try a different name, group, month or note.</p></div>';
  content+='</div>';
  return shell(content,'People',{large:true,add:true,pageClass:'page tight'});
}
function planScreen(){
  const p=person();if(!p)return shell('<p>This person is no longer saved.</p>','A thoughtful plan',{back:true});
  let content=section('',`<img class="form-hero" src="CareJournal.png" alt="A journal of time together"><div class="form-row stack" style="align-items:flex-start"><h1 class="serif">${esc(B.first(p))}</h1><p class="muted">${esc(B.shortDate(p))} · ${B.countdown(B.days(p))}</p></div>${navrow('Birthday details &amp; gift ideas','detail',p.uuid)}`);
  content+=section('The intention',`<div class="form-row">${textarea('celebrationIntent',p.celebrationIntent,'A picnic at their favorite spot…',3)}</div>${field('Budget ('+currency()+')',input('celebrationBudget',p.celebrationBudget,'0','number','min="0" step="0.01"'))}`,'Start with who they are. A thoughtful gesture can cost nothing.');
  let checklist=p.celebrationChecklist.map((step,i)=>button(icon(p.completedCelebrationSteps.includes(step)?'checkmark.circle':'circle',20)+esc(step),'step','form-row accent',String(i),!pro())).join('');
  if(pro())checklist+=`<form id="add-step" class="form-row inline-add">${input('step','','One concrete next step','text','required maxlength="500"')}<button type="submit" class="accent">Add</button></form>${p.celebrationChecklist.length?button('Start a fresh checklist','clear-steps','form-row danger'):''}`;
  else checklist+=navrow('Unlock personal checklists with Pro','pro','','leaf');
  content+=section('Make it happen',checklist);
  let connection=pro()?field('Catch-up cadence',`<select name="connectionCadence" aria-label="Catch-up cadence">${[[0,'No cadence'],[7,'Every week'],[14,'Every two weeks'],[30,'Every month'],[90,'Every three months']].map(([v,l])=>`<option value="${v}" ${p.connectionCadence===v?'selected':''}>${l}</option>`).join('')}</select>`):navrow('Set a connection rhythm with Pro','pro');
  if(p.lastConnectionDate)connection+=field('Last time together',`<span class="value">${esc(new Date(p.lastConnectionDate).toLocaleDateString(undefined,{dateStyle:'medium'}))}</span>`);
  connection+=`<form id="add-moment">${field('When',input('connectionDate',localDate(new Date()),'When','date',`max="${localDate(new Date())}" required`))}<div class="form-row">${textarea('journal','','What do you want to remember?',2)}</div><button type="submit" class="form-row accent">Save a moment together</button></form>`;
  content+=section('Beyond the birthday',connection,'Pro cadence appears on Today when a catch-up is due. Birthday notifications are managed separately in Settings.');
  if(p.connectionJournal.length)content+=`<div id="journal">${section('Moments to keep',p.connectionJournal.map(e=>`<p class="journal-entry">${esc(e)}</p>`).join(''))}</div>`;
  return shell(content,'A thoughtful plan',{back:true,pageClass:'page form'});
}
function currency(){try{return new Intl.NumberFormat(undefined,{style:'currency',currency:'RON'}).resolvedOptions().currency;}catch{return 'local currency';}}
function localDate(d){return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');}
function detailScreen(){
  const p=person();if(!p)return shell('<p>This person is no longer saved.</p>','Birthday',{back:true});
  let content=`<section class="detail-header">${avatar(p,true)}<h2>${esc(B.name(p))}${p.isFavorite?' <span style="color:var(--rose)">♥</span>':''}</h2><p class="muted">${esc(B.fullDate(p))}</p>${p.relationshipRaw?`<span class="tag">${esc(p.relationshipRaw)}</span>`:''}<div class="actions">${p.phone?actionIcon('message','Message','message',p.uuid):''}${p.phone?actionIcon('phone','Call','call',p.uuid):''}${actionIcon('bolt','Quick','quick',p.uuid)}</div></section>${button(icon('leaf',18)+'Plan something meaningful','plan','primary',p.uuid)}<section class="card stack"><div class="row between"><h2 class="accent">${B.countdown(B.days(p))}</h2>${state.settings.showAge&&B.turning(p)!=null?`<small>Turns ${B.turning(p)}</small>`:''}</div>${countdownStrip(p)}</section>`;
  content+=`<section class="card">${fact('Date',B.fullDate(p))}${state.settings.showAge?fact('Age',B.age(p)==null?'Year not set':B.age(p)+' years old'):''}${state.settings.showZodiac?fact('Zodiac',B.zodiac(p)):''}${fact('Next birthday',B.next(p).toLocaleDateString(undefined,{dateStyle:'medium'}))}</section>`;
  const reminders=p.usesCustomReminders?p.customReminderDays:state.settings.defaultReminderDays;
  content+=`<section class="card stack"><h3 class="row">${icon('bell',18)}Reminders ${p.usesCustomReminders?'<span class="badge">Custom</span>':''}</h3>${reminders.length?[...reminders].sort((a,b)=>b-a).map(d=>`<div class="row">${icon('checkmark.circle',14)}<small class="grow">${offsetLabel(d)}</small><small>${timeLabel()}</small></div>`).join(''):'<small>No reminders set.</small>'}${button(p.usesCustomReminders?'Change reminders':'Set custom reminders','edit','text-button',p.uuid)}</section><section class="card stack"><h3 class="row">${icon('note',18)}Notes</h3>${textarea('notes',p.notes,'Favourite flowers, shirt size, things they mentioned wanting…',3)}</section>`;
  content+=`<section class="card stack"><div class="row between"><h3 class="row">${icon('gift',18)}Gift Ideas</h3>${button('All','gifts','text-button',p.uuid)}</div>${p.giftIdeas.length?giftRows(p,[...p.giftIdeas].sort((a,b)=>a.isPurchased-b.isPurchased).slice(0,4)):'<small>Nothing yet. Jot down ideas whenever they come up.</small>'}${giftForm()}</section>`;
  if(p.giftHistory.length)content+=`<section class="card stack"><h3>Gift History</h3>${historyRows(p)}</section>`;
  if(p.phone||p.email)content+=`<section class="card stack"><h3>Contact</h3>${p.phone?button(icon('phone',16)+esc(p.phone),'call','text-button',p.uuid):''}${p.email?button(icon('envelope',16)+esc(p.email),'email','text-button',p.uuid):''}</section>`;
  content+=button(icon('trash',16)+'Delete Person','delete','danger',p.uuid);
  return shell(content,'',{back:true,right:button(icon('ellipsis.circle',23),'person-menu','icon-button',p.uuid),pageClass:'page tight'});
}
function fact(label,value){return `<div class="fact"><span>${label}</span><span>${esc(value)}</span></div>`;}
function actionIcon(ic,label,action,id){return button(`<span>${icon(ic,20)}</span>${label}`,action,'action',id);}
function giftForm(){return `<form id="add-gift" class="inline-add">${input('gift','','Add an idea','text','required maxlength="500"')}<button type="submit" class="icon-button" aria-label="Add gift idea">${icon('plus.circle',22)}</button></form>`;}
function giftRows(p,ideas,remove=false){return ideas.map(g=>`<div class="row"><button class="check-row ${g.isPurchased?'checked':''} grow" ${attr('gift-toggle',g.uuid)} aria-label="${g.isPurchased?'Undo gifted':'Mark gifted'}: ${esc(g.title)}">${icon(g.isPurchased?'checkmark.circle':'circle',20)}${esc(g.title)}</button>${remove?button(icon('trash',16),'gift-delete','icon-button',g.uuid):''}</div>`).join('');}
function historyRows(p){return [...p.giftHistory].sort((a,b)=>b.year-a.year).map(g=>`<div class="history-row"><b>${g.year}</b><span>${esc(g.item)}</span></div>`).join('');}
function giftsScreen(){const p=person();if(!p)return shell('<p>Person not found.</p>','Gift Ideas',{back:true});const ideas=[...p.giftIdeas].sort((a,b)=>a.isPurchased-b.isPurchased).filter(g=>giftFilter==='All'||(giftFilter==='Gifted'?g.isPurchased:!g.isPurchased));return shell(`${section('',`<div class="form-row">${giftForm()}</div>`,'Tip: note what they mention wanting during the year — that’s what makes this list useful.')}<div class="segmented">${['To consider','Gifted','All'].map(f=>button(f,'gift-filter',giftFilter===f?'active':'',f)).join('')}</div>${section('Ideas',`<div style="padding:0 16px">${ideas.length?giftRows(p,ideas,true):'<p class="muted" style="padding:16px 0">Nothing here yet.</p>'}</div>`)}${p.giftHistory.length?section('Gift History',`<div style="padding:0 16px">${historyRows(p)}</div>`):''}`,'Gift Ideas',{back:true,pageClass:'page form'});}
function openEditor(id){editDraft=structuredClone(state.people.find(p=>p.uuid===id)||B.person({birthMonth:new Date().getMonth()+1,birthDay:new Date().getDate(),birthYear:1995,customReminderDays:[...state.settings.defaultReminderDays]}));navigate('edit',id);}
function editScreen(){
  if(!editDraft)editDraft=B.person();const p=editDraft;
  const group=p.relationshipRaw||'',custom=group&&!B.GROUPS.includes(group),year=p.birthYear??1995;
  const months=Array.from({length:12},(_,i)=>`<option value="${i+1}" ${p.birthMonth===i+1?'selected':''}>${B.month(i+1)}</option>`).join('');
  let content=`<form id="save-person" class="stack gap24"><div class="photo-picker">${avatar(p,true)}${button('Choose photo','photo','text-button')}${p.photoData?button('Remove photo','remove-photo','text-button'):''}</div>${section('Name',`<div class="form-row">${input('firstName',p.firstName,'First name','text','maxlength="200" autocomplete="given-name"')}</div><div class="form-row">${input('lastName',p.lastName,'Last name','text','maxlength="200" autocomplete="family-name"')}</div>${field('Favorite',toggle('isFavorite',p.isFavorite,'Favorite'))}`)}`;
  content+=section('Birthday',`${field('Month',`<select name="birthMonth" aria-label="Month">${months}</select>`)}${field('Day',`<select name="birthDay" aria-label="Day">${Array.from({length:new Date(p.birthYear||2000,p.birthMonth,0).getDate()},(_,i)=>`<option value="${i+1}" ${p.birthDay===i+1?'selected':''}>${i+1}</option>`).join('')}</select>`)}${field('Include year',toggle('includeYear',p.birthYear!=null,'Include year'))}${p.birthYear!=null?field('Year',input('birthYear',year,'Year','number',`min="1900" max="${new Date().getFullYear()}"`)):''}`,p.birthYear!=null?'Shown as '+esc(B.fullDate(p))+'.':"Leave the year off if you don’t know it — the age simply won’t be shown.");
  content+=section('Relationship',`${field('Relationship',`<select name="relationshipRaw" aria-label="Relationship"><option value="">None</option>${B.GROUPS.map(g=>`<option ${group===g?'selected':''}>${g}</option>`).join('')}<option value="__custom__" ${custom?'selected':''}>Custom…</option></select>`)}${custom?`<div class="form-row">${input('customRelationship',group,'Group name','text','maxlength="100"')}</div>`:''}`);
  content+=section('Reminders',`${field('Use custom reminders',toggle('usesCustomReminders',p.usesCustomReminders,'Use custom reminders'))}${p.usesCustomReminders?B.OFFSETS.map(d=>field(offsetLabel(d),`<input type="checkbox" name="customReminder-${d}" aria-label="${offsetLabel(d)}" ${p.customReminderDays.includes(d)?'checked':''}>`)).join(''):''}`,p.usesCustomReminders?'These override the app defaults for this person.':'Using the app default: '+reminderSummary(state.settings.defaultReminderDays)+' at '+timeLabel()+'.');
  content+=section('Notes',`<div class="form-row">${textarea('notes',p.notes,'Loves ceramics and gardening…',3)}</div>`);
  content+=`<button type="submit" class="primary">Save</button></form>`;
  return shell(content,route.id?'Edit Birthday':'Add Birthday',{back:true,pageClass:'page form'});
}
function settingsScreen(){
  const s=state.settings;
  const content=section('A little more room to care',navrow('Next Birthday Pro','pro','','leaf')+navrow('Birthday calendar','calendar','','calendar'))+
    section('Reminders',navrow(`Default reminders <small class="value">${reminderSummary(s.defaultReminderDays)}</small>`,'reminders','','bell')+field('Notification time',input('notificationTime',timeLabel(),'Notification time','time'),'clock')+field('Smart wording',toggle('smartRemindersEnabled',s.smartRemindersEnabled,'Smart wording'),'sparkles')+button(native?.notificationsAllowed()?'Notifications are enabled':'Enable notifications','notifications','form-row accent'),"Smart wording changes early reminders into gift nudges and same-day ones into message nudges.")+
    section('Appearance',field('Accent colour',`<div class="swatches">${colors.map((c,i)=>button(`<span class="hidden">${colorNames[i]}</span>`,'accent','swatch '+(s.accentIndex===i?'active':''),String(i)).replace('<button ',`<button style="background:${c}" aria-label="${colorNames[i]}" `)).join('')}</div>`,'paintpalette')+field('Warm background wash',toggle('showBackgroundArt',s.showBackgroundArt,'Warm background wash'),'photo'))+
    section('Birthday display',field('Show age',toggle('showAge',s.showAge,'Show age'),'number')+field('Show zodiac signs',toggle('showZodiac',s.showZodiac,'Show zodiac signs'),'sparkles')+field('Show days remaining',toggle('showDaysRemaining',s.showDaysRemaining,'Show days remaining'),'clock'))+
    section('Contacts',navrow('Import from Contacts','contacts','','person')+(s.lastContactsCheck?field('Last import',`<small class="value">${esc(new Date(s.lastContactsCheck).toLocaleString())}</small>`):''))+
    section('Data',navrow('Export birthdays (JSON)','export','','export')+navrow('Import backup','import','','download'),`${state.people.length} ${state.people.length===1?'person':'people'} stored on this phone.`)+
    section('',navrow('Privacy &amp; Data','privacy','','lock')+navrow('Widgets','widgets','','square.grid.2x2')+field('Version','<small class="value">2.0 (1)</small>'));
  return shell(content,'Settings',{large:true,pageClass:'page form'});
}
function remindersScreen(){return shell(section('Pick as many as you like',B.OFFSETS.map(d=>button(`<span class="grow">${offsetLabel(d)}</span>${state.settings.defaultReminderDays.includes(d)?icon('checkmark',20):''}`,'default-reminder','form-row',String(d))).join(''),"These apply to everyone who doesn’t have custom reminders set on their own page.")+section('Suggested by group',B.GROUPS.map((g,i)=>field(g,`<small class="value">${reminderSummary([[14,3,0],[7,1,0],[14,3,0],[1,0],[3,0],[1,0]][i])}</small>`)).join('')),'Default reminders',{back:true,pageClass:'page form'});}
function calendarScreen(){
  const m=calendarAnchor.getMonth()+1,y=calendarAnchor.getFullYear();
  let content=`<div class="segmented">${['Month','Year'].map(v=>button(v,'calendar-mode',calendarMode===v?'active':'',v)).join('')}</div>`;
  if(calendarMode==='Year')content+=`<div class="year-grid">${Array.from({length:12},(_,i)=>button(`<small>${esc(B.month(i+1,true).toUpperCase())}</small><b>${state.people.filter(p=>p.birthMonth===i+1).length}</b><i></i>`,'calendar-month','month-cell',String(i+1))).join('')}</div>`;
  else{
    // Match the device locale's first weekday; fall back to Monday for Bucharest.
    let firstWeekday=1;try{firstWeekday=new Intl.Locale(navigator.language).getWeekInfo().firstDay%7;}catch{if(/^en-US/.test(navigator.language))firstWeekday=0;}
    const first=new Date(y,m-1,1),leading=(first.getDay()-firstWeekday+7)%7,count=new Date(y,m,0).getDate();
    content+=`<section class="card stack"><div class="row between">${button(icon('chevron.left',20),'calendar-prev','icon-button')}<h3>${B.month(m)} ${y}</h3>${button(icon('chevron.right',20),'calendar-next','icon-button')}</div><div class="calendar">${Array.from({length:7},(_,i)=>`<span class="weekday">${new Date(2024,0,7+(i+firstWeekday)%7).toLocaleDateString(undefined,{weekday:'narrow'})}</span>`).join('')}${'<span></span>'.repeat(leading)}${Array.from({length:count},(_,i)=>{const d=i+1,people=state.people.filter(p=>p.birthMonth===m&&Math.min(p.birthDay,count)===d),today=localDate(new Date(y,m-1,d))===localDate(new Date());return button(`${d}${people.length?'<span class="dot"></span>':'<span style="height:4px"></span>'}`,'calendar-day','day '+(today?'today ':'')+(selectedDay===d?'selected':''),String(d),!people.length&&!today);}).join('')}</div></section>`;
    if(selectedDay!=null){const list=state.people.filter(p=>p.birthMonth===m&&Math.min(p.birthDay,count)===selectedDay);if(list.length)content+=`<section class="card stack"><h3>${B.month(m)} ${selectedDay}</h3>${list.map(p=>personRow(p)).join('')}</section>`;}
    const list=state.people.filter(p=>p.birthMonth===m).sort((a,b)=>a.birthDay-b.birthDay);
    content+=title(B.month(m)+' Birthdays',list.length)+(list.length?list.map(p=>personRow(p)).join(''):'<div class="card"><small>No birthdays this month.</small></div>');
  }
  return shell(content,'Calendar',{back:true,large:true,pageClass:'page tight'});
}
function proScreen(){
  let content=`<img class="pro-art" src="CareRhythm.png" alt="A rhythm of thoughtful connection"><h1 class="serif">More intention.<br>All year long.</h1><p class="eyebrow accent">NEXT BIRTHDAY PRO</p><p class="muted">A private planning companion for the people you care about.</p>${feature('checklist','Personal celebration checklists','Build and track the steps behind every gesture.')}${feature('arrow.triangle.2.circlepath','Your connection rhythm','Choose a cadence and see who is due a catch-up on Today.')}<p class="pro-note">Free includes unlimited birthdays, reminders, gift ideas, celebration intentions, budgets, connection journaling and backups. Your saved plans remain readable if Pro ends.</p>`;
  if(pro())content+=`<p class="accent row">${icon('checkmark.circle',22)}Pro is active</p>${button('Manage subscription','manage','secondary')}`;
  else if(billing.plans.length)content+=billing.plans.map(p=>button(`<div><strong>${esc(p.title)}</strong><br><small>Billed ${p.id.endsWith('yearly')?'yearly':'monthly'} · auto-renews</small></div><strong>${esc(p.price)}</strong>`,'buy','subscription',p.id,billing.busy)).join('');
  else content+=`<p class="pro-note">${billing.loading?'Loading plans from Google Play…':'Plans are currently unavailable. You can continue using all free features.'}</p>${button('Reload plans','reload-plans','secondary','',billing.loading)}`;
  content+=`${button('Restore purchases','restore','text-button','',billing.busy)}<p class="pro-note">Payment is charged to your Google Play account. Subscriptions automatically renew unless cancelled before the current period ends. Manage or cancel in Google Play subscription settings.</p><div class="row between">${button('Privacy','open-privacy','text-button')}${button('Terms of Use','open-terms','text-button')}</div>${button('Reviewer access','review','text-button')}`;
  return shell(content,'Pro',{back:true});
}
function privacyScreen(){return shell(`<h2 class="accent">Your birthdays stay on your phone.</h2><div class="stack muted"><p>Next Birthday has no account, no login and no server. Everything you add — names, dates, photos, notes, gift ideas, celebration plans and journal entries — is stored in the app’s own database on this device.</p><p>Optional Pro subscriptions connect to Google Play to load plans, process purchases and verify access. Your personal planning data is not sent with purchases. Google handles billing.</p><p>Contacts access is optional and read-only. When you import, the app reads the names and birthdays you select and copies them locally. It never uploads them, and it never writes back to your Contacts.</p><p>Notifications are scheduled locally by Android. Nothing about them leaves the phone.</p><p>Widgets read a small copy of your upcoming birthdays from the app’s database on this device.</p><p>Automatic cloud backups are disabled. Deleting the app deletes all of it. Use Export in Settings first if you want to keep a copy.</p></div><p class="accent row">${icon('checkmark.circle',20)}No account · No tracking · No analytics</p>${button('Privacy policy','open-privacy')}`,'Privacy & Data',{back:true});}
function widgetScreen(){return shell(`<h2 class="accent">Add a widget</h2><p>1. Touch and hold an empty area of your Home Screen.</p><p>2. Tap Widgets.</p><p>3. Search for Next Birthday and pick a size.</p><hr><h3>Available widgets</h3><p>• Up Next — resizable small, medium and large lists of who’s coming up.</p><p>• Countdown — one person, big number of days. Choose a person when adding or reconfiguring the widget.</p><p>• Compact — a small birthday and countdown pair. Available on the Lock Screen where your Android device supports widgets.</p><small>Widgets refresh a few times a day and whenever you change something in the app. Android may delay notifications and widget updates while the device is conserving battery.</small>`,'Widgets',{back:true});}
function quickScreen(){const p=person();if(!p)return shell('<p>Person not found.</p>','Quick Actions',{back:true});return shell(`<div class="detail-header">${avatar(p,true)}<h3>${esc(B.name(p))}</h3><p class="accent">${B.countdown(B.days(p))}</p></div>${p.phone?`<div class="actions">${actionIcon('message','Message','message',p.uuid)}${actionIcon('phone','Call','call',p.uuid)}${actionIcon('message','WhatsApp','whatsapp',p.uuid)}</div>`:p.email?`<div class="actions">${actionIcon('envelope','Email','email',p.uuid)}</div>`:'<p class="muted center">Link this person to a contact to message or call them from here.</p>'}<section class="card stack"><small>Suggested message</small><p>${esc(B.message(p))}</p>${button(icon('copy',18)+'Copy Message','copy','secondary',p.uuid)}</section>${button(icon('export',18)+'Share Birthday','share','text-button',p.uuid)}${button('Mark birthday '+(p.acknowledgedYear===B.next(p).getFullYear()?'not done':'done'),'acknowledge','secondary',p.uuid)}`,'Quick Actions',{back:true});}
function contactsScreen(){
  let content='<p class="muted">Only contacts with a saved birthday appear here. Nothing is imported until you choose Import.</p>';
  if(contactsLoading)content+='<div class="empty"><p>Loading birthdays from Contacts…</p></div>';
  else if(contactsDenied)content+=`<div class="empty">${icon('lock',44)}<h2>Contacts access is off</h2><p>Allow read-only Contacts access to choose birthdays to import, or add a birthday by hand.</p>${button('Try again','load-contacts','primary')}${button('Add a Birthday','add','secondary')}</div>`;
  else if(!contactCandidates.length)content+=`<div class="empty"><h2>No birthdays found</h2><p>Add birthdays to your device’s Contacts, then try again.</p>${button('Reload Contacts','load-contacts','secondary')}</div>`;
  else{
    content+=`<div class="row between">${button('Select all new','select-contacts')}${button('Clear selection','clear-contacts')}</div><div class="form-body">${contactCandidates.map((p,i)=>{const known=contactKnown(p);return `<label class="form-row"><span class="grow"><strong>${esc(B.name(p))}</strong><br><small>${B.shortDate(p)}${known?' · Already saved':''}</small></span><input type="checkbox" data-contact="${i}" aria-label="Import ${esc(B.name(p))}" ${known?'disabled':selectedContacts.has(i)?'checked':''}></label>`;}).join('')}</div>${button('Import '+selectedContacts.size+' birthdays','import-contacts','primary','',!selectedContacts.size)}`;
  }
  return shell(content,'Import from Contacts',{back:true});
}
function contactKnown(p){return state.people.some(x=>(p.contactIdentifier&&p.contactIdentifier===x.contactIdentifier)||(B.name(x).toLocaleLowerCase()===B.name(p).toLocaleLowerCase()&&p.birthMonth===x.birthMonth&&p.birthDay===x.birthDay));}
function loadContacts(){contactsLoading=true;contactsDenied=false;render(true);if(native)native.contacts();else{contactsLoading=false;contactsDenied=true;render(true);}}
function modalView(){
  const p=state.people.find(p=>p.uuid===modal.id);
  let content='';
  if(modal.type==='person'&&p)content=`<h2 class="mb">${esc(B.name(p))}</h2><div class="stack">${button('Edit','edit','secondary',p.uuid)}${button(p.isFavorite?'Remove Favorite':'Add to Favorites','favorite','secondary',p.uuid)}${button('Share Birthday','share','secondary',p.uuid)}${button('Delete Person','delete','danger',p.uuid)}</div>`;
  if(modal.type==='row'&&p)content=`<h2 class="mb">${esc(B.name(p))}</h2><div class="stack">${button('Edit','edit','secondary',p.uuid)}${button(p.isFavorite?'Remove Favorite':'Add to Favorites','favorite','secondary',p.uuid)}${route.screen==='birthdays'?button(p.acknowledgedYear===B.next(p).getFullYear()?'Undo Done':'Done','acknowledge','secondary',p.uuid)+button('Message','quick','secondary',p.uuid):button('Delete','delete','danger',p.uuid)}</div>`;
  if(modal.type==='delete'&&p)content=`<h2>Delete ${esc(B.name(p))}?</h2><p class="muted mt mb">This removes their birthday, notes, celebration plans, journal and gift ideas from this phone.</p><div class="stack">${button('Delete','confirm-delete','danger',p.uuid)}</div>`;
  if(modal.type==='clear-steps')content=`<h2>Start a fresh checklist?</h2><p class="muted mt mb">This clears the steps and their completion status.</p>${button('Clear checklist','confirm-clear-steps','danger')}`;
  if(modal.type==='review')content=`<h2>Reviewer access</h2><p class="muted mt mb">Enter the access code provided in Google Play’s review instructions.</p><form id="review-form" class="stack">${input('reviewCode','','Access code','password','required autocomplete="off"')}<button type="submit" class="primary">Continue</button></form>`;
  return `<div class="modal-backdrop"><section class="modal" role="dialog" aria-modal="true"><div class="stack">${content}${button('Cancel','close-modal','secondary')}</div></section></div>`;
}
function openURL(url){if(native)native.open(url);else window.open(url,'_blank','noopener');}
function finish(){change(s=>s.settings.hasCompletedOnboarding=true,false);route={screen:'today'};historyStack=[];render();}
let swipeStart=null,suppressClickUntil=0;
document.addEventListener('pointerdown',e=>{const row=e.target.closest('.person-row[data-id]');if(row&&['people','birthdays'].includes(route.screen))swipeStart={x:e.clientX,y:e.clientY,id:row.dataset.id};});
document.addEventListener('pointercancel',()=>swipeStart=null);
document.addEventListener('pointerup',e=>{if(!swipeStart)return;const s=swipeStart;swipeStart=null;const dx=e.clientX-s.x,dy=e.clientY-s.y;if(Math.abs(dx)<70||Math.abs(dy)>40)return;suppressClickUntil=Date.now()+350;if(dx>0){updatePerson(s.id,p=>p.isFavorite=!p.isFavorite);showMessage('Favorite updated');}else{modal={type:'row',id:s.id};render(true);}});
document.addEventListener('contextmenu',e=>{const row=e.target.closest('.person-row[data-id]');if(row){e.preventDefault();modal={type:'row',id:row.dataset.id};render(true);}});
document.addEventListener('click',e=>{
  if(Date.now()<suppressClickUntil){e.preventDefault();return;}
  const b=e.target.closest('[data-action]');if(!b||b.disabled)return;
  const a=b.dataset.action,id=b.dataset.id||'',p=state.people.find(p=>p.uuid===id)||person();
  if(b.closest('form')&&b.type!=='submit')e.preventDefault();
  switch(a){
    case 'tab':switchTab(id);break;
    case 'back':goBack();break;
    case 'continue':onboardingPage=1;render();break;
    case 'finish':finish();break;
    case 'add':openEditor(null);break;
    case 'edit':openEditor(id);break;
    case 'plan':case 'detail':case 'gifts':case 'quick':navigate(a,id);break;
    case 'pro':case 'calendar':case 'privacy':case 'widgets':case 'reminders':navigate(a);break;
    case 'filter':filter=id;render(true);break;
    case 'gift-filter':giftFilter=id;render(true);break;
    case 'calendar-mode':calendarMode=id;render(true);break;
    case 'calendar-month':calendarAnchor=new Date(calendarAnchor.getFullYear(),Number(id)-1,1);calendarMode='Month';selectedDay=null;render(true);break;
    case 'calendar-prev':case 'calendar-next':calendarAnchor=new Date(calendarAnchor.getFullYear(),calendarAnchor.getMonth()+(a==='calendar-prev'?-1:1),1);selectedDay=null;render(true);break;
    case 'calendar-day':selectedDay=selectedDay===Number(id)?null:Number(id);render(true);break;
    case 'step':if(!pro()){navigate('pro');break;}updatePerson(route.id,p=>{const step=p.celebrationChecklist[Number(id)];if(p.completedCelebrationSteps.includes(step))p.completedCelebrationSteps=p.completedCelebrationSteps.filter(x=>x!==step);else p.completedCelebrationSteps.push(step);});break;
    case 'clear-steps':modal={type:'clear-steps'};render(true);break;
    case 'confirm-clear-steps':if(pro())updatePerson(route.id,p=>{p.celebrationChecklist=[];p.completedCelebrationSteps=[];},false);modal=null;render(true);break;
    case 'gift-toggle':updatePerson(route.id,p=>B.toggleGift(p,id));break;
    case 'gift-delete':updatePerson(route.id,p=>p.giftIdeas=p.giftIdeas.filter(g=>g.uuid!==id));break;
    case 'person-menu':modal={type:'person',id};render(true);break;
    case 'close-modal':modal=null;render(true);break;
    case 'delete':modal={type:'delete',id:p.uuid};render(true);break;
    case 'confirm-delete':change(s=>s.people=s.people.filter(p=>p.uuid!==id),false);switchTab('people');break;
    case 'favorite':updatePerson(p.uuid,p=>p.isFavorite=!p.isFavorite,false);modal=null;render(true);break;
    case 'acknowledge':modal=null;updatePerson(p.uuid,p=>p.acknowledgedYear=p.acknowledgedYear===B.next(p).getFullYear()?null:B.next(p).getFullYear());break;
    case 'photo':if(native)native.photo();else showMessage('Photo picking is available in the Android app.');break;
    case 'remove-photo':editDraft.photoData=null;render(true);break;
    case 'default-reminder':change(s=>{const n=Number(id);s.settings.defaultReminderDays=s.settings.defaultReminderDays.includes(n)?s.settings.defaultReminderDays.filter(x=>x!==n):[...s.settings.defaultReminderDays,n].sort((a,b)=>b-a);});break;
    case 'accent':change(s=>s.settings.accentIndex=Number(id));break;
    case 'notifications':if(native){if(native.notificationsAllowed())native.notificationSettings();else native.requestNotifications();}else showMessage('Notifications are available in the Android app.');break;
    case 'contacts':navigate('contacts');loadContacts();break;
    case 'load-contacts':loadContacts();break;
    case 'select-contacts':selectedContacts=new Set(contactCandidates.map((p,i)=>contactKnown(p)?-1:i).filter(i=>i>=0));render(true);break;
    case 'clear-contacts':selectedContacts.clear();render(true);break;
    case 'import-contacts':{
      let added=0;change(s=>{for(const i of selectedContacts){const p=contactCandidates[i];if(!p||s.people.some(x=>(p.contactIdentifier&&p.contactIdentifier===x.contactIdentifier)||(B.name(x).toLowerCase()===B.name(p).toLowerCase()&&x.birthMonth===p.birthMonth&&x.birthDay===p.birthDay)))continue;s.people.push(B.person(p));added++;}s.settings.lastContactsCheck=new Date().toISOString();s.settings.hasCompletedOnboarding=true;},false);switchTab('people');showMessage(`Imported ${added} birthdays.`);break;
    }
    case 'export':{const json=JSON.stringify(B.backup(state),null,2);if(native)native.export(json);else{const url=URL.createObjectURL(new Blob([json],{type:'application/json'}));const link=document.createElement('a');link.href=url;link.download='NextBirthday-'+localDate(new Date())+'.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}break;}
    case 'import':if(native)native.importBackup();else showMessage('Import backups using the Android app.');break;
    case 'copy':if(native)native.copy(B.message(p));else navigator.clipboard?.writeText(B.message(p));showMessage('Copied');break;
    case 'share':if(native)native.shareText(`${B.name(p)}’s birthday — ${B.fullDate(p)}`);else navigator.clipboard?.writeText(`${B.name(p)}’s birthday — ${B.fullDate(p)}`);break;
    case 'message':openURL('smsto:'+encodeURIComponent(p.phone)+'?body='+encodeURIComponent(B.message(p)));break;
    case 'call':openURL('tel:'+encodeURIComponent(p.phone));break;
    case 'whatsapp':openURL('https://wa.me/'+p.phone.replace(/\D/g,'')+'?text='+encodeURIComponent(B.message(p)));break;
    case 'email':openURL('mailto:'+encodeURIComponent(p.email)+'?subject='+encodeURIComponent('Happy birthday!'));break;
    case 'reload-plans':billing.loading=true;render(true);native?.plans();if(!native){billing.loading=false;render(true);}break;
    case 'buy':native?.buy(id);break;
    case 'restore':native?.restore();if(!native)showMessage('Restore purchases in the Android app through Google Play.');break;
    case 'manage':openURL('https://play.google.com/store/account/subscriptions?package=com.oanarinaldi.nextbirthday');break;
    case 'open-privacy':openURL('https://oanarinaldi.com/nextbirthdayandroidprivacy.html');break;
    case 'open-terms':openURL('https://oanarinaldi.com/nextbirthdayterms.html');break;
    case 'review':modal={type:'review'};render(true);break;
  }
});
function collectEditor(){
  if(!editDraft)return;const f=document.getElementById('save-person');if(!f)return;const data=new FormData(f),p=editDraft;
  for(const k of ['firstName','lastName','notes'])p[k]=String(data.get(k)||'');
  p.birthMonth=Number(data.get('birthMonth'));p.birthDay=Number(data.get('birthDay'));
  p.birthYear=data.has('includeYear')?Math.min(new Date().getFullYear(),Math.max(1900,Number(data.get('birthYear'))||1995)):null;
  p.birthDay=Math.min(p.birthDay,new Date(p.birthYear||2000,p.birthMonth,0).getDate());
  const group=data.get('relationshipRaw');p.relationshipRaw=group==='__custom__'?String(data.get('customRelationship')||'Custom group'):group||null;
  p.isFavorite=data.has('isFavorite');const hadCustom=p.usesCustomReminders;p.usesCustomReminders=data.has('usesCustomReminders');if(hadCustom)p.customReminderDays=B.OFFSETS.filter(d=>data.has('customReminder-'+d));
}
document.addEventListener('input',e=>{
  if(e.target.name==='search'){search=e.target.value;const cursor=e.target.selectionStart;render(true);const f=document.querySelector('[name=search]');f.focus();f.setSelectionRange(cursor,cursor);}
  if(route.screen==='edit'){
    // Keep typed fields when the photo picker or a conditional editor control opens.
    const name=e.target.name;if(['firstName','lastName','notes','customRelationship'].includes(name)&&editDraft){if(name==='customRelationship')editDraft.relationshipRaw=e.target.value;else editDraft[name]=e.target.value;}
  }
});
document.addEventListener('change',e=>{
  const t=e.target,n=t.name;
  if(t.dataset.contact!=null){const i=Number(t.dataset.contact);if(t.checked)selectedContacts.add(i);else selectedContacts.delete(i);render(true);return;}
  if(route.screen==='edit'){collectEditor();if(['birthMonth','birthYear','includeYear','relationshipRaw','usesCustomReminders'].includes(n))render(true);return;}
  if(n==='sort'){sort=t.value;render(true);return;}
  if(route.screen==='settings'){
    if(n==='notificationTime'){const [h,m]=t.value.split(':').map(Number);change(s=>{s.settings.notificationHour=h;s.settings.notificationMinute=m;});}
    else if(Object.hasOwn(B.DEFAULTS,n))change(s=>s.settings[n]=t.type==='checkbox'?t.checked:t.value);
  }
  if(route.screen==='plan'&&['celebrationIntent','celebrationBudget','connectionCadence'].includes(n)){
    if(n==='connectionCadence'&&!pro())return;
    if(n==='celebrationBudget'&&(!Number.isFinite(Number(t.value))||Number(t.value)<0)){showMessage('Enter a budget of zero or more.');render(true);return;}
    updatePerson(route.id,p=>p[n]=n==='celebrationIntent'?t.value:Number(t.value),false);
  }
  if(route.screen==='detail'&&n==='notes')updatePerson(route.id,p=>p.notes=t.value,false);
});
document.addEventListener('submit',e=>{
  e.preventDefault();const f=e.target,d=new FormData(f);
  try{
    if(f.id==='save-person'){
      collectEditor();let p=structuredClone(editDraft);p.firstName=p.firstName.trim();p.lastName=p.lastName.trim();B.validate(p);
      const s=structuredClone(state),index=s.people.findIndex(x=>x.uuid===p.uuid);if(index>=0)s.people[index]=p;else s.people.push(p);s.settings.hasCompletedOnboarding=true;
      if(persist(s)){editDraft=null;if(historyStack.length&&historyStack[historyStack.length-1].screen!=='edit'&&state.settings.hasCompletedOnboarding)goBack();else switchTab('today');if(native&&!native.notificationsAllowed())native.requestNotifications();}
    }
    if(f.id==='add-gift'){const title=String(d.get('gift')||'').trim();if(title)updatePerson(route.id,p=>p.giftIdeas.push({uuid:B.uid(),title,isPurchased:false,createdAt:new Date().toISOString()}));}
    if(f.id==='add-step'&&pro()){const step=String(d.get('step')||'').trim();if(step)updatePerson(route.id,p=>{if(!p.celebrationChecklist.includes(step))p.celebrationChecklist.push(step);});}
    if(f.id==='add-moment'){
      const raw=String(d.get('connectionDate')||''),date=new Date(raw+'T12:00:00');if(!Number.isFinite(+date)||B.today(date)>B.today())throw Error('Choose today or an earlier date.');
      const note=String(d.get('journal')||'').trim();updatePerson(route.id,p=>{p.connectionJournal.unshift(date.toLocaleDateString(undefined,{dateStyle:'medium'})+' — '+(note||'Spent time together'));if(!p.lastConnectionDate||date>new Date(p.lastConnectionDate))p.lastConnectionDate=date.toISOString();});
    }
    if(f.id==='review-form'){if(native?.reviewAccess(String(d.get('reviewCode')||''))){modal=null;showMessage('Reviewer access is active for 30 days.');billing.isPro=true;render(true);}else showMessage('That access code is not valid.');}
  }catch(error){showMessage(error.message);}
});
window.receiveImport=raw=>{try{const result=B.mergeBackup(state,raw);if(persist(result.state)){showMessage(`Imported ${result.added}. Skipped ${result.skipped} already saved.`);render(true);}}catch(e){showMessage(e.message||"That file isn't a Next Birthday backup.");}};
window.receivePhoto=data=>{if(editDraft){editDraft.photoData=data;render(true);}};
window.receiveContacts=data=>{contactsLoading=false;contactsDenied=data==null;contactCandidates=(data||[]).map(p=>B.person(p));selectedContacts=new Set(contactCandidates.map((p,i)=>contactKnown(p)?-1:i).filter(i=>i>=0));if(route.screen==='contacts')render(true);};
window.onBilling=value=>{billing=value;if(route.screen==='pro'||route.screen==='plan'||route.screen==='today')render(true);};
window.notificationPermission=ok=>{showMessage(ok?'Birthday reminders are enabled.':'Notifications are off. Enable them in Android settings to get reminders.');if(route.screen==='settings')render(true);};
window.openDeepLink=url=>{try{const u=new URL(url);if(u.protocol!=='nextbirthday:')return;if(u.hostname==='add')openEditor(null);else if(u.hostname==='person'){const id=u.pathname.slice(1);if(state.people.some(p=>p.uuid===id))navigate('detail',id);}}catch{}};
window.refreshData=()=>{if(!native)return;try{const current=B.read(native.read());if(current.revision!==state.revision){state=current;render(true);}}catch(e){storageError=e.message;render();}};
setInterval(()=>{const p=route.id?person():B.sorted(state.people)[0];if(p)document.querySelectorAll('.countdown').forEach(el=>el.innerHTML=countdownParts(p));},1000);
// Preview fixtures are available only without the Android bridge and never enter a device store.
if(!native&&new URLSearchParams(location.search).has('demo')){state=B.demo();route={screen:new URLSearchParams(location.search).get('screen')||'today'};if(['plan','detail','gifts','quick'].includes(route.screen))route.id=state.people[0].uuid;}
render();

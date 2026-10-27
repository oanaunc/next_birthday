/* Run against this app's debug WebView on an Android emulator. Requires Playwright. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),adb=process.env.ADB||path.join(process.env.HOME,'Library/Android/sdk/platform-tools/adb');
const screenshots=path.join(root,'GooglePlay/screenshots/phone');fs.mkdirSync(screenshots,{recursive:true});
const sh=(...args)=>execFileSync(adb,args,{encoding:'utf8'});
async function connect(){const pid=sh('shell','pidof','com.oanarinaldi.nextbirthday').trim();assert(pid,'Start the debug app on an emulator first.');sh('forward','tcp:9238','localabstract:webview_devtools_remote_'+pid);const b=await chromium.connectOverCDP('http://127.0.0.1:9238');return {browser:b,page:b.contexts()[0].pages()[0]};}
async function main(){
  sh('shell','pm','grant','com.oanarinaldi.nextbirthday','android.permission.POST_NOTIFICATIONS');
  let {browser,page}=await connect();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const original=await page.evaluate(()=>Android.read());
  const paint=async()=>{await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(()=>requestAnimationFrame(r)))));await new Promise(r=>setTimeout(r,250));};
  const save=async name=>{await page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0);});sh('shell','input','keyevent','111');await page.getByRole('main').waitFor();await paint();fs.writeFileSync(path.join(screenshots,name+'.png'),execFileSync(adb,['exec-out','screencap','-p']));};
  try{
    await page.evaluate(()=>{const s=Birthday.empty();s.revision=JSON.parse(Android.read()||'{"revision":0}').revision;state=s;storageError=null;persist(s);onboardingPage=0;route={screen:'today'};render();});
    await save('01-welcome');
    await page.getByRole('button',{name:'Continue',exact:true}).click();
    await page.getByRole('button',{name:"I'll do this later",exact:true}).click();
    await page.getByRole('button',{name:'Add your first person',exact:true}).click();
    await page.getByRole('textbox',{name:'First name',exact:true}).fill('Ada');await page.getByRole('textbox',{name:'Last name',exact:true}).fill('Lovelace');
    await page.getByRole('combobox',{name:'Month',exact:true}).selectOption('2');await page.getByRole('checkbox',{name:'Include year',exact:true}).uncheck();await page.getByRole('combobox',{name:'Day',exact:true}).selectOption('29');
    await page.getByRole('combobox',{name:'Relationship',exact:true}).selectOption('__custom__');await page.getByRole('textbox',{name:'Group name',exact:true}).fill('Chosen family');
    await page.getByRole('button',{name:'Save',exact:true}).click();
    let saved=await page.evaluate(()=>JSON.parse(Android.read()));assert.equal(saved.people.length,1);assert.equal(saved.people[0].birthYear,null);assert.equal(saved.people[0].birthDay,29);assert.equal(saved.people[0].relationshipRaw,'Chosen family');
    console.log('PASS: onboarding, conditional date editor, custom relationship, native persistence');
    await page.locator('.occasion').click();
    await page.getByRole('textbox',{name:'A picnic at their favorite spot…',exact:true}).fill('An afternoon at the botanical garden');
    await page.getByRole('spinbutton',{name:'0',exact:true}).fill('40');await page.getByRole('spinbutton',{name:'0',exact:true}).blur();
    await page.getByRole('textbox',{name:'What do you want to remember?',exact:true}).fill('A long walk and a good conversation.');
    await page.getByRole('button',{name:'Save a moment together',exact:true}).click();
    saved=await page.evaluate(()=>JSON.parse(Android.read()));assert.equal(saved.people[0].celebrationBudget,40);assert.equal(saved.people[0].celebrationIntent,'An afternoon at the botanical garden');assert.match(saved.people[0].connectionJournal[0],/A long walk/);assert.equal(await page.locator('#add-step').count(),0);
    console.log('PASS: free intentions, budget and journaling; Pro editing stays locked');
    await page.getByRole('button',{name:'Birthday details & gift ideas',exact:true}).click();
    await page.getByRole('textbox',{name:'Add an idea',exact:true}).fill('Handmade photo album');await page.getByRole('button',{name:'Add gift idea',exact:true}).click();
    await page.getByRole('button',{name:'Mark gifted: Handmade photo album',exact:true}).click();
    saved=await page.evaluate(()=>JSON.parse(Android.read()));assert.equal(saved.people[0].giftHistory.length,1);assert.equal(saved.people[0].giftIdeas[0].isPurchased,true);
    await page.getByRole('button',{name:'Undo gifted: Handmade photo album',exact:true}).click();saved=await page.evaluate(()=>JSON.parse(Android.read()));assert.equal(saved.people[0].giftHistory.length,0);
    console.log('PASS: gift idea purchase history and undo through the real app');
    await page.evaluate(()=>switchTab('people'));await page.getByRole('searchbox',{name:'Search name, note, month…',exact:true}).fill('Chosen family');assert.equal(await page.locator('.person-row').count(),1);
    await page.getByRole('searchbox',{name:'Search name, note, month…',exact:true}).fill('Nobody');assert.equal(await page.locator('.person-row').count(),0);
    await page.evaluate(()=>switchTab('settings'));await page.getByRole('checkbox',{name:'Show zodiac signs',exact:true}).check();await page.getByRole('button',{name:'Sky',exact:true}).click();
    saved=await page.evaluate(()=>JSON.parse(Android.read()));assert.equal(saved.settings.showZodiac,true);assert.equal(saved.settings.accentIndex,1);
    await page.evaluate(()=>{const backup=Birthday.backup(state);window.receiveImport(JSON.stringify(backup));});saved=await page.evaluate(()=>JSON.parse(Android.read()));assert.equal(saved.people.length,1);
    console.log('PASS: search, settings persistence and duplicate-safe backup import');
    // Verify the same database survives a new Activity and a fresh WebView process.
    await browser.close();sh('shell','am','force-stop','com.oanarinaldi.nextbirthday');sh('shell','am','start','-n','com.oanarinaldi.nextbirthday/.MainActivity');
    for(let attempt=0;attempt<30;attempt++){try{({browser,page}=await connect());await page.waitForFunction(()=>typeof Android!=='undefined'&&typeof Birthday!=='undefined',{},{timeout:1000});break;}catch(e){if(attempt===29)throw e;await new Promise(r=>setTimeout(r,100));}}
    assert.equal(await page.evaluate(()=>JSON.parse(Android.read()).people[0].firstName),'Ada');console.log('PASS: process restart restores the native database');
    // Screenshots use the same sample people, plans, and artwork as the iOS showroom.
    await page.evaluate(()=>{const s=Birthday.demo();s.revision=state.revision;s.settings.hasCompletedOnboarding=true;persist(s);billing.isPro=false;switchTab('today');});
    await save('02-today');await page.evaluate(()=>switchTab('birthdays'));await save('03-birthdays');await page.evaluate(()=>switchTab('people'));await save('04-people');
    await page.evaluate(()=>navigate('plan',state.people[0].uuid));await save('05-plan');await page.evaluate(()=>document.getElementById('journal')?.scrollIntoView());await paint();fs.writeFileSync(path.join(screenshots,'06-journal.png'),execFileSync(adb,['exec-out','screencap','-p']));
    await page.evaluate(()=>navigate('gifts',state.people[0].uuid));await save('07-gifts');await page.evaluate(()=>navigate('calendar'));await save('08-calendar');await page.evaluate(()=>navigate('pro'));await save('09-pro');await page.evaluate(()=>switchTab('settings'));await save('10-settings');await page.evaluate(()=>navigate('privacy'));await save('11-privacy');
    await page.evaluate(()=>openEditor(null));await save('12-add');
    const broken=await page.evaluate(()=>[...document.images].filter(i=>!i.complete||!i.naturalWidth).map(i=>i.src));assert.deepEqual(broken,[]);assert.deepEqual(errors,[]);console.log('PASS: all showroom screens render with no JavaScript errors or missing images');
  }finally{
    if(browser){try{await page.evaluate(raw=>{const restored=raw?Birthday.read(raw):Birthday.empty();restored.revision=state.revision;persist(restored);route={screen:'today'};historyStack=[];editDraft=null;render();},original);}finally{await browser.close();}}
  }
}
main().catch(e=>{console.error(e);process.exitCode=1;});

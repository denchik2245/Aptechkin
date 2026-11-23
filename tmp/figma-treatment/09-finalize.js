const mutations=new Set([section.id]);
const allFrames=section.children.filter(n=>n.type==='FRAME');
for(const f of allFrames){
 for(const n of f.findAllWithCriteria({types:['INSTANCE']})){
  if(n.name.startsWith('Вариант · ')){if(n.children[0]){n.children[0].visible=false;mutations.add(n.children[0].id);}}
  if(f.name.startsWith('Схема /')&&n.name==='stock control'){
   for(const t of n.findAllWithCriteria({types:['TEXT']}))if(t.characters==='Осталось'||t.characters==='Остаток'){t.characters='Разовая доза';mutations.add(t.id);}
  }
  if(n.name.startsWith('Упаковка · ')&&n.type==='INSTANCE'){
   const txt=n.findAllWithCriteria({types:['TEXT']}).map(t=>t.characters).join(' ');
   if(txt.includes('просрочены')){n.setProperties({'Статус#697:16':'697:1059','Подпись#697:19':'Просрочено'});mutations.add(n.id);}
  }
 }
}
const courseList=await figma.getNodeByIdAsync(STATE.screens.courses.id);
for(const n of courseList.findAllWithCriteria({types:['INSTANCE']})){
 if(n.name==='course card'){
  const title=n.findAllWithCriteria({types:['TEXT']}).find(t=>t.name==='title')?.characters;
  if(title==='Простуда'){n.setProperties({'Принято#722:32':'21 принято · 1 пропуск'});mutations.add(n.id);}
  else if(title==='Витамин D'||title==='Давление'){
   const p=n.children.find(c=>c.name==='progress');if(p){p.visible=true;const track=p.children.find(c=>c.name==='track');if(track){track.visible=false;mutations.add(track.id);}mutations.add(p.id);}
  }
 }
}
const completed=await figma.getNodeByIdAsync(STATE.screens['courses-completed'].id);
for(const t of completed.findAllWithCriteria({types:['TEXT']}))if(t.characters.startsWith('Я · 25 октября')&&t.characters.includes('28 приёмов')){t.characters=t.characters.replace('28 приёмов','48 приёмов');mutations.add(t.id);}
const schema=await figma.getNodeByIdAsync(STATE.screens['schema-daily'].content);add(schema,L('Приём по необходимости','schema-prn'));mutations.add(schema.id);
const manual=await figma.getNodeByIdAsync(STATE.screens['manual-drug'].content);add(manual,L('Указать запас позже','stock-unknown'));mutations.add(manual.id);
const linksToWire=[...STATE.links,...links]; let wired=0;
for(const link of linksToWire){
 if(link.to==='permission')link.to='permission-enabled';
 const source=await figma.getNodeByIdAsync(link.from);
 if(!source)throw new Error('Missing prototype source '+link.from);
 let owner=source;while(owner.parent&&owner.parent!==section)owner=owner.parent;
 if(owner.id===STATE.screens.history.id&&link.to==='intake-edit')link.to='intake-correct';
 if(owner.id===STATE.screens['today-mom'].id&&link.to==='intake-edit')link.to='already-marked';
 const destination=STATE.screens[link.to];if(!destination)throw new Error('Missing destination '+link.to);if(owner.id===destination.id)continue;
 await source.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:destination.id,navigation:'NAVIGATE',transition:{type:'DISSOLVE',duration:0.18,easing:{type:'EASE_OUT'}}}]}]);mutations.add(source.id);wired++;
}
for(const f of allFrames){
 const nav=f.children.find(n=>n.type==='INSTANCE'&&n.name==='tab bar / treatment');
 if(nav){const pharmacy=nav.findAllWithCriteria({types:['TEXT']}).find(t=>t.characters==='Аптечка');if(pharmacy){await pharmacy.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:'826:4877',navigation:'NAVIGATE',transition:null}]}]);mutations.add(pharmacy.id);}}
}
const headers=section.children.filter(n=>n.type==='TEXT'&&/^\d\d · /.test(n.name)).sort((a,b)=>a.y-b.y);
const rows=headers.map((h,i)=>({header:h,frames:allFrames.filter(f=>f.y>=h.y&&f.y<(headers[i+1]?.y??Infinity)).sort((a,b)=>a.x-b.x)}));
let y=100;for(const row of rows){row.header.x=64;row.header.y=y;mutations.add(row.header.id);row.frames.forEach((f,i)=>{f.x=64+i*438;f.y=y+64;mutations.add(f.id);});y+=64+Math.max(...row.frames.map(f=>f.height))+96;}
section.resizeWithoutConstraints(2820,y+24);
const intro=T('Обновлено 5 ноября 2026 · ежедневные действия, курсы, напоминания и совместный учёт','body','muted',2600);section.appendChild(intro);intro.x=64;intro.y=42;
section.name='Лечение';const original=await figma.getNodeByIdAsync('723:3238');original.name='Архив / Лечение до правок · 05.11.2026';mutations.add(original.id);
const titleCounts={};const imageNodes=[];const fonts=new Set();let count=0;
for(const n of section.findAll(()=>true)){count++;titleCounts[n.type]=(titleCounts[n.type]||0)+1;if('fills'in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE'))imageNodes.push({id:n.id,name:n.name,type:n.type,w:n.width,h:n.height});if(n.type==='TEXT'){let v=n.visible,p=n.parent;while(p&&p!==section){v=v&&p.visible;p=p.parent;}if(v){for(const f of n.getStyledTextSegments(['fontName']))fonts.add(f.fontName.family);}}}
const wrongFonts=[...fonts].filter(f=>f!=='Manrope'&&f!=='SF Pro');if(wrongFonts.length)throw new Error('Unexpected fonts '+wrongFonts.join(', '));
figma.viewport.scrollAndZoomIntoView([await figma.getNodeByIdAsync(STATE.screens.today.id)]);
return result({phase:'finalize',mutatedNodeIds:[...mutations],screenCount:allFrames.length,prototypeConnections:wired,structure:{descendants:count,types:titleCounts,imageNodes,visibleFonts:[...fonts]},sectionBounds:{x:section.x,y:section.y,w:section.width,h:section.height},rows:rows.map(r=>({id:r.header.id,name:r.header.name,y:r.header.y,frames:r.frames.map(f=>({id:f.id,name:f.name,x:f.x,y:f.y,w:f.width,h:f.height}))}))});


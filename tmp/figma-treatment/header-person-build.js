await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const source=await figma.getNodeByIdAsync('1064:22059');
const fonts=new Map();for(const t of source.findAllWithCriteria({types:['TEXT']}))for(const seg of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(seg.fontName),seg.fontName);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const parent=figma.createSection();parent.name='Лечение / Человек в заголовке';parent.x=9997;parent.y=31119;parent.resizeWithoutConstraints(1442,4600);
const created=[parent.id],roots=[],selectors={},stats=[];
const switcher=await figma.getNodeByIdAsync('823:4983');
const muted=await figma.variables.getVariableByIdAsync('VariableID:6:38');
function emptyLine(){const t=figma.createText();created.push(t.id);t.name='Нет приёмов';t.textStyleId='S:5309bd921ef00491d7a3e6ba9f86900e417639c1,';t.resize(358,20);t.textAutoResize='HEIGHT';t.characters='Нет запланированных приёмов';t.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',muted)];return t;}
for(const [i,person] of ['Все','Я','Мама','Миша'].entries()){
 const f=source.clone();parent.appendChild(f);f.name='Лечение / Сегодня · D — Человек в заголовке / '+person;f.x=64+i%3*462;f.y=160+Math.floor(i/3)*1600;
 const header=f.children.find(n=>n.name==='Header'),h=header.children[0],old=h.children.find(n=>n.type==='TEXT'&&n.name==='Title');
 const selector=switcher.createInstance();created.push(selector.id);selector.name='Выбор человека / '+person;selector.setProperties({'Название#823:51':person});
 h.insertChild(0,selector);selector.layoutPositioning='AUTO';selector.layoutSizingHorizontal='HUG';selector.layoutSizingVertical='HUG';selector.counterAxisAlignItems='CENTER';
 const label=selector.children.find(n=>n.type==='TEXT');label.textStyleId=old.textStyleId;label.textAutoResize='WIDTH_AND_HEIGHT';label.fills=JSON.parse(JSON.stringify(old.fills));old.visible=false;
 h.primaryAxisAlignItems='SPACE_BETWEEN';h.itemSpacing=16;h.counterAxisAlignItems='CENTER';selectors[person]=selector.id;
 const c=f.children.find(n=>n.name==='Content'),people=c.children.find(n=>n.name==='People');people.visible=false;
 let total=0,taken=0,visibleActors=[];
 for(const periodName of ['Утро','День','Вечер']){
  const period=c.children.find(n=>n.name===periodName),body=period.children.find(n=>n.name==='Приёмы / '+periodName);let periodVisible=0;
  for(const line of body.children){const intake=line.children.find(n=>n.type==='INSTANCE'&&(n.name==='intake row'||n.name==='intake now'));if(!intake)continue;
   const isNow=intake.name==='intake now';const texts=intake.findAllWithCriteria({types:['TEXT']});const actor=(texts.find(t=>t.name===(isNow?'time':'dose')).characters.startsWith('Мама')?'Мама':'Я');
   const visible=person==='Все'||person===actor;line.visible=visible;if(!visible)continue;
   periodVisible++;total++;visibleActors.push(actor);const main=await intake.getMainComponentAsync();if(main.id==='722:3226')taken++;
   if(person!=='Все'){
    if(isNow)intake.setProperties({'Время#722:27':'Сейчас'});
    else{const dose=texts.find(t=>t.name==='dose').characters.replace(/^(Я|Мама)\s*·\s*/,'');intake.setProperties({'Доза#722:6':dose});const d=intake.findAllWithCriteria({types:['TEXT']}).find(t=>t.name==='dose');d.textStyleId='S:5309bd921ef00491d7a3e6ba9f86900e417639c1,';d.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',muted)];d.textAutoResize='HEIGHT';}
   }
  }
  if(!periodVisible){const t=emptyLine();body.appendChild(t);t.layoutSizingHorizontal='FILL';t.layoutSizingVertical='HUG';}
 }
 if(person!=='Все'){const week=c.children.find(n=>n.name==='Week');for(const cell of week.children){const main=await cell.getMainComponentAsync();if(main.id!=='722:3307'){const dot=cell.children.find(n=>n.type==='ELLIPSE'||n.name==='dot');if(dot)dot.visible=false;}}}
 const count=c.children.find(n=>n.name==='Summary').children.find(n=>n.type==='TEXT'&&n.name==='Count');count.characters=total?'Принято '+taken+' из '+total:'Нет приёмов';
 f.primaryAxisSizingMode='AUTO';const nav=f.children.find(n=>n.name.startsWith('Tab Bar'));nav.y=f.height-nav.height;
 roots.push({id:f.id,name:f.name,person,selector:selector.id,w:f.width,h:f.height});stats.push({person,total,taken,visibleActors});
}
const all=new Set(created);for(const r of roots){const f=await figma.getNodeByIdAsync(r.id);all.add(f.id);for(const n of f.findAll(()=>true))all.add(n.id);}
return {sectionId:parent.id,roots,selectors,stats,createdNodeIds:[...all],mutatedNodeIds:[]};

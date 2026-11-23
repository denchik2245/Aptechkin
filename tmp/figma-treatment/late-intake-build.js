await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const source=await figma.getNodeByIdAsync('1068:21774');
const shellSource=await figma.getNodeByIdAsync('880:14960');
const bannerSource=await figma.getNodeByIdAsync('1075:22859');
const selectSource=await figma.getNodeByIdAsync('727:4762');
const saveSource=await figma.getNodeByIdAsync('727:4774');
const dimSource=await figma.getNodeByIdAsync('880:14959');
const fonts=new Map();for(const root of [source,shellSource,bannerSource,selectSource,saveSource])for(const t of root.findAllWithCriteria({types:['TEXT']}))for(const s of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(s.fontName),s.fontName);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const section=figma.createSection();section.name='Лечение / Поздняя отметка';section.x=4202;section.y=31119;section.resizeWithoutConstraints(1442,2700);
const ink=await figma.variables.getVariableByIdAsync('VariableID:6:39'),blue=await figma.variables.getVariableByIdAsync('VariableID:6:42'),muted=await figma.variables.getVariableByIdAsync('VariableID:6:38');
const created=[section.id],roots=[];
const paint=v=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',v);
const nav=id=>[{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:id,navigation:'NAVIGATE',transition:null}]}];
function caption(value,x,y,size=18){const t=figma.createText();section.appendChild(t);t.name=value;t.textStyleId=size===24?'S:588b587a7e25f65e7c4cbf4810812786e3de75c4,':'S:6e3b926f8631a9bd6ee84b889c1088b3b5d6bd52,';t.characters=value;t.fills=[paint(ink)];t.x=x;t.y=y;created.push(t.id);return t;}
function textValue(n,name,value){const t=n.findAllWithCriteria({types:['TEXT']}).find(t=>t.name===name);t.characters=value;return t;}
function collect(n){created.push(n.id,...n.findAll(()=>true).map(c=>c.id));}
function setClock(f){const status=f.children.find(n=>n.name==='Status bar');const t=status.findAllWithCriteria({types:['TEXT']}).find(t=>t.characters==='9:41');if(t){t.characters='13:20';t.textAutoResize='WIDTH_AND_HEIGHT';}}
function base(name){const f=source.clone();section.appendChild(f);f.name=name;setClock(f);const c=f.children.find(n=>n.name==='Content');const morning=c.children.find(n=>n.name==='Утро').children.find(n=>n.name==='Приёмы / Утро');const old=morning.children[1];const vitamin=morning.children[0].clone();morning.insertChild(1,vitamin);old.remove();const row=vitamin.children.find(n=>n.type==='INSTANCE');row.setProperties({'Название#722:0':'Витамин D3','Доза#722:6':'Я · 1 капсула · во время завтрака','Статус#722:12':'Принято в 08:10'});for(const t of row.findAllWithCriteria({types:['TEXT']})){if(['title','dose','status'].includes(t.name)){t.layoutSizingHorizontal='FILL';t.textAutoResize='HEIGHT';}}return f;}
const before=base('Лечение / Поздний приём / 13:20 — нет отметки');
const card=before.findAll(n=>n.type==='INSTANCE'&&n.name==='intake now')[0];card.setProperties({'Время#722:27':'Я · по плану в 13:00'});
const hint=card.findAllWithCriteria({types:['TEXT']}).find(n=>n.name==='hint');hint.visible=false;
const actionBlock=card.children.find(n=>n.name==='actions'),secondary=actionBlock.children.find(n=>n.name==='secondary');secondary.children[0].visible=false;secondary.children[1].layoutSizingHorizontal='FILL';
const accept=actionBlock.children.find(n=>n.type==='INSTANCE');
before.primaryAxisSizingMode='AUTO';before.children.find(n=>n.name.startsWith('Tab Bar')).y=before.height-95;
function marked(name,time,corrected){const f=base(name),c=f.children.find(n=>n.name==='Content'),day=c.children.find(n=>n.name==='День'),body=day.children.find(n=>n.name==='Приёмы / День');const line=body.children[0],old=line.children.find(n=>n.type==='INSTANCE');const first=c.children.find(n=>n.name==='Утро').children.find(n=>n.name==='Приёмы / Утро').children[0].children.find(n=>n.type==='INSTANCE');const r=first.clone();line.insertChild(1,r);old.remove();r.setProperties({'Название#722:0':'Ибупрофен, 200 мг','Доза#722:6':'Я · 1 таблетка · после еды','Статус#722:12':'Принято в '+time});r.layoutSizingHorizontal='FILL';r.layoutSizingVertical='HUG';for(const t of r.findAllWithCriteria({types:['TEXT']})){if(['title','dose','status'].includes(t.name)){t.layoutSizingHorizontal='FILL';t.textAutoResize='HEIGHT';}}
textValue(c.children.find(n=>n.name==='Summary'),'Count','Принято 5 из 7');
const banner=bannerSource.clone();c.insertChild(2,banner);banner.name='Подтверждение отметки';banner.layoutSizingHorizontal='FILL';const title=textValue(banner,'Title',corrected?'Время приёма изменено':'Приём отмечен в '+time),next=textValue(banner,'Next',corrected?'Принято в '+time+' · по плану в 13:00':'Изменить время');for(const t of [title,next]){t.layoutSizingHorizontal='FILL';t.textAutoResize='HEIGHT';}if(!corrected){next.textStyleId='S:dc34a7f1da72dd5a5eb130bfe04d52e9d0d0ce69,';next.fills=[paint(blue)];}
f.primaryAxisSizingMode='AUTO';f.children.find(n=>n.name.startsWith('Tab Bar')).y=f.height-95;return {f,row:r,change:next};}
const saved=marked('Лечение / Поздний приём / принято в 13:20','13:20',false);
const fixed=marked('Лечение / Поздний приём / уточнено — 13:10','13:10',true);
function form(time){const f=saved.f.clone();section.appendChild(f);f.name='Лечение / Время приёма / '+time;f.layoutMode='NONE';f.resize(390,844);f.clipsContent=true;f.children.find(n=>n.name.startsWith('Tab Bar')).y=749;
const dim=dimSource.clone();f.appendChild(dim);dim.name='Закрыть время приёма';dim.x=0;dim.y=0;dim.resize(390,844);
const sheet=shellSource.clone();f.appendChild(sheet);sheet.name='Уточнить время приёма';const head=sheet.children.find(n=>n.name==='sheet header');head.setProperties({'Заголовок#824:1':'Время приёма'});const close=head.findAll(n=>n.name==='close')[0],grab=head.findAll(n=>n.name==='grabber')[0];const body=sheet.children.find(n=>n.name==='body');for(const n of [...body.children])n.remove();body.itemSpacing=12;
const context=figma.createText();body.appendChild(context);context.name='Контекст приёма';context.textStyleId='S:5309bd921ef00491d7a3e6ba9f86900e417639c1,';context.resize(358,38);context.textAutoResize='HEIGHT';context.characters='Я · Ибупрофен, 200 мг · 1 таблетка\nПо плану в 13:00';context.fills=[paint(muted)];context.layoutSizingHorizontal='FILL';
const date=selectSource.clone();body.appendChild(date);date.name='Дата приёма';date.setProperties({'Подпись#710:12':'Дата','Значение#710:15':'Сегодня, 29 октября'});date.layoutSizingHorizontal='FILL';
const field=selectSource.clone();body.appendChild(field);field.name='Фактическое время приёма';field.setProperties({'Подпись#710:12':'Время приёма','Значение#710:15':time});field.layoutSizingHorizontal='FILL';
const button=saveSource.clone();body.appendChild(button);button.layoutSizingHorizontal='FILL';
sheet.primaryAxisSizingMode='AUTO';sheet.x=0;sheet.y=844-sheet.height;return {f,sheet,field,button,close,grab,dim};}
const edit=form('13:20'),edited=form('13:10');
await accept.setReactionsAsync(nav(saved.f.id));await saved.change.setReactionsAsync(nav(edit.f.id));await saved.row.setReactionsAsync(nav(edit.f.id));await fixed.row.setReactionsAsync(nav(edited.f.id));
for(const s of [edit,edited]){for(const n of [s.close,s.grab,s.dim])await n.setReactionsAsync(nav(saved.f.id));}
await edit.field.setReactionsAsync(nav(edited.f.id));await edited.field.setReactionsAsync(nav(edit.f.id));await edit.button.setReactionsAsync(nav(saved.f.id));await edited.button.setReactionsAsync(nav(fixed.f.id));
const layout=[{f:before,x:64,y:160,label:'1 · План 13:00, открыли в 13:20'},{f:saved.f,x:526,y:160,label:'2 · Принял — отметка в 13:20'},{f:fixed.f,x:988,y:160,label:'3 · Уточнили: принято в 13:10'},{f:edit.f,x:64,y:1740,label:'Изменить время · исходное 13:20'},{f:edited.f,x:526,y:1740,label:'Пример ввода · приняли в 13:10'}];
for(const o of layout){o.f.x=o.x;o.f.y=o.y;caption(o.label,o.x,o.y-40);collect(o.f);roots.push({id:o.f.id,name:o.f.name,w:o.f.width,h:o.f.height});}
caption('Поздний приём — быстрая отметка и уточнение времени',64,48,24);
const note=caption('Время слева — по плану. В карточке — фактическое. Следующие приёмы остаются по расписанию.',64,2640,18);note.resize(1314,30);note.textAutoResize='HEIGHT';
const checks=[];for(const r of roots){const f=await figma.getNodeByIdAsync(r.id),nodes=f.findAll(()=>true),types={},images=[];for(const n of nodes){types[n.type]=(types[n.type]||0)+1;if('fills'in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE'))images.push(n.id);}const fontFamilies=[...new Set(f.findAllWithCriteria({types:['TEXT']}).flatMap(t=>t.getStyledTextSegments(['fontName']).map(s=>s.fontName.family)))];if(fontFamilies.some(n=>!['Manrope','SF Pro'].includes(n)))throw Error('Wrong font '+fontFamilies.join(','));checks.push({id:f.id,descendants:nodes.length,types,images,fontFamilies});}
figma.viewport.scrollAndZoomIntoView([before,saved.f,fixed.f]);
return {sectionId:section.id,baseId:source.id,roots,flow:{before:before.id,accept:accept.id,saved:saved.f.id,edit:edit.f.id,edited:edited.f.id,corrected:fixed.f.id},checks,createdNodeIds:[...new Set(created)],mutatedNodeIds:[]};

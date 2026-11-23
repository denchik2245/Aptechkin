await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const base=await figma.getNodeByIdAsync('1068:21774');
const archive=await figma.getNodeByIdAsync('723:3928');
const courseSource=await figma.getNodeByIdAsync('723:3983');
const archiveAction=await figma.getNodeByIdAsync('723:4044');
const segmented=await figma.getNodeByIdAsync('722:3333');
const fonts=new Map();for(const root of [base,archive])for(const t of root.findAllWithCriteria({types:['TEXT']}))for(const seg of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(seg.fontName),seg.fontName);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const tokens={};for(const [name,id] of Object.entries({ink:'6:39',muted:'6:38',blue:'6:42',surface:'6:35',radius:'6:48'}))tokens[name]=await figma.variables.getVariableByIdAsync('VariableID:'+id);
const paint=v=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',v);
const styles={heading:'S:588b587a7e25f65e7c4cbf4810812786e3de75c4,',large:'S:6e3b926f8631a9bd6ee84b889c1088b3b5d6bd52,',bold:'S:83eef1f8f0ace31fd224cecb0cf219601d1032d1,',body:'S:5309bd921ef00491d7a3e6ba9f86900e417639c1,'};
const section=figma.createSection();section.name='Лечение / Курсы — варианты списка';section.x=5884;section.y=31119;section.resizeWithoutConstraints(1442,1220);
const created=[section.id],screens=[];
function text(parent,value,style,color,width){const n=figma.createText();parent.appendChild(n);n.name=value;n.textStyleId=style;n.fills=[paint(color)];if(width){n.resize(width,24);n.textAutoResize='HEIGHT';}else n.textAutoResize='WIDTH_AND_HEIGHT';n.characters=value;return n;}
function stack(parent,name,gap,width){const n=figma.createAutoLayout();parent.appendChild(n);n.name=name;n.layoutMode='VERTICAL';n.fills=[];n.itemSpacing=gap;n.resize(width,10);n.primaryAxisSizingMode='AUTO';n.counterAxisSizingMode='FIXED';return n;}
const data=[
 {name:'Простуда',person:'Я',dates:'25 октября — 3 ноября',drugs:'Ибупрофен · 3 раза в день\nНазивин · 2 раза в день',short:'Ибупрофен · Називин',warning:'Ибупрофена хватит на 2 дня',day:'День 5 из 10',kind:'finite'},
 {name:'Витамин D',person:'Я',dates:'2 месяца приём · 1 месяц перерыв',drugs:'Витамин D3 · 1 капсула утром',short:'Витамин D3 · 1 капсула утром',warning:'',day:'',kind:'cycle'},
 {name:'Давление',person:'Мама',dates:'Постоянно',drugs:'Лозартан · 1 таблетка утром',short:'Лозартан · 1 таблетка утром',warning:'Лозартана хватит на 5 дней',day:'',kind:'continuous'}
];
function card(parent,d,mode,grouped){const n=courseSource.clone();parent.appendChild(n);n.name='Курс / '+d.name+' / '+d.person;n.resize(358,198);n.layoutSizingHorizontal='FILL';n.primaryAxisSizingMode='AUTO';n.setProperties({'Название#722:29':d.name,'Подзаголовок#722:30':(grouped?'':d.person+' · ')+d.dates,'Препараты#722:33':mode==='A'?d.drugs:d.short,'Показать предупреждение#722:35':!!d.warning,'Предупреждение#722:34':d.warning||' ','День#722:31':d.day||' ','Принято#722:32':' '});
 const progress=n.children.find(n=>n.name==='progress');progress.visible=mode==='A'&&d.kind==='finite';
 if(progress.visible){const taken=progress.findAllWithCriteria({types:['TEXT']}).find(n=>n.name==='taken');taken.visible=false;const fill=progress.findAll(n=>n.name==='fill')[0];fill.resize(163,6);}
 for(const t of n.findAllWithCriteria({types:['TEXT']})){if(['title','subtitle','drugs'].includes(t.name)){t.layoutSizingHorizontal='FILL';t.textAutoResize='HEIGHT';}}
 const warning=n.children.find(n=>n.name==='warning');if(d.warning){warning.layoutSizingHorizontal='FILL';warning.counterAxisAlignItems='CENTER';const label=warning.children.find(n=>n.type==='TEXT');label.layoutSizingHorizontal='FILL';label.textAutoResize='HEIGHT';}
 return n;}
const descriptions={A:'Подробно: схема препаратов видна сразу.\nБлиже к архиву; список требует прокрутки.',B:'Компактно: название, получатель, срок и запас.\nБольше курсов помещается на первом экране.',C:'По людям: свои курсы и курсы близких отдельно.\nУдобно сравнить семейный сценарий.'};
const names={A:'Подробные карточки',B:'Компактный список',C:'По людям'};
for(const [index,mode] of ['A','B','C'].entries()){
 const f=base.clone();section.appendChild(f);f.name='Лечение / Курсы / '+mode+' — '+names[mode];f.layoutMode='NONE';f.resize(390,844);f.clipsContent=true;f.x=64+index*462;f.y=160;
 const c=f.children.find(n=>n.name==='Content');for(const n of [...c.children])n.remove();c.paddingTop=8;c.paddingBottom=20;c.paddingLeft=16;c.paddingRight=16;c.itemSpacing=24;
 const viewport=figma.createFrame();f.insertChild(2,viewport);viewport.name='Список курсов / прокрутка';viewport.layoutMode='NONE';viewport.fills=[];viewport.clipsContent=true;viewport.resize(390,615);viewport.x=0;viewport.y=134;viewport.overflowDirection='VERTICAL';viewport.appendChild(c);c.layoutPositioning='AUTO';c.x=0;c.y=0;c.resize(390,100);c.primaryAxisSizingMode='AUTO';
 const seg=segmented.createInstance();c.appendChild(seg);seg.name='segmented';seg.resize(358,42);seg.layoutSizingHorizontal='FILL';
 const selector=f.findAll(n=>n.type==='INSTANCE'&&n.name.startsWith('Выбор человека /'))[0];if(selector)await selector.setReactionsAsync([]);
 if(mode==='C'){
   for(const person of ['Я','Мама']){const group=stack(c,'Активные / '+person,8,358);group.layoutSizingHorizontal='FILL';text(group,person==='Я'?'Я · 2 активных курса':'Мама · 1 активный курс',styles.bold,tokens.muted);const list=stack(group,'Курсы / '+person,12,358);list.layoutSizingHorizontal='FILL';for(const d of data.filter(d=>d.person===person))card(list,d,mode,true);}
 }else{
   const group=stack(c,'Активные курсы',8,358);group.layoutSizingHorizontal='FILL';text(group,'Активные · 3',styles.bold,tokens.muted);const list=stack(group,'Список / Активные',12,358);list.layoutSizingHorizontal='FILL';for(const d of data)card(list,d,mode,false);
 }
 const finished=archiveAction.clone();c.appendChild(finished);finished.name='Завершённые курсы';finished.characters='Завершённые · 2';finished.textAutoResize='HEIGHT';finished.layoutSizingHorizontal='FILL';
 const footer=f.children.find(n=>n.name.startsWith('Tab Bar'));footer.x=0;footer.y=749;
 const left=seg.children.find(n=>n.name==='left');await left.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:'1068:21774',navigation:'NAVIGATE',transition:null}]}]);
 const label=text(section,mode+' · '+names[mode],styles.large,tokens.ink);label.x=f.x;label.y=120;
 const note=text(section,descriptions[mode],styles.body,tokens.muted,390);note.x=f.x;note.y=1040;
 created.push(f.id,...f.findAll(()=>true).map(n=>n.id),label.id,note.id);screens.push({id:f.id,variant:mode,name:f.name,w:f.width,h:f.height,contentHeight:c.height,viewport:viewport.id,viewportHeight:viewport.height,scrolls:c.height>viewport.height,cards:c.findAll(n=>n.type==='INSTANCE'&&n.name.startsWith('Курс /')).map(n=>({id:n.id,name:n.name,w:n.width,h:n.height}))});
}
const heading=text(section,'Курсы — три варианта основного списка',styles.heading,tokens.ink);heading.x=64;heading.y=48;created.push(heading.id);
const note=text(section,'Общий заголовок, выбор человека и кнопка «+» — из выбранной «Основы».',styles.body,tokens.muted,1314);note.x=64;note.y=1148;created.push(note.id);
const checks=[];for(const s of screens){const f=await figma.getNodeByIdAsync(s.id),nodes=f.findAll(()=>true),counts={},imageNodes=[];for(const n of nodes){counts[n.type]=(counts[n.type]||0)+1;if('fills'in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE'))imageNodes.push({id:n.id,name:n.name,type:n.type,w:n.width,h:n.height});}const fontFamilies=[...new Set(f.findAllWithCriteria({types:['TEXT']}).flatMap(t=>t.getStyledTextSegments(['fontName']).map(seg=>seg.fontName.family)))];if(fontFamilies.some(n=>!['Manrope','SF Pro'].includes(n)))throw Error('Unexpected font '+fontFamilies.join(','));checks.push({id:f.id,descendantCount:nodes.length,nodeTypes:counts,imageNodes,fontFamilies});}
figma.viewport.scrollAndZoomIntoView(await Promise.all(screens.map(s=>figma.getNodeByIdAsync(s.id))));
return {sectionId:section.id,screens,checks,createdNodeIds:[...new Set(created)],mutatedNodeIds:[],scope:'Один основной экран вкладки «Курсы», три варианта. Без экранов курса, создания, архива и модальных окон.'};

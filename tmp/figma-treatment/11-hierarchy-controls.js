await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const section=await figma.getNodeByIdAsync('1028:16806');
const frames=section.children.filter(n=>n.type==='FRAME');
const changed=new Set(),created=[],buttonIds=new Set(),chipIds=[],headGroups=[];
const fonts=new Map();
for(const t of section.findAllWithCriteria({types:['TEXT']}))for(const seg of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(seg.fontName),seg.fontName);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const md=await figma.variables.getVariableByIdAsync('VariableID:6:48');
const sm=await figma.variables.getVariableByIdAsync('VariableID:75:287');
const danger=await figma.variables.getVariableByIdAsync('VariableID:296:573');
const clone=v=>JSON.parse(JSON.stringify(v));
const instances=section.findAllWithCriteria({types:['INSTANCE']});
const mains=await Promise.all(instances.map(n=>n.getMainComponentAsync()));
const beforeButtons=[];
for(let i=0;i<instances.length;i++){
 const n=instances[i],mc=mains[i];if(!mc)continue;
 if(['671:2083','671:2086','671:2088','671:2091'].includes(mc.id)){
  buttonIds.add(n.id);beforeButtons.push({id:n.id,main:mc.id,height:n.height,pads:[n.paddingTop,n.paddingRight,n.paddingBottom,n.paddingLeft],fills:n.fills,strokes:n.strokes});
  n.fills=clone(mc.fills);n.strokes=clone(mc.strokes);n.effects=clone(mc.effects);
  n.paddingTop=mc.paddingTop;n.paddingRight=mc.paddingRight;n.paddingBottom=mc.paddingBottom;n.paddingLeft=mc.paddingLeft;
  n.itemSpacing=mc.itemSpacing;n.primaryAxisAlignItems=mc.primaryAxisAlignItems;n.counterAxisAlignItems=mc.counterAxisAlignItems;n.layoutSizingVertical='HUG';
  const source=mc.findAllWithCriteria({types:['TEXT']})[0];
  for(const t of n.findAllWithCriteria({types:['TEXT']})){
   t.textStyleId=source.textStyleId;t.fills=clone(source.fills);t.textAlignHorizontal='CENTER';t.textAlignVertical='CENTER';t.textAutoResize='WIDTH_AND_HEIGHT';changed.add(t.id);
  }
  changed.add(n.id);
 }
 if(['715:2435','715:2440'].includes(mc.id)){
  const label=n.children.find(c=>c.type==='TEXT'&&c.name==='label');
  const hasIcon=n.children.some(c=>c!==label&&c.visible);
  if(label&&!hasIcon){
   n.paddingLeft=16;n.paddingRight=16;n.paddingTop=10;n.paddingBottom=10;
   n.primaryAxisAlignItems='CENTER';n.counterAxisAlignItems='CENTER';
   label.textAlignHorizontal='CENTER';label.textAlignVertical='CENTER';
   changed.add(n.id);changed.add(label.id);chipIds.push(n.id);
  }
 }
}
for(const t of section.findAllWithCriteria({types:['TEXT']}))if(t.name==='Действие · Удалить курс'){
 t.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',danger)];changed.add(t.id);
}
function layout(name,w,gap,padTop=0){
 const f=figma.createAutoLayout('VERTICAL');created.push(f.id);f.name=name;f.resize(w,100);f.primaryAxisSizingMode='AUTO';f.counterAxisSizingMode='FIXED';f.fills=[];f.itemSpacing=gap;
 if(gap===12)f.setBoundVariable('itemSpacing',sm);if(gap===16)f.setBoundVariable('itemSpacing',md);f.paddingTop=padTop;return f;
}
function isTitle(n,next){
 if(n.type==='FRAME'&&n.layoutMode==='HORIZONTAL'&&n.children[0]?.type==='TEXT'&&n.name===n.children[0].characters&&n.children[0].fontSize>=16)return true;
 if(n.type==='TEXT'&&typeof n.fontSize==='number'&&n.fontSize>=18)return true;
 return n.type==='TEXT'&&n.fontSize===16&&n.fontName.style==='Bold'&&!!next&&!buttonIds.has(next.id);
}
function contentFor(h,arr,i){
 const title=h.type==='TEXT'?h.characters:h.name, first=arr[i+1];if(!first||isTitle(first,arr[i+2]))return [];
 let count=1;
 const takeWhile=predicate=>{let j=i+1;while(j<arr.length&&predicate(arr[j],j))j++;return Math.max(1,j-i-1);};
 if(/^Ближайш/.test(title)||/^Вчера,/.test(title)||(/^Сегодня,/.test(title)&&first.name.startsWith('Приём · ')))count=takeWhile(n=>n.name.startsWith('Приём · '));
 else if(title==='Нужно уточнить')count=takeWhile(n=>n.name.startsWith('Приём · ')||n.name==='Действие · Принял раньше или не принимал?');
 else if(title.startsWith('Активные'))count=takeWhile(n=>n.name==='course card');
 else if(title==='Препараты')count=takeWhile(n=>n.type==='FRAME'&&!isTitle(n)||n.name==='Выбор · Ибупрофен'||n.name==='Выбор · Називин');
 else if(title==='Срок')count=takeWhile(n=>n.name==='Выбор · Начало'||n.name==='Варианты'||n.type==='TEXT');
 else if(title==='Напоминания')count=takeWhile(n=>n.name==='Переключатель · Напоминать о приёме'||n.name==='Выбор · На телефоне'||n.name==='Выбор · Повтор');
 else if(title==='Время')count=takeWhile(n=>n.name.startsWith('Выбор · Приём ')||n.name==='Действие · Добавить время');
 else if(title==='Дни приёма')count=takeWhile(n=>n.name==='Варианты'||n.type==='TEXT');
 else if(title==='Участники')count=takeWhile(n=>n.type==='TEXT'||n.name==='Кнопка · Добавить близкого');
 else if(title==='Права на курс')count=takeWhile(n=>n.name.startsWith('Вариант · ')||n.type==='TEXT');
 else if(title==='Если приём не отмечен')count=takeWhile(n=>n.name==='Переключатель · Сообщить маме'||n.name==='Выбор · Через'||n.name==='Мама получит сообщение');
 else if(title==='Октябрь 2026')count=takeWhile(n=>n.name==='Неделя');
 else if(title==='Из ваших аптечек')count=takeWhile(n=>n.name.startsWith('Упаковка · '));
 else if(title==='Что показывать в уведомлениях')count=takeWhile(n=>n.name.startsWith('Вариант · '));
 return arr.slice(i+1,i+1+count);
}
const parents=[];
for(const f of frames){
 const c=f.children.find(n=>n.name==='Content');if(c)parents.push(c);
 const sheet=f.children.find(n=>n.name==='Sheet');const body=sheet?.children.find(n=>n.name==='Содержимое окна');if(body)parents.push(body);
}
for(const parent of parents){
 const arr=[...parent.children],used=new Set();
 for(let i=0;i<arr.length;i++){
  const heading=arr[i];if(used.has(heading.id)||!isTitle(heading,arr[i+1]))continue;
  const nodes=contentFor(heading,arr,i).filter(n=>!used.has(n.id));if(!nodes.length)continue;
  const label=heading.type==='TEXT'?heading.characters:heading.name;
  const index=parent.children.indexOf(heading),w=parent.width-parent.paddingLeft-parent.paddingRight;
  const group=layout('Раздел / '+label,w,8,8);parent.insertChild(index,group);group.layoutSizingHorizontal='FILL';
  group.appendChild(heading);heading.layoutPositioning='AUTO';heading.layoutSizingHorizontal='FILL';
  const body=layout('Содержимое / '+label,w,12);group.appendChild(body);body.layoutSizingHorizontal='FILL';
  for(const n of nodes){body.appendChild(n);n.layoutPositioning='AUTO';n.layoutSizingHorizontal='FILL';used.add(n.id);changed.add(n.id);}
  used.add(heading.id);changed.add(parent.id);changed.add(heading.id);
  headGroups.push({id:group.id,titleId:heading.id,title:label,bodyId:body.id,bodyChildren:nodes.map(n=>n.id),parentId:parent.id});
 }
}
const buttonGroups=[];
for(const parent of parents){
 const arr=[...parent.children];let i=0;
 while(i<arr.length){if(!buttonIds.has(arr[i].id)){i++;continue;}let end=i+1;while(end<arr.length&&buttonIds.has(arr[end].id))end++;
  if(end-i>1){const members=arr.slice(i,end),index=parent.children.indexOf(members[0]);const group=layout('Действия / Основные кнопки',parent.width-parent.paddingLeft-parent.paddingRight,8);parent.insertChild(index,group);group.layoutSizingHorizontal='FILL';for(const b of members){group.appendChild(b);b.layoutPositioning='AUTO';b.layoutSizingHorizontal='FILL';changed.add(b.id);}changed.add(parent.id);buttonGroups.push({id:group.id,buttons:members.map(n=>n.id)});}
  i=end;
 }
}
const sheets=[];
for(const f of frames){if(f.layoutMode==='NONE'){const sheet=f.children.find(n=>n.name==='Sheet');if(sheet){sheet.y=Math.max(62,844-sheet.height);changed.add(sheet.id);sheets.push({id:sheet.id,height:sheet.height,bottom:sheet.y+sheet.height});}}}
const headers=section.children.filter(n=>n.type==='TEXT'&&/^\d\d · /.test(n.name)).sort((a,b)=>a.y-b.y);
const rows=headers.map((h,i)=>({h,frames:frames.filter(f=>f.y>=h.y&&f.y<(headers[i+1]?.y??Infinity)).sort((a,b)=>a.x-b.x)}));
let y=100;for(const row of rows){row.h.y=y;changed.add(row.h.id);for(const f of row.frames){f.y=y+64;changed.add(f.id);}y+=64+Math.max(...row.frames.map(f=>f.height))+96;}
section.resizeWithoutConstraints(2820,y+24);changed.add(section.id);
return {createdNodeIds:created,mutatedNodeIds:[...changed],counts:{screens:frames.length,buttons:buttonIds.size,chips:chipIds.length,headingGroups:headGroups.length,buttonGroups:buttonGroups.length},headGroups,buttonGroups,chipIds,buttonIds:[...buttonIds],sheets,sectionHeight:section.height};


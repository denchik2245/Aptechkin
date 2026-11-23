await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const work=await figma.getNodeByIdAsync('1028:16806');
const fonts=new Map();for(const t of work.findAllWithCriteria({types:['TEXT']}))for(const seg of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(seg.fontName),seg.fontName);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const ink=await figma.variables.getVariableByIdAsync('VariableID:6:39'),muted=await figma.variables.getVariableByIdAsync('VariableID:6:38');
const made=[],changed=new Set([work.id]);
function text(value,size=14,w=390){const t=figma.createText();made.push(t.id);t.name=value;t.textStyleId=size===24?'S:588b587a7e25f65e7c4cbf4810812786e3de75c4,':size===18?'S:6e3b926f8631a9bd6ee84b889c1088b3b5d6bd52,':'S:5309bd921ef00491d7a3e6ba9f86900e417639c1,';t.resize(w,20);t.textAutoResize='HEIGHT';t.characters=value;t.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',size===14?muted:ink)];return t;}
function frame(name,w=1314,vertical=true,gap=24){const f=figma.createAutoLayout(vertical?'VERTICAL':'HORIZONTAL');made.push(f.id);f.name=name;f.resize(w,100);f.primaryAxisSizingMode=vertical?'AUTO':'FIXED';f.counterAxisSizingMode=vertical?'FIXED':'AUTO';f.itemSpacing=gap;f.fills=[];f.counterAxisAlignItems='MIN';return f;}
function put(p,n,stretch=true){p.appendChild(n);n.layoutPositioning='AUTO';if(stretch)n.layoutSizingHorizontal='FILL';return n;}
const descriptions={A:['A · Исходная структура','Рекомендую как основу. В каждой карточке явно указан получатель. Week и всё расписание дня открыты.'],B:['B · Сворачивание выполненного','Выполненные периоды свёрнуты. Приёмы без отметки и отложенные остаются видимыми.'],C:['C · Время отдельной колонкой','Время по плану вынесено слева. Получатель выделен в карточке. Week и периоды дня сохранены.']};
const comparisons=[];let y=64;
for(const [state,title] of [['normal','Обычный день · три варианта'],['issues','Нет отметки и отложенный приём'],['done','Все приёмы отмечены']]){
 const group=frame('Сравнение / '+title);work.appendChild(group);group.x=64;group.y=y;
 put(group,text(title,24,1314));
 const legend=frame('Варианты',1314,false,72);put(group,legend);
 for(const key of ['A','B','C']){const col=frame('Описание / '+key,390,true,8);legend.appendChild(col);col.layoutSizingHorizontal='FIXED';put(col,text(descriptions[key][0],18));if(state==='normal')put(col,text(descriptions[key][1]));}
 const list=frame('Экраны',1314,false,72);put(group,list);
 for(const key of ['A','B','C']){const ref=ROOTS.find(r=>r.state===state&&r.variant===key);const f=await figma.getNodeByIdAsync(ref.id);list.appendChild(f);f.layoutPositioning='AUTO';f.layoutSizingHorizontal='FIXED';f.layoutSizingVertical='HUG';changed.add(f.id);}
 comparisons.push({id:group.id,state,title,w:group.width,h:group.height});y+=group.height+112;
}
work.resizeWithoutConstraints(1442,y-48);work.name='Лечение';
const failures=[],structure={};let descendantCount=0;const imageNodes=[];
for(const n of work.findAll(()=>true)){descendantCount++;structure[n.type]=(structure[n.type]||0)+1;if('fills'in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE'))imageNodes.push({id:n.id,name:n.name,type:n.type,w:n.width,h:n.height});}
for(const ref of ROOTS){
 const f=await figma.getNodeByIdAsync(ref.id);const c=f.children.find(n=>n.name==='Content');
 const week=c.children.find(n=>n.name==='Week');if(!week||week.children.length!==7)failures.push({id:f.id,reason:'Week must have seven days'});
 for(const period of ['Утро','День','Вечер'])if(!c.children.find(n=>n.name===period))failures.push({id:f.id,reason:'Missing period '+period});
 const people=c.children.find(n=>n.name==='People');for(const n of people.children){const t=n.children.find(t=>t.type==='TEXT'&&t.name==='label');if(t){const dx=t.x+t.width/2-n.width/2,dy=t.y+t.height/2-n.height/2;if(Math.abs(dx)>0.1||Math.abs(dy)>0.1)failures.push({id:n.id,reason:'Chip center',dx,dy});}}
}
for(const row of ROWS){const n=await figma.getNodeByIdAsync(row.rowId);const t=n.findAllWithCriteria({types:['TEXT']}).find(t=>t.name===(row.isNow?'time':'dose'));if(!t.characters.startsWith(row.actor))failures.push({id:n.id,reason:'Recipient missing'});}
figma.viewport.scrollAndZoomIntoView([await figma.getNodeByIdAsync(comparisons[0].id)]);
return {createdNodeIds:made,mutatedNodeIds:[...changed],comparisons,roots:ROOTS,checks:{frames:ROOTS.length,intakes:ROWS.length,weekRows:ROOTS.length,failures},structure:{descendantCount,types:structure,imageNodes},workingBounds:{w:work.width,h:work.height}};

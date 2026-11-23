await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const work=await figma.getNodeByIdAsync('1028:16806');
const sources=[['normal','723:3312','Сейчас'],['issues','723:3521','Нет отметки и отложенный приём'],['done','723:3720','Всё отмечено']];
const fonts=new Map();
for(const [,id] of sources){const f=await figma.getNodeByIdAsync(id);for(const t of f.findAllWithCriteria({types:['TEXT']}))for(const seg of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(seg.fontName),seg.fontName);}
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const ink=await figma.variables.getVariableByIdAsync('VariableID:6:39'),muted=await figma.variables.getVariableByIdAsync('VariableID:6:38'),blue=await figma.variables.getVariableByIdAsync('VariableID:6:42');
const btnPrimary=await figma.getNodeByIdAsync('671:2086'),btnSecondary=await figma.getNodeByIdAsync('671:2091');
const created=[],roots=[],rowData=[];
const clone=x=>JSON.parse(JSON.stringify(x));
function fill(t,v){t.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',v)];}
function V(name,w=358,gap=12){const n=figma.createAutoLayout('VERTICAL');created.push(n.id);n.name=name;n.resize(w,100);n.primaryAxisSizingMode='AUTO';n.counterAxisSizingMode='FIXED';n.itemSpacing=gap;n.fills=[];return n;}
function H(name,w=358,gap=8){const n=figma.createAutoLayout('HORIZONTAL');created.push(n.id);n.name=name;n.resize(w,40);n.primaryAxisSizingMode='FIXED';n.counterAxisSizingMode='AUTO';n.itemSpacing=gap;n.counterAxisAlignItems='CENTER';n.fills=[];return n;}
function T(text,style='body',w=358,color=muted){const n=figma.createText();created.push(n.id);n.name=text;n.textStyleId=style==='label'?'S:eaec9a6c0d387eb2015467594c928f2dbb4d90bd,':'S:5309bd921ef00491d7a3e6ba9f86900e417639c1,';n.resize(w,20);n.textAutoResize='HEIGHT';n.characters=text;fill(n,color);return n;}
function put(p,n,stretch=true){p.appendChild(n);n.layoutPositioning='AUTO';if(stretch)n.layoutSizingHorizontal='FILL';return n;}
const variantNames={A:'Исходная структура',B:'Сворачивание выполненного',C:'Время отдельной колонкой'};
const col={A:0,B:1,C:2}[VARIANT];
for(let index=0;index<sources.length;index++){
 const [state,id,label]=sources[index];
 const name='Лечение / Сегодня · '+VARIANT+' — '+variantNames[VARIANT]+' / '+label;
 if(work.findAllWithCriteria({types:['FRAME']}).some(n=>n.name===name))throw new Error('Variant already exists: '+name);
 const f=(await figma.getNodeByIdAsync(id)).clone();work.appendChild(f);f.name=name;f.x=64+col*462;f.y=220+index*1800;f.minHeight=844;
 const content=f.children.find(n=>n.name==='Content');
 const count=content.children.find(n=>n.name==='Summary')?.children.find(n=>n.type==='TEXT'&&n.name==='Count');
 if(count)count.characters='Принято '+(state==='normal'?'4':state==='issues'?'3':'7')+' из 7';
 const people=content.children.find(n=>n.name==='People');if(people){people.resize(358,people.height);people.layoutSizingHorizontal='FILL';}
 const allInstances=f.findAllWithCriteria({types:['INSTANCE']});
 const allMains=await Promise.all(allInstances.map(n=>n.getMainComponentAsync()));
 for(let i=0;i<allInstances.length;i++){
  const n=allInstances[i],mc=allMains[i];if(!mc)continue;
  if(['715:2435','715:2440'].includes(mc.id)){n.paddingLeft=n.paddingRight=16;n.primaryAxisAlignItems=n.counterAxisAlignItems='CENTER';const t=n.children.find(c=>c.type==='TEXT'&&c.name==='label');if(t)t.textAlignHorizontal='CENTER';}
  if(['671:2086','671:2091'].includes(mc.id)){const source=mc.id==='671:2086'?btnPrimary:btnSecondary;n.fills=clone(source.fills);n.strokes=clone(source.strokes);n.paddingTop=n.paddingBottom=source.paddingTop;n.paddingLeft=n.paddingRight=source.paddingLeft;n.primaryAxisAlignItems=n.counterAxisAlignItems='CENTER';n.layoutSizingVertical='HUG';const t=n.findAllWithCriteria({types:['TEXT']})[0],mt=source.findAllWithCriteria({types:['TEXT']})[0];t.textStyleId=mt.textStyleId;t.fills=clone(mt.fills);t.textAlignHorizontal='CENTER';}
 }
 for(const periodName of ['Утро','День','Вечер']){
  const period=content.children.find(n=>n.name===periodName);const title=period.children.find(n=>n.type==='TEXT'&&n.name==='Time');
  const rows=period.children.filter(n=>n.type==='INSTANCE'&&(n.name==='intake row'||n.name==='intake now'));
  period.itemSpacing=8;period.paddingTop=8;
  const body=V('Приёмы / '+periodName,358,12);put(period,body);
  let allTaken=true;const actors=[];
  for(let j=0;j<rows.length;j++){
   const n=rows[j],isNow=n.name==='intake now';const mc=await n.getMainComponentAsync();
   if(mc.id!=='722:3226')allTaken=false;
   const text=n.findAllWithCriteria({types:['TEXT']});const medication=text.find(t=>t.name==='title').characters;
   const actor=medication.startsWith('Лозартан')?'Мама':'Я';actors.push(actor);
   const planned=periodName==='Утро'?(j<2?'08:00':'09:00'):periodName==='День'?'13:00':'21:00';
   const dose=text.find(t=>t.name==='dose').characters.replace(/\s*·\s*Мама\s*$/,'');
   if(isNow){n.setProperties({'Время#722:27':VARIANT==='C'?actor+' · сейчас':actor+' · сейчас, '+planned,'Доза#722:25':dose});}
   else{
    n.setProperties({'Доза#722:6':actor+' · '+dose});
    const who=n.findAllWithCriteria({types:['TEXT']}).find(t=>t.name==='dose');who.setRangeFontName(0,actor.length,{family:'Manrope',style:'Bold'});who.setRangeFills(0,actor.length,[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',ink)]);
    const status=n.findAllWithCriteria({types:['TEXT']}).find(t=>t.name==='status');
    if(mc.id==='722:3236'&&VARIANT!=='C'){n.setProperties({'Статус#722:12':'По плану в '+planned});status.visible=true;fill(status,muted);}
    if(status&&status.visible){status.layoutSizingHorizontal='FILL';status.layoutSizingVertical='HUG';status.textAutoResize='HEIGHT';}
   }
   if(VARIANT==='C'){
    const line=H('Приём по плану / '+planned,358,10);line.counterAxisAlignItems='MIN';put(body,line);
    const clock=V('Время по плану',44,0);clock.paddingTop=12;put(clock,T(planned,'label',44,ink));put(line,clock,false);clock.layoutSizingHorizontal='FIXED';
    if(isNow){const drug=n.children.find(c=>c.name==='drug');const icon=drug?.children.find(c=>c.name==='icon');if(icon)icon.visible=false;}
    else{const icon=n.children.find(c=>c.name==='icon');if(icon)icon.visible=false;}
    n.resize(304,n.height);put(line,n);n.layoutSizingVertical='HUG';
   }else put(body,n);
   rowData.push({frameId:f.id,state,variant:VARIANT,period:periodName,rowId:n.id,actor,planned,medication,isNow});
  }
  if(VARIANT==='B'&&allTaken){
   const h=H('Завершённый период / '+periodName);period.insertChild(0,h);put(h,title);title.characters=periodName+' · '+rows.length+' из '+rows.length;
   const show=T('Показать','body',68,blue);show.textStyleId='S:dc34a7f1da72dd5a5eb130bfe04d52e9d0d0ce69,';put(h,show,false);show.layoutSizingHorizontal='HUG';
   body.visible=false;
   const mine=actors.filter(a=>a==='Я').length,mom=actors.filter(a=>a==='Мама').length;
   const summary=T([mine?'Я: '+mine:null,mom?'Мама: '+mom:null].filter(Boolean).join(' · ')+' · все приёмы отмечены');put(period,summary);
  }
 }
 f.primaryAxisSizingMode='AUTO';const nav=f.children.find(n=>n.name.startsWith('Tab Bar'));if(nav)nav.y=f.height-nav.height;
 roots.push({id:f.id,name:f.name,state,variant:VARIANT,w:f.width,h:f.height});
}
const allCreated=new Set(created);for(const f of roots){const n=await figma.getNodeByIdAsync(f.id);allCreated.add(n.id);for(const c of n.findAll(()=>true))allCreated.add(c.id);}
return {variant:VARIANT,roots,rowData,createdNodeIds:[...allCreated],mutatedNodeIds:[work.id]};

await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('671:828'));
figma.skipInvisibleInstanceChildren=false;
const section=await figma.getNodeByIdAsync('1028:16806');
// Async adaptation of the bundled validateCreation helper.
async function validateCreation(checks){const passed=[],failed=[];for(const c of checks){const n=await figma.getNodeByIdAsync(c.nodeId);if(!n){failed.push({id:c.nodeId,reason:'Missing node'});continue;}const errors=[];if(n.type!==c.expectedType)errors.push('Wrong node type');if(n.name!==c.expectedName)errors.push('Wrong name');if(n.width!==390)errors.push('Wrong screen width');if(errors.length)failed.push({id:n.id,reason:errors.join(', ')});else passed.push(n.id);}return {passed,failed};}
const checks=Object.values(STATE.screens).map(s=>({nodeId:s.id,expectedType:'FRAME',expectedName:s.name}));
const creation=await validateCreation(checks);
const frames=section.children.filter(n=>n.type==='FRAME');
const headers=section.children.filter(n=>n.type==='TEXT'&&/^\d\d · /.test(n.name)).sort((a,b)=>a.y-b.y);
const rows=headers.map((h,i)=>({h,frames:frames.filter(f=>f.y>=h.y&&f.y<(headers[i+1]?.y??Infinity)).sort((a,b)=>a.x-b.x)}));
const changed=[section.id];let y=100;
for(const row of rows){row.h.x=64;row.h.y=y;changed.push(row.h.id);row.frames.forEach((f,i)=>{f.x=64+i*438;f.y=y+64;changed.push(f.id);});y+=64+Math.max(...row.frames.map(f=>f.height))+96;}
section.resizeWithoutConstraints(2820,y+24);
const overlaps=[];for(let i=0;i<frames.length;i++)for(let j=i+1;j<frames.length;j++){const a=frames[i],b=frames[j];if(a.x<b.x+b.width&&a.x+a.width>b.x&&a.y<b.y+b.height&&a.y+a.height>b.y)overlaps.push([a.id,b.id]);}
const clipRisks=[],badFreeText=[],wrongFonts=[],imageNodes=[];let textCount=0,visibleTextCount=0,instanceCount=0,reactionCount=0;
for(const n of section.findAll(()=>true)){
 if(n.type==='INSTANCE')instanceCount++;
 if('reactions'in n)reactionCount+=n.reactions.length;
 if('fills'in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE'))imageNodes.push({id:n.id,name:n.name,type:n.type,w:n.width,h:n.height});
 if(n.type!=='TEXT')continue;textCount++;let visible=n.visible,p=n.parent,inInstance=false;while(p&&p!==section){visible=visible&&p.visible;if(p.type==='INSTANCE')inInstance=true;p=p.parent;}if(!visible||!n.characters.trim())continue;visibleTextCount++;
 for(const seg of n.getStyledTextSegments(['fontName']))if(!['Manrope','SF Pro'].includes(seg.fontName.family))wrongFonts.push({id:n.id,font:seg.fontName});
 if(!inInstance&&n.parent?.type==='FRAME'&&n.parent.layoutMode!=='NONE'&&n.textAutoResize==='NONE')badFreeText.push({id:n.id,text:n.characters});
 if(n.parent?.type==='FRAME'&&n.parent.layoutMode!=='NONE'&&n.x+n.width>n.parent.width+1)clipRisks.push({id:n.id,text:n.characters,width:n.width,parentWidth:n.parent.width});
}
const outOfSection=frames.filter(f=>f.x<0||f.y<0||f.x+f.width>section.width||f.y+f.height>section.height).map(f=>f.id);
return {mutatedNodeIds:changed,checks:{screensPassed:creation.passed.length,screensFailed:creation.failed,overlaps,outOfSection,wrongFonts,badFreeText,horizontalTextRisks:clipRisks},counts:{screens:frames.length,instances:instanceCount,textNodes:textCount,visibleTextNodes:visibleTextCount,reactions:reactionCount},imageNodes,section:{id:section.id,name:section.name,width:section.width,height:section.height},rows:rows.map(r=>({name:r.h.name,screenCount:r.frames.length,y:r.h.y}))};

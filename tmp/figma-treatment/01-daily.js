if(section.children.some(n=>n.name==='Лечение / Сегодня'))throw new Error('Daily phase already started; inspect before retry');
async function daily(key,name,mode='normal',person='Все'){
 const s=await screen(key,name,'Лечение',true);add(s.c,segment());add(s.c,people(person));heading(s.c,'Сегодня, 29 октября','Календарь','calendar');
 if(mode==='done'){
  add(s.c,banner('Все приёмы на сегодня отмечены','7 принято · пропусков нет. Следующий приём завтра в 08:00.','','','ok'));
  add(s.c,select('Принятые сегодня','7 приёмов','history'));
  add(s.c,card('Завтра · 08:00','Я · Ибупрофен, 200 мг\n1 таблетка · после еды','Открыть курс','course-active'));
 }else if(person==='Мама'){
  add(s.c,T('Показаны только приёмы мамы','body','muted'));
  add(s.c,med('Лозартан, 50 мг','1 таблетка','Принято в 09:12 · отметила мама','taken','Мама','intake-edit'));
  add(s.c,banner('На сегодня больше нет приёмов','Следующий — завтра в 09:00.','','','ok'));
  add(s.c,L('Кто может отмечать приёмы','access'));
 }else{
  add(s.c,T(mode==='missed'?'Принято 3 из 7 · 1 без отметки':'Принято 4 из 7','body','muted'));
  if(mode==='missed'){
   heading(s.c,'Нужно уточнить');add(s.c,med('Ибупрофен, 200 мг','1 таблетка · после еды','Нет отметки за 08:00','missed','Я','intake-edit'));add(s.c,L('Принял раньше или не принимал?','intake-edit'));
  }
  add(s.c,now());heading(s.c,'Ближайшие');
  add(s.c,med('Ибупрофен, 200 мг','1 таблетка · после еды','По плану в 21:00','upcoming','Я','course-active'));
  add(s.c,med('Називин, 0,05%','2 капли в каждый носовой ход','По плану в 21:00','upcoming','Я','course-active','671:1999'));
  add(s.c,select('Принятые сегодня',mode==='missed'?'3 приёма':'4 приёма','history'));
 }
 finish(s);return s;
}
await daily('today','Лечение / Сегодня');
await daily('today-unmarked','Лечение / Сегодня — нет отметки','missed');
await daily('today-done','Лечение / Сегодня — всё отмечено','done');
const courses=await screen('courses','Лечение / Курсы','Лечение',true);add(courses.c,segment(true));add(courses.c,people());
heading(courses.c,'Активные · 3');
for(const [title,sub,day,count,drugs,warn,to] of [
 ['Простуда','Я · 25 октября — 3 ноября','День 5 из 10','13 принято · 1 пропуск','Ибупрофен · 3 раза в день\nНазивин · 2 раза в день','Нужно пополнить запас','course-active'],
 ['Витамин D','Я · приём циклами','Приём · день 24 из 60','','Витамин D3 · 1 капсула утром','Перерыв начнётся 5 декабря','cycle-break'],
 ['Давление','Мама · без даты окончания','Ближайший · завтра, 09:00','','Лозартан · 1 таблетка утром','Запаса осталось на 5 дней','course-paused']
]){const comp=await figma.getNodeByIdAsync('722:3292');const n=register(comp.createInstance());n.setProperties({'Название#722:29':title,'Подзаголовок#722:30':sub,'День#722:31':day,'Принято#722:32':count,'Препараты#722:33':drugs,'Предупреждение#722:34':warn,'Показать предупреждение#722:35':true});n.resize(358,n.height);if(title!=='Простуда'){const p=n.children.find(n=>n.name==='progress');if(p)p.visible=false;}add(courses.c,n);go(n,to);}
add(courses.c,select('На паузе','1 курс','course-paused'));add(courses.c,L('Завершённые курсы','courses-completed'));finish(courses);
const empty=await screen('empty','Лечение / Первый курс','Лечение',true);const ec=V('Первый курс',358,16,16,'card');
const old=await figma.getNodeByIdAsync('723:3240');const image=old.findAll(n=>'fills'in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE'))[0];if(image){const cp=register(image.clone());cp.resize(220,190);ec.appendChild(cp);ec.counterAxisAlignItems='CENTER';}
add(ec,T('Добавьте первый курс','h2','ink',326));add(ec,T('Сохраните назначение, настройте расписание и отмечайте приёмы. Запас можно добавить позже.','body','muted',326));add(ec,B('Добавить курс','course-basic',false,326));add(empty.c,ec);finish(empty);
const completeList=await screen('courses-completed','Лечение / Завершённые курсы','Завершённые курсы');add(completeList.c,card('Активных курсов нет','История и назначения сохранены. Можно создать новый курс.','Добавить курс','course-basic'));heading(completeList.c,'Завершённые');add(completeList.c,card('Простуда','Я · 25 октября — 3 ноября\n28 приёмов отмечены как принятые · 2 пропуска','Открыть историю курса','course-complete'));finish(completeList);
let nextY=group('01 · Каждый день',['today','today-unmarked','today-done','courses','empty','courses-completed'],100);
await daily('today-mom','Лечение / Сегодня — мама','normal','Мама');
const noDay=await screen('day-empty','Лечение / Другой день — без приёмов','Лечение',true);add(noDay.c,segment());add(noDay.c,people('Миша'));heading(noDay.c,'Пятница, 30 октября','Сегодня','today');add(noDay.c,banner('На этот день приёмов нет','Ближайший приём — 2 ноября в 08:00.','','','info'));add(noDay.c,B('Вернуться к сегодня','today'));add(noDay.c,L('Посмотреть курсы Миши','courses'));finish(noDay);
const cal=await screen('calendar','Лечение / Календарь','Календарь приёмов');add(cal.c,people());heading(cal.c,'Октябрь 2026');
for(const row of [['Пн','Вт','Ср','Чт','Пт','Сб','Вс'],['26','27','28','29','30','31','1']]){const h=H('Неделя',358,7);for(const d of row){const cell=V('День '+d,44,4,8,d==='29'?'blue':'card');const text=T(d,'label',d==='29'?'white':'ink',28);add(cell,text);go(cell,d==='29'?'today':'day-empty');h.appendChild(cell);}add(cal.c,h);}
add(cal.c,T('29 октября · 7 приёмов','large'));add(cal.c,T('Принято: 4 · ещё предстоит: 3','body','muted'));add(cal.c,B('Открыть выбранный день','today'));add(cal.c,L('Вернуться к сегодня','today'));finish(cal);
nextY=group('02 · Люди и календарь',['today-mom','calendar','day-empty'],nextY);
return result({nextY,phase:'daily',screenBounds:Object.entries(screens).map(([key,s])=>{const n=made.find(n=>n.id===s.id);return {key,id:s.id,w:n.width,h:n.height,x:n.x,y:n.y};})});

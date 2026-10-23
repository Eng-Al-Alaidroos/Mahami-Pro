import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.db;
  runApp(const MahamiApp());
}

class MahamiApp extends StatelessWidget {
  const MahamiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'مِهامي Pro',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b63)), scaffoldBackgroundColor: const Color(0xfff5f7f8)),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: const HomePage(),
  );
}

class Task {
  final int? id;
  final String title, notes, department, priority, status;
  final DateTime? due;
  Task({this.id, required this.title, this.notes='', this.department='', this.priority='متوسطة', this.status='جديدة', this.due});
  Map<String,Object?> map() => {'title':title,'notes':notes,'department':department,'priority':priority,'status':status,'due':due?.toIso8601String()};
  factory Task.from(Map<String,Object?> m) => Task(id:m['id'] as int,title:m['title'] as String,notes:m['notes'] as String? ?? '',department:m['department'] as String? ?? '',priority:m['priority'] as String? ?? 'متوسطة',status:m['status'] as String? ?? 'جديدة',due:m['due']==null?null:DateTime.tryParse(m['due'] as String));
}

class Store {
  static Database? _db;
  static Future<Database> get db async => _db ??= await openDatabase(p.join(await getDatabasesPath(),'mahamipro.db'),version:1,onCreate:(db,v)=>db.execute("CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,notes TEXT NOT NULL,department TEXT NOT NULL,priority TEXT NOT NULL,status TEXT NOT NULL,due TEXT)"));
  static Future<List<Task>> all() async => (await (await db).query('tasks',orderBy:'id DESC')).map(Task.from).toList();
  static Future<void> save(Task t) async { final d=await db; if(t.id==null){await d.insert('tasks',t.map());}else{await d.update('tasks',t.map(),where:'id=?',whereArgs:[t.id]);} }
  static Future<void> delete(int id) async => (await db).delete('tasks',where:'id=?',whereArgs:[id]);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Task> tasks=[]; String search='',filter='الكل'; bool loading=true;
  @override void initState(){super.initState();refresh();}
  Future<void> refresh() async {final t=await Store.all();if(mounted)setState((){tasks=t;loading=false;});}
  List<Task> get shown=>tasks.where((t)=>(('${t.title} ${t.notes} ${t.department}').contains(search))&&(filter=='الكل'||(filter=='المفتوحة'?t.status!='منجزة':t.status==filter))).toList();
  Future<void> edit([Task? task]) async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>Editor(task:task)));await refresh();}
  @override Widget build(BuildContext context){
    final open=tasks.where((t)=>t.status!='منجزة').length;
    return Scaffold(
      appBar: AppBar(title: const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('مِهامي Pro',style:TextStyle(fontWeight:FontWeight.bold)),Text('منظّم أعمالك اليومية',style:TextStyle(fontSize:12))])),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('مهمة جديدة')),
      body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,90),children:[
        Row(children:[Expanded(child:metric('كل المهام',tasks.length,Icons.assignment)),const SizedBox(width:8),Expanded(child:metric('مفتوحة',open,Icons.pending_actions)),const SizedBox(width:8),Expanded(child:metric('منجزة',tasks.length-open,Icons.task_alt))]),
        const SizedBox(height:14),
        TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث عن مهمة أو إدارة')),
        const SizedBox(height:10),
        Wrap(spacing:6,children:['الكل','المفتوحة','جديدة','قيد التنفيذ','بانتظار التأكيد','منجزة'].map((s)=>ChoiceChip(label:Text(s),selected:filter==s,onSelected:(_)=>setState(()=>filter=s))).toList()),
        if(shown.isEmpty) Padding(padding:const EdgeInsets.all(40),child:Center(child:Text(tasks.isEmpty?'أضف أول مهمة لتبدأ':'لا توجد نتائج مطابقة'))),
        ...shown.map((t)=>Card(elevation:0,color:Colors.white,child:ListTile(
          leading:IconButton(icon:Icon(t.status=='منجزة'?Icons.check_circle:Icons.radio_button_unchecked,color:t.status=='منجزة'?Colors.green:null),onPressed:()async{await Store.save(Task(id:t.id,title:t.title,notes:t.notes,department:t.department,priority:t.priority,status:t.status=='منجزة'?'قيد التنفيذ':'منجزة',due:t.due));await refresh();}),
          title:Text(t.title,style:TextStyle(fontWeight:FontWeight.bold,decoration:t.status=='منجزة'?TextDecoration.lineThrough:null)),
          subtitle:Text([if(t.department.isNotEmpty)t.department,t.priority,t.status,if(t.due!=null)date(t.due!)].join(' • ')),
          onTap:()=>edit(t),
          trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit'){edit(t);}else{await Store.delete(t.id!);await refresh();}},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'delete',child:Text('حذف'))]),
        ))),
      ])),
    );
  }
  Widget metric(String label,int count,IconData icon)=>Card(elevation:0,color:Colors.white,child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Icon(icon,color:Theme.of(context).colorScheme.primary),Text('$count',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(fontSize:12))])));
}

class Editor extends StatefulWidget {
  final Task? task; const Editor({super.key,this.task});
  @override State<Editor> createState()=>_EditorState();
}
class _EditorState extends State<Editor>{
  final form=GlobalKey<FormState>();late final TextEditingController title,notes,department;
  late String priority,status;DateTime? due;bool saving=false;
  @override void initState(){super.initState();final t=widget.task;title=TextEditingController(text:t?.title??'');notes=TextEditingController(text:t?.notes??'');department=TextEditingController(text:t?.department??'');priority=t?.priority??'متوسطة';status=t?.status??'جديدة';due=t?.due;}
  @override void dispose(){title.dispose();notes.dispose();department.dispose();super.dispose();}
  Future<void> pickDate()async{final n=DateTime.now();final d=await showDatePicker(context:context,initialDate:due??n,firstDate:DateTime(n.year-5),lastDate:DateTime(n.year+15),helpText:'اختر الموعد النهائي',cancelText:'إلغاء',confirmText:'اختيار');if(d!=null)setState(()=>due=d);}
  Future<void> save()async{if(!form.currentState!.validate())return;setState(()=>saving=true);await Store.save(Task(id:widget.task?.id,title:title.text.trim(),notes:notes.text.trim(),department:department.text.trim(),priority:priority,status:status,due:due));if(mounted)Navigator.pop(context);}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.task==null?'إضافة مهمة':'تعديل المهمة')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
    TextFormField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'عنوان المهمة *'),validator:(v)=>v==null||v.trim().isEmpty?'اكتب عنوان المهمة':null),
    const SizedBox(height:12),TextFormField(controller:notes,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'التفاصيل والملاحظات')),
    const SizedBox(height:12),TextFormField(controller:department,decoration:const InputDecoration(labelText:'الإدارة المستفيدة (اختياري)')),
    const SizedBox(height:12),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:['عالية','متوسطة','منخفضة'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>priority=v??priority)),
    const SizedBox(height:12),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'حالة المهمة'),items:['جديدة','قيد التنفيذ','بانتظار التأكيد','منجزة'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>status=v??status)),
    const SizedBox(height:12),Card(elevation:0,color:Colors.white,child:ListTile(leading:const Icon(Icons.calendar_month),title:const Text('الموعد النهائي'),subtitle:Text(due==null?'لم يحدد':date(due!)),onTap:pickDate,trailing:IconButton(icon:const Icon(Icons.edit_calendar),onPressed:pickDate))),
    const SizedBox(height:20),FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'جارٍ الحفظ':'حفظ المهمة')),
    const SizedBox(height:10),const Text('تُحفظ المهام على هذا الجهاز باستخدام SQLite.',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
  ])));
}
String date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

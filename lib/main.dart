
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseApp());
}

const purple = Color(0xFF8B7CFF);
const bg = Color(0xFF10111A);
const panel = Color(0xFF1B1D2A);
const green = Color(0xFF45D6A0);
const red = Color(0xFFFF7185);

String fa(String s) {
  const en = '0123456789';
  const pe = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(en[i], pe[i]);
  }
  return s;
}

String money(int n) {
  final raw = n.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
    out.write(raw[i]);
  }
  return '${fa(out.toString())} تومان';
}

class Entry {
  final String id, title, category, type, date;
  final int amount;
  Entry({required this.id, required this.title, required this.category,
    required this.type, required this.amount, required this.date});
  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'category': category, 'type': type,
    'amount': amount, 'date': date,
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'], title: j['title'], category: j['category'],
    type: j['type'], amount: j['amount'], date: j['date']);
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'مدیریت هزینه',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor: bg, centerTitle: true),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    ),
    home: const Directionality(textDirection: TextDirection.rtl, child: MainPage()),
  );
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int tab = 0;
  List<Entry> entries = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('entries') ?? '[]';
    final list = (jsonDecode(raw) as List).map((e) => Entry.fromJson(e)).toList();
    if (mounted) setState(() { entries = list; loading = false; });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  int get income => entries.where((e) => e.type == 'درآمد').fold(0, (s, e) => s + e.amount);
  int get expense => entries.where((e) => e.type == 'هزینه').fold(0, (s, e) => s + e.amount);
  int get balance => income - expense;

  Future<void> addEntry() async {
    final result = await showModalBottomSheet<Entry>(
      context: context, isScrollControlled: true, backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const AddEntrySheet(),
    );
    if (result != null) {
      setState(() => entries.insert(0, result));
      await save();
    }
  }

  Future<void> remove(Entry e) async {
    setState(() => entries.removeWhere((x) => x.id == e.id));
    await save();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(entries: entries, income: income, expense: expense, balance: balance,
        onAdd: addEntry, onDelete: remove),
      TransactionsPage(entries: entries, onDelete: remove),
      ReportsPage(entries: entries, income: income, expense: expense),
      SettingsPage(onReset: () async {
        setState(() => entries.clear()); await save();
      }),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت هزینه', style: TextStyle(fontWeight: FontWeight.bold))),
      body: loading ? const Center(child: CircularProgressIndicator()) : pages[tab],
      floatingActionButton: tab < 2 ? FloatingActionButton.extended(
        onPressed: addEntry, backgroundColor: purple, icon: const Icon(Icons.add),
        label: const Text('ثبت تراکنش')) : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'تراکنش‌ها'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'گزارش‌ها'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Entry> entries; final int income, expense, balance;
  final VoidCallback onAdd; final ValueChanged<Entry> onDelete;
  const HomePage({super.key, required this.entries, required this.income,
    required this.expense, required this.balance, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6557D9), Color(0xFF302B66)]),
        borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('موجودی کل', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        Text(money(balance), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _miniStat('درآمد', income, green, Icons.arrow_downward)),
          const SizedBox(width: 12),
          Expanded(child: _miniStat('هزینه', expense, const Color(0xFFFFB3BE), Icons.arrow_upward)),
        ])
      ]),
    ),
    const SizedBox(height: 24),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('آخرین تراکنش‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text('${fa(entries.length.toString())} مورد', style: const TextStyle(color: Colors.white54)),
    ]),
    const SizedBox(height: 10),
    if (entries.isEmpty) const EmptyState()
    else ...entries.take(5).map((e) => EntryTile(entry: e, onDelete: () => onDelete(e))),
    const SizedBox(height: 80),
  ]);

  Widget _miniStat(String label, int value, Color color, IconData icon) => Row(children: [
    CircleAvatar(backgroundColor: Colors.white.withOpacity(.15), child: Icon(icon, color: Colors.white)),
    const SizedBox(width: 9),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Text(money(value), maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]))
  ]);
}

class TransactionsPage extends StatelessWidget {
  final List<Entry> entries; final ValueChanged<Entry> onDelete;
  const TransactionsPage({super.key, required this.entries, required this.onDelete});
  @override
  Widget build(BuildContext context) => entries.isEmpty
    ? const EmptyState()
    : ListView(padding: const EdgeInsets.all(16), children: [
      Text('همه تراکنش‌ها (${fa(entries.length.toString())})',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...entries.map((e) => EntryTile(entry: e, onDelete: () => onDelete(e))),
      const SizedBox(height: 80),
    ]);
}

class EntryTile extends StatelessWidget {
  final Entry entry; final VoidCallback onDelete;
  const EntryTile({super.key, required this.entry, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == 'درآمد';
    return Card(color: panel, margin: const EdgeInsets.only(bottom: 9), child: ListTile(
      leading: CircleAvatar(backgroundColor: (isIncome ? green : red).withOpacity(.15),
        child: Icon(isIncome ? Icons.south_west : Icons.north_east, color: isIncome ? green : red)),
      title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${entry.category} • ${fa(entry.date)}', style: const TextStyle(color: Colors.white54)),
      trailing: SizedBox(width: 112, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Expanded(child: Text('${isIncome ? '+' : '-'}${money(entry.amount)}',
          textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: isIncome ? green : red, fontWeight: FontWeight.bold))),
        PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 20), onSelected: (_) => onDelete(),
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف تراکنش'))]),
      ])),
    ));
  }
}

class ReportsPage extends StatelessWidget {
  final List<Entry> entries; final int income, expense;
  const ReportsPage({super.key, required this.entries, required this.income, required this.expense});
  @override
  Widget build(BuildContext context) {
    final categories = <String, int>{};
    for (final e in entries.where((e) => e.type == 'هزینه')) {
      categories[e.category] = (categories[e.category] ?? 0) + e.amount;
    }
    final sorted = categories.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('گزارش مالی', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _reportCard('مجموع درآمد', income, green),
      _reportCard('مجموع هزینه', expense, red),
      _reportCard('مانده', income - expense, purple),
      const SizedBox(height: 18),
      const Text('هزینه بر اساس دسته‌بندی', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (sorted.isEmpty) const EmptyState(message: 'هنوز هزینه‌ای ثبت نشده است')
      else ...sorted.map((e) {
        final ratio = expense == 0 ? 0.0 : (e.value / expense).clamp(0.0, 1.0);
        return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.key), Text(money(e.value), style: const TextStyle(color: Colors.white70)),
          ]),
          const SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
            value: ratio, minHeight: 9, backgroundColor: panel, color: purple)),
        ]));
      }),
    ]);
  }
  Widget _reportCard(String title, int amount, Color color) => Card(color: panel,
    margin: const EdgeInsets.only(bottom: 9), child: ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      trailing: Text(money(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold))));
}

class SettingsPage extends StatelessWidget {
  final Future<void> Function() onReset;
  const SettingsPage({super.key, required this.onReset});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const CircleAvatar(radius: 38, backgroundColor: panel, child: Icon(Icons.account_balance_wallet, size: 38, color: purple)),
    const SizedBox(height: 12),
    const Center(child: Text('مدیریت هزینه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    const Center(child: Text('نسخه ۱.۰.۰', style: TextStyle(color: Colors.white54))),
    const SizedBox(height: 25),
    Card(color: panel, child: const ListTile(leading: Icon(Icons.payments_outlined, color: purple),
      title: Text('واحد پول'), trailing: Text('تومان'))),
    Card(color: panel, child: const ListTile(leading: Icon(Icons.storage_outlined, color: purple),
      title: Text('محل ذخیره‌سازی'), subtitle: Text('حافظه داخلی دستگاه'))),
    const SizedBox(height: 18),
    OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('پاک کردن اطلاعات؟'),
          content: const Text('تمام تراکنش‌های ذخیره‌شده حذف می‌شوند.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف همه')),
          ],
        ));
        if (ok == true) { await onReset(); }
      },
      icon: const Icon(Icons.delete_outline), label: const Text('پاک کردن تمام اطلاعات'),
      style: OutlinedButton.styleFrom(foregroundColor: red)),
  ]);
}

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key});
  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final title = TextEditingController();
  final amount = TextEditingController();
  String type = 'هزینه';
  String category = 'خوراک';
  final expenseCats = ['خوراک', 'حمل‌ونقل', 'خرید', 'قبوض', 'درمان', 'تفریح', 'آموزش', 'سایر'];
  final incomeCats = ['حقوق', 'هدیه', 'فروش', 'سایر'];

  @override
  Widget build(BuildContext context) {
    final cats = type == 'هزینه' ? expenseCats : incomeCats;
    if (!cats.contains(category)) category = cats.first;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ثبت تراکنش جدید', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'هزینه', label: Text('هزینه'), icon: Icon(Icons.arrow_upward)),
          ButtonSegment(value: 'درآمد', label: Text('درآمد'), icon: Icon(Icons.arrow_downward)),
        ], selected: {type}, onSelectionChanged: (s) => setState(() { type = s.first; category = type == 'هزینه' ? expenseCats.first : incomeCats.first; })),
        const SizedBox(height: 14),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان تراکنش', hintText: 'مثلاً خرید روزانه')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'مبلغ (تومان)', hintText: 'مثلاً ۱۵۰۰۰۰')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'دسته‌بندی'),
          items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => category = v ?? cats.first)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: purple, padding: const EdgeInsets.all(15)),
          onPressed: () {
            final clean = amount.text.replaceAll(',', '').replaceAll('٬', '').replaceAll('۰','0').replaceAll('۱','1')
              .replaceAll('۲','2').replaceAll('۳','3').replaceAll('۴','4').replaceAll('۵','5')
              .replaceAll('۶','6').replaceAll('۷','7').replaceAll('۸','8').replaceAll('۹','9');
            final value = int.tryParse(clean);
            if (title.text.trim().isEmpty || value == null || value <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عنوان و مبلغ معتبر را وارد کنید')));
              return;
            }
            final now = DateTime.now();
            final date = '${now.year}/${now.month.toString().padLeft(2,'0')}/${now.day.toString().padLeft(2,'0')}';
            Navigator.pop(context, Entry(id: DateTime.now().microsecondsSinceEpoch.toString(),
              title: title.text.trim(), category: category, type: type, amount: value, date: date));
          },
          child: const Text('ذخیره تراکنش')),
      ])),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, this.message = 'هنوز تراکنشی ثبت نشده است'});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 50),
    child: Column(children: [
      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white.withOpacity(.35)),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: Colors.white54)),
      const SizedBox(height: 5),
      const Text('برای شروع، یک تراکنش جدید ثبت کنید.', style: TextStyle(color: Colors.white38, fontSize: 12)),
    ]));
}

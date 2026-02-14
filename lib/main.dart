import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const MiGestorApp());
}

class MiGestorApp extends StatelessWidget {
  const MiGestorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  DateTime fechaSeleccionada = DateTime.now();
  String diaDeLaSemana = "";
  final TextEditingController _tareaController = TextEditingController();
  int horas = 0;
  int minutos = 0;
  Database? _database;
  List<Map<String, dynamic>> _registrosDelDia = [];

  @override
  void initState() {
    super.initState();
    actualizarDia(fechaSeleccionada);
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    _database = await openDatabase(
      p.join(await getDatabasesPath(), 'gestor_tiempo.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE registros(id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, concepto TEXT, horas INTEGER, minutos INTEGER)',
        );
      },
      version: 1,
    );
    await _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    final db = _database;
    if (db == null) return;
    final String fechaStr = DateFormat('yyyy-MM-dd').format(fechaSeleccionada);
    final List<Map<String, dynamic>> res = await db.query(
      'registros',
      where: 'fecha = ?',
      whereArgs: [fechaStr],
    );
    if (!mounted) return;
    setState(() {
      _registrosDelDia = res;
    });
  }

  Future<void> _guardarEnBD() async {
    final db = _database;
    if (_tareaController.text.isEmpty || db == null) return;
    await db.insert('registros', {
      'fecha': DateFormat('yyyy-MM-dd').format(fechaSeleccionada),
      'concepto': _tareaController.text,
      'horas': horas,
      'minutos': minutos,
    });
    _tareaController.clear();
    if (!mounted) return;
    setState(() {
      horas = 0;
      minutos = 0;
    });
    await _cargarRegistros();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  void actualizarDia(DateTime fecha) {
    setState(() {
      fechaSeleccionada = fecha;
      diaDeLaSemana = DateFormat('EEEE', 'es').format(fecha).toUpperCase();
    });
    _cargarRegistros();
  }

  String _formatearTiempo(int totalMins) {
    return "${totalMins ~/ 60}h ${totalMins % 60}min";
  }

  void _confirmarBorrado(int? id, {String? fecha}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿BORRAR?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("NO"),
          ),
          TextButton(
            onPressed: () async {
              final db = _database;
              if (db != null) {
                if (id != null) {
                  await db.delete(
                    'registros',
                    where: 'id = ?',
                    whereArgs: [id],
                  );
                } else if (fecha != null) {
                  await db.delete(
                    'registros',
                    where: 'fecha = ?',
                    whereArgs: [fecha],
                  );
                }
              }
              await _cargarRegistros();
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("SÍ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarInforme(String tipo) async {
    final db = _database;
    if (db == null) return;
    DateTime inicio = (tipo == 'semana')
        ? fechaSeleccionada.subtract(
            Duration(days: fechaSeleccionada.weekday - 1),
          )
        : DateTime(fechaSeleccionada.year, fechaSeleccionada.month, 1);
    DateTime fin = (tipo == 'semana')
        ? inicio.add(const Duration(days: 6))
        : DateTime(fechaSeleccionada.year, fechaSeleccionada.month + 1, 0);

    final List<Map<String, dynamic>> res = await db.query(
      'registros',
      where: 'fecha BETWEEN ? AND ?',
      whereArgs: [
        DateFormat('yyyy-MM-dd').format(inicio),
        DateFormat('yyyy-MM-dd').format(fin),
      ],
      orderBy: 'fecha ASC',
    );

    Map<String, Map<String, dynamic>> agrupado = {};
    int totalGlobalMins = 0;
    for (var r in res) {
      String fReal = r['fecha'];
      DateTime d = DateTime.parse(fReal);
      String clave = (tipo == 'semana')
          ? "${DateFormat('EEEE', 'es').format(d)} ${d.day}/${d.month}"
          : "Semana ${((d.day - 1) ~/ 7) + 1}";
      int mins = (r['horas'] as int) * 60 + (r['minutos'] as int);
      if (!agrupado.containsKey(clave)) {
        agrupado[clave] = {'mins': 0, 'fecha': fReal};
      }
      agrupado[clave]!['mins'] += mins;
      totalGlobalMins += mins;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tipo == 'semana' ? "DETALLE SEMANAL" : "DETALLE MENSUAL"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...agrupado.entries.map(
                  (e) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatearTiempo(e.value['mins']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_sweep,
                              color: Colors.red,
                              size: 18,
                            ),
                            onPressed: () => _confirmarBorrado(
                              null,
                              fecha: e.value['fecha'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.blue),
                Text(
                  "TOTAL: ${_formatearTiempo(totalGlobalMins)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CERRAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalMinsDia = 0;
    for (var r in _registrosDelDia) {
      totalMinsDia += (r['horas'] as int) * 60 + (r['minutos'] as int);
    }
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(diaDeLaSemana, style: const TextStyle(color: Colors.grey)),
              Text(
                "${fechaSeleccionada.day}/${fechaSeleccionada.month}/${fechaSeleccionada.year}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final DateTime? p = await showDatePicker(
                    context: context,
                    initialDate: fechaSeleccionada,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale('es'),
                  );
                  if (p != null && mounted) {
                    actualizarDia(p);
                  }
                },
                child: const Text("CAMBIAR FECHA"),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _tareaController,
                      decoration: const InputDecoration(labelText: "CONCEPTO"),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<int>(
                          value: horas,
                          items: List.generate(
                            24,
                            (i) =>
                                DropdownMenuItem(value: i, child: Text("$i h")),
                          ),
                          onChanged: (v) => setState(() => horas = v!),
                        ),
                        const SizedBox(width: 15),
                        DropdownButton<int>(
                          value: minutos,
                          items: List.generate(
                            60,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text("$i min"),
                            ),
                          ),
                          onChanged: (v) => setState(() => minutos = v!),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                            size: 40,
                          ),
                          onPressed: _guardarEnBD,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Text(
                "TOTAL DÍA: ${_formatearTiempo(totalMinsDia)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _registrosDelDia.length,
                itemBuilder: (c, i) {
                  final r = _registrosDelDia[i];
                  return ListTile(
                    title: Text(r['concepto']),
                    subtitle: Text("${r['horas']}h ${r['minutos']}min"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarBorrado(r['id']),
                    ),
                  );
                },
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        onPressed: () => _mostrarInforme('semana'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("SEMANA"),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        onPressed: () => _mostrarInforme('mes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("MES"),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "© 2026 Jaume",
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

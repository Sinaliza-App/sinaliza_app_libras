import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database/database_init.dart';
import 'services/sign_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize database
  final dbInit = DatabaseInit();
  await dbInit.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinaliza App - Libras',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Sinaliza App - Libras'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SignService _signService = SignService();
  final UserService _userService = UserService();
  
  List<dynamic> _signs = [];
  List<dynamic> _users = [];
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Carregando dados...';
    });

    try {
      final signs = await _signService.getAllSigns();
      final users = await _userService.getAllUsers();
      
      setState(() {
        _signs = signs;
        _users = users;
        _statusMessage = 'Dados carregados com sucesso!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao carregar dados: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testando conexão...';
    });

    try {
      final dbInit = DatabaseInit();
      final isConnected = await dbInit.testConnection();
      
      setState(() {
        _statusMessage = isConnected 
            ? '✅ Conexão com MySQL estabelecida com sucesso!'
            : '❌ Falha na conexão com MySQL';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Erro no teste de conexão: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Recarregar dados',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusMessage.contains('✅') 
                          ? Colors.green.shade100 
                          : _statusMessage.contains('❌')
                              ? Colors.red.shade100
                              : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('✅') 
                            ? Colors.green.shade800 
                            : _statusMessage.contains('❌')
                                ? Colors.red.shade800
                                : Colors.blue.shade800,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Database info
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.gesture, size: 40, color: Colors.blue),
                                const SizedBox(height: 8),
                                Text(
                                  '${_signs.length}',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const Text('Sinais de Libras'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.people, size: 40, color: Colors.green),
                                const SizedBox(height: 8),
                                Text(
                                  '${_users.length}',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const Text('Usuários'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Signs list
                  if (_signs.isNotEmpty) ...[
                    Text(
                      'Sinais de Libras',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _signs.length,
                        itemBuilder: (context, index) {
                          final sign = _signs[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.gesture),
                              title: Text(sign.word),
                              subtitle: Text('${sign.description} - ${sign.category}'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _testConnection,
            tooltip: 'Testar Conexão',
            child: const Icon(Icons.wifi),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _loadData,
            tooltip: 'Recarregar',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
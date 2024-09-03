import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final String baseUrl = "https://apigo.rocketgestor.com/";
  final TextEditingController _numbersController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();
  String? _sessaoKey;
  List<String> _options = [];
  bool _includeServer = false;
  int _totalNumbers = 0;
  int _totalNumbersFiltrados = 0;
  bool _isLoading = false;
  bool _isApiOnline = false;
  bool _isLoadingApi = false;
  bool _isLoadingSessions = false;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
    _checkStatusApi();
    _numbersController.addListener(_updateTotalNumbers);
  }

  void _updateTotalNumbers() {
    setState(() {
      _totalNumbers = _numbersController.text
          .split('\n')
          .where((number) => number.trim().isNotEmpty)
          .length;
    });
  }

  Future<void> _fetchOptions() async {
    setState(() {
      _isLoadingSessions = true;
    });
    final url = Uri.parse('${baseUrl}instance/list');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _options = data.map((session) => session['key'].toString()).toList();
          _isLoadingSessions = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao buscar opções')),
          );

          setState(() {
            _isLoadingSessions = false;
          });
        }
        throw Exception('Falha ao buscar opções');
      }
    } catch (e) {
      var err = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao buscar opções $err')));
      }
      setState(() {
        _options = [];
        _isLoadingSessions = false;
      });
    }
  }

  void _makeRequest() async {
    String numbersText = _numbersController.text;
    if (numbersText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha pelo menos um numero!')));
      return;
    } else {
      setState(() {
        _isLoading = true;
      });

      List<String> numbersList = numbersText
          .split('\n')
          .map((number) => number.trim())
          .where((number) => number.isNotEmpty)
          .toList();

      String serverParam = _includeServer ? 'true' : 'false';

      if (_sessaoKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecione pelo menos uma sessão!')));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
          '${baseUrl}misc/onwhatsapplist?key=$_sessaoKey&server=$serverParam');

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({'numbers': numbersList}),
        );

        if (response.statusCode == 200) {
          List<dynamic> responseData = json.decode(response.body);
          String formattedResult =
              responseData.map((item) => item.toString()).join('\n');

          setState(() {
            _totalNumbersFiltrados = responseData.length;
            _resultController.text = formattedResult;
          });
        } else {
          var statusCode = response.statusCode.toString();
          var body = response.body.toString();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Houve um erro ao fazer a consulta: $statusCode - $body')));
          }
          throw Exception('Falha ao filtrar números');
        }
      } catch (e) {
        var err = e.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Houve um erro ao fazer a consulta: $err')));
        }
        setState(() {
          _resultController.text = 'Erro ao filtrar números';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    ClipboardData? data = await Clipboard.getData('text/plain');
    if (data != null) {
      setState(() {
        _numbersController.text = data.text!;
      });
    }
  }

  void _clearFields() {
    setState(() {
      _numbersController.clear();
      _resultController.clear();
      _totalNumbers = 0;
    });
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _resultController.text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Resultado copiado!')));
  }

  Future<bool> _checkStatusApi() async {
    setState(() {
      _isLoadingApi = true;
    });
    final url = Uri.parse('${baseUrl}status');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _isApiOnline = true;
          _isLoadingApi = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Api Online!')));
        }
        return true;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Api Offline!')));
        }
        setState(() {
          _isApiOnline = false;
          _isLoadingApi = false;
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _isApiOnline = false;
        _isLoadingApi = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao verificar status da api!')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(
            'Check On Whatsapp',
            style: TextStyle(color: Colors.white), // Define a cor branca
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0000B1), // Azul
                  Color(0xFF6900A9), // Roxo
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: _isLoadingApi
                  ? const CircularProgressIndicator()
                  : _isApiOnline
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                      : const Icon(Icons.error, color: Colors.red),
              onPressed: _checkStatusApi,
              tooltip: 'Status da API',
            ),
          ]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _sessaoKey,
              hint: _isLoadingSessions
                  ? const Text('Carregando...')
                  : const Text('Selecione uma sessão'),
              items: _options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _sessaoKey = newValue;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: _includeServer,
                  onChanged: (bool value) {
                    setState(() {
                      _includeServer = value;
                    });
                  },
                ),
                const Text('Incluir server?'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Colar',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Total de Números: $_totalNumbers'),
            const SizedBox(height: 8),
            TextField(
              controller: _numbersController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Insira os números (um por linha)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: _isLoading ? null : _makeRequest,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                            semanticsLabel: 'Carregando...',
                            backgroundColor: Colors.green,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text('Filtrar Números'))
              ],
            ),
            const SizedBox(height: 16),
            Text('Total de Números: $_totalNumbersFiltrados'),
            const SizedBox(height: 16),
            TextField(
              controller: _resultController,
              maxLines: 8,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Resultado',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _copyResult,
                  child: const Text('Copiar Resultado'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _clearFields,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Limpar Campos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  String _currentPath = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final path = await _storage.getBaseDownloadPath();
    if (mounted) setState(() => _currentPath = path);
  }

  void _changePath() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final config = await _storage.loadConfig();
      config['download_path'] = result;
      await _storage.saveConfig(config);
      if (mounted) setState(() => _currentPath = result);
    }
  }

  // Abre um alerta para confirmar a exclusão em massa
  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Apagar TODOS os downloads?"),
        content: const Text(
          "Esta ação não pode ser desfeita. Todos os mangás salvos no seu dispositivo serão removidos.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Fecha o diálogo
              await _storage.deleteAllDownloads(); // Agora o método existe!
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Limpeza concluída com sucesso!")),
                );
              }
            },
            child: const Text("Confirmar e Apagar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "ARMANZENAMENTO",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text("Local de Download"),
            subtitle: Text(_currentPath),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: _changePath,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "ZONA DE PERIGO",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text("Limpar armazenamento local"),
            subtitle: const Text("Exclui permanentemente todos os capítulos baixados"),
            onTap: _confirmDeleteAll,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "SOBRE",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Versão do App"),
            subtitle: Text("2.1.0 - Estável"),
          ),
        ],
      ),
    );
  }
}
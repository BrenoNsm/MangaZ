import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'manga_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  
  List allFavs = [];
  List filteredFavs = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Atualiza a lista de favoritos (Prioriza API, mas funciona Offline)
  Future<void> _refresh() async {
    setState(() => isLoading = true);
    final config = await _storage.loadConfig();
    final List savedFavs = config['favoritos'] ?? [];

    try {
      if (savedFavs.isNotEmpty) {
        // Tenta buscar dados novos na API para atualizar capas e títulos
        String idsQuery = "?${savedFavs.map((m) => "ids[]=${m['id']}").join("&")}";
        final results = await _api.searchMangas(idsQuery);
        allFavs = results;
      } else {
        allFavs = [];
      }
    } catch (e) {
      // MODO OFFLINE: Usa os dados salvos no JSON local
      allFavs = savedFavs.map((m) => {
        "id": m['id'],
        "attributes": {
          "title": {"en": m['title'] ?? "Manga Offline"}
        },
        "relationships": [] 
      }).toList();
      
      if (mounted && allFavs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modo Offline: Carregando banco local."))
        );
      }
    }

    if (mounted) {
      setState(() {
        filteredFavs = allFavs;
        isLoading = false;
      });
    }
  }

  String _getBestTitle(Map attr) {
    return attr['title']['pt-br'] ?? 
           attr['title']['en'] ?? 
           attr['title'].values.first.toString();
  }

  String _getCover(dynamic m) {
    try {
      final rel = m['relationships'].firstWhere((r) => r['type'] == 'cover_art');
      return "https://uploads.mangadex.org/covers/${m['id']}/${rel['attributes']['fileName']}";
    } catch (_) {
      return "";
    }
  }

  void _openDetail(dynamic m) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => MangaDetailScreen(
        mangaData: m, 
        title: _getBestTitle(m['attributes']), 
        imageUrl: _getCover(m)
      ))
    );
    _refresh(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MangaZ"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search), 
            onPressed: () async {
              final m = await showSearch(context: context, delegate: MangaSearchDelegate(_api));
              if (m != null && mounted) _openDetail(m);
            }
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // BANNER LATERAL
            Container(
              width: double.infinity,
              color: Colors.orange,
              child: Image.asset(
                'assets/images/Baner Lateral.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 150, 
                  child: Center(child: Icon(Icons.image_not_supported, size: 50))
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Configurações"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text("Importar Backup"),
                    onTap: () async {
                      Navigator.pop(context);
                      FilePickerResult? r = await FilePicker.platform.pickFiles();
                      if (r != null && r.files.single.path != null) {
                        if (await _storage.importConfig(File(r.files.single.path!)) && mounted) _refresh();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: const Text("Exportar Backup"),
                    onTap: () async {
                      Navigator.pop(context);
                      File f = await _storage.getConfigFile();
                      if (await f.exists()) await Share.shareXFiles([XFile(f.path)]);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // FILTRO DE BUSCA LOCAL
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (q) {
                setState(() {
                  filteredFavs = allFavs.where((m) => 
                    _getBestTitle(m['attributes']).toLowerCase().contains(q.toLowerCase())
                  ).toList();
                });
              },
              decoration: InputDecoration(
                hintText: "Filtrar favoritos...",
                prefixIcon: const Icon(Icons.filter_list),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          // LISTAGEM
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : filteredFavs.isEmpty
                ? const Center(child: Text("Nenhum mangá nos favoritos."))
                : ListView.builder(
                    itemCount: filteredFavs.length,
                    itemBuilder: (c, i) {
                      final manga = filteredFavs[i];
                      final coverUrl = _getCover(manga);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 50, height: 75,
                            color: Colors.grey[300],
                            child: coverUrl.isEmpty 
                              ? const Icon(Icons.book)
                              : Image.network(
                                  coverUrl, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
                                ),
                          ),
                        ),
                        title: Text(_getBestTitle(manga['attributes']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _openDetail(manga),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// DELEGATE DE BUSCA COM CAPAS CORRIGIDO
class MangaSearchDelegate extends SearchDelegate {
  final ApiService api;
  MangaSearchDelegate(this.api);

  String _getCover(dynamic m) {
    try {
      final rel = m['relationships'].firstWhere((r) => r['type'] == 'cover_art');
      return "https://uploads.mangadex.org/covers/${m['id']}/${rel['attributes']['fileName']}";
    } catch (_) { return ""; }
  }

  String _getBestTitle(Map attr) {
    return attr['title']['pt-br'] ?? attr['title']['en'] ?? attr['title'].values.first.toString();
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null)
  );

  @override
  Widget buildResults(BuildContext context) => _showResults();

  @override
  Widget buildSuggestions(BuildContext context) => _showResults();

  Widget _showResults() {
    if (query.isEmpty) return const Center(child: Text("Digite algo para pesquisar..."));

    return FutureBuilder<List>(
      future: api.searchMangas(query),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
        if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text("Nada encontrado."));

        return ListView.builder(
          itemCount: snap.data!.length,
          itemBuilder: (c, i) {
            final manga = snap.data![i];
            final cover = _getCover(manga);
            return ListTile(
              leading: Container(
                width: 40, height: 60,
                color: Colors.grey[200],
                child: cover.isNotEmpty 
                  ? Image.network(cover, fit: BoxFit.cover) 
                  : const Icon(Icons.book),
              ),
              title: Text(_getBestTitle(manga['attributes'])),
              onTap: () => close(context, manga),
            );
          },
        );
      },
    );
  }
}
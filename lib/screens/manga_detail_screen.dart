import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final dynamic mangaData;
  final String title, imageUrl;

  const MangaDetailScreen({
    super.key,
    required this.mangaData,
    required this.title,
    required this.imageUrl,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  List chapters = [];
  Map<String, dynamic> config = {"favoritos": [], "lidos": []};
  Map<String, double> downloadsInProgress = {};
  bool isLoading = true;
  String selectedLang = 'pt-br';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => isLoading = true);
    final loadedConfig = await _storage.loadConfig();
    config = loadedConfig;

    try {
      // TENTA CARREGAR PELA API
      final loadedChapters = await _api.getChapters(widget.mangaData['id'], selectedLang);
      if (mounted) {
        setState(() {
          chapters = loadedChapters;
          isLoading = false;
        });
      }
    } catch (e) {
      // MODO OFFLINE: ESCANEAR CAPÍTULOS BAIXADOS NO DISCO
      if (mounted) {
        final offlineChapters = await _getOfflineChapters();
        setState(() {
          chapters = offlineChapters;
          isLoading = false;
        });
        if (offlineChapters.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Modo Offline: Mostrando capítulos baixados."))
          );
        }
      }
    }
  }

  // NOVA FUNÇÃO: Varre as pastas para encontrar o que foi baixado
  Future<List> _getOfflineChapters() async {
    List localList = [];
    try {
      final base = await _storage.getBaseDownloadPath();
      final mangaDir = Directory("$base/${widget.mangaData['id']}");

      if (await mangaDir.exists()) {
        final List<FileSystemEntity> entities = await mangaDir.list().toList();
        for (var entity in entities) {
          if (entity is Directory) {
            // Pega o ID do capítulo pelo nome da pasta
            String chapterId = entity.path.split(Platform.pathSeparator).last;
            
            // Cria um objeto fake para o design não quebrar
            localList.add({
              "id": chapterId,
              "attributes": {
                "chapter": "Baixado", // Como não temos o número da API, marcamos como baixado
                "title": "Capítulo Offline",
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao listar capítulos offline: $e");
    }
    return localList;
  }

  Future<void> _startDownload(String mangaId, String chapterId) async {
    try {
      final pages = await _api.getChapterPages(chapterId);
      final base = await _storage.getBaseDownloadPath();
      final dir = Directory("$base/$mangaId/$chapterId");
      if (!await dir.exists()) await dir.create(recursive: true);

      for (int i = 0; i < pages.length; i++) {
        await Dio().download(pages[i], "${dir.path}/$i.jpg");
        if (mounted) {
          setState(() => downloadsInProgress[chapterId] = (i + 1) / pages.length);
        }
      }
      if (mounted) setState(() => downloadsInProgress.remove(chapterId));
    } catch (e) {
      if (mounted) {
        setState(() => downloadsInProgress.remove(chapterId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro no download: $e")));
      }
    }
  }

  void _openReader(int index) {
    if (chapters.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => MangaReaderScreen(
          mangaId: widget.mangaData['id'],
          chapterId: chapters[index]['id'],
          chapterNum: chapters[index]['attributes']['chapter'] ?? '?',
          allChapters: chapters,
          currentIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List favoritos = config['favoritos'] is List ? config['favoritos'] : [];
    final List lidos = config['lidos'] is List ? config['lidos'] : [];
    final String currentId = widget.mangaData['id'];
    bool isFav = favoritos.any((m) => m is Map && m['id'] == currentId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.red),
            onPressed: () async {
              setState(() {
                if (isFav) {
                  favoritos.removeWhere((m) => m['id'] == currentId);
                } else {
                  favoritos.add({"id": currentId, "title": widget.title});
                }
              });
              config['favoritos'] = favoritos;
              await _storage.saveConfig(config);
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.imageUrl.isNotEmpty
                            ? Image.network(
                                widget.imageUrl, 
                                width: 120, height: 180, fit: BoxFit.cover,
                                errorBuilder: (c,e,s) => Container(width: 120, height: 180, color: Colors.grey[300], child: const Icon(Icons.book)),
                              )
                            : Container(width: 120, height: 180, color: Colors.grey[300], child: const Icon(Icons.book)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                              onPressed: chapters.isEmpty ? null : () => _openReader(0),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text("Ler do Início"),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                              onPressed: chapters.isEmpty ? null : () => _openReader(chapters.length - 1),
                              icon: const Icon(Icons.last_page),
                              label: const Text("Último Lançamento"),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: "Idioma"),
                              initialValue: selectedLang,
                              items: const [
                                DropdownMenuItem(value: 'pt-br', child: Text("Português Brasil")),
                                DropdownMenuItem(value: 'en', child: Text("Inglês")),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  selectedLang = v;
                                  _load();
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: chapters.isEmpty 
                  ? const Center(child: Text("Nenhum capítulo disponível offline."))
                  : ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final c = chapters[index];
                      final id = c['id'];
                      final num = c['attributes']['chapter'] ?? '?';
                      final bool isRead = lidos.contains(id);

                      return FutureBuilder<bool>(
                        future: _storage.isDownloaded(widget.mangaData['id'], id),
                        builder: (context, snap) {
                          bool isDown = snap.data ?? false;
                          return ListTile(
                            leading: Icon(
                              isRead ? Icons.check_circle : Icons.circle_outlined,
                              color: isRead ? Colors.green : Colors.grey,
                            ),
                            title: Text("Capítulo $num"),
                            subtitle: Text(c['attributes']['title'] ?? "Sem título"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (downloadsInProgress.containsKey(id))
                                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: downloadsInProgress[id], strokeWidth: 2))
                                else
                                  IconButton(
                                    icon: Icon(
                                      isDown ? Icons.download_done : Icons.download,
                                      color: isDown ? Colors.blue : null,
                                    ),
                                    onPressed: () async {
                                      if (isDown) {
                                        await _storage.deleteChapter(widget.mangaData['id'], id);
                                      } else {
                                        await _startDownload(widget.mangaData['id'], id);
                                      }
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () async {
                              if (!isRead) {
                                setState(() { lidos.add(id); });
                                config['lidos'] = lidos;
                                await _storage.saveConfig(config);
                              }
                              _openReader(index);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
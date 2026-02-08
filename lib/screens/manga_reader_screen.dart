import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class MangaReaderScreen extends StatefulWidget {
  final String mangaId, chapterId, chapterNum;
  final List allChapters;
  final int currentIndex;

  const MangaReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.chapterNum,
    required this.allChapters,
    required this.currentIndex,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  List<String> pages = [];
  bool isLoading = true;
  bool isOffline = false;
  bool showUI = true;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  // Carrega as páginas (Prioriza arquivos locais se existirem)
  void _loadPages() async {
    setState(() => isLoading = true);
    final base = await _storage.getBaseDownloadPath();
    final dir = Directory("$base/${widget.mangaId}/${widget.chapterId}");

    if (await dir.exists()) {
      // MODO OFFLINE: Lê arquivos da pasta
      final files = dir.listSync().map((f) => f.path).toList()..sort();
      if (mounted) {
        setState(() {
          pages = files;
          isOffline = true;
          isLoading = false;
        });
      }
    } else {
      // MODO ONLINE: Busca na API
      try {
        final urls = await _api.getChapterPages(widget.chapterId);
        if (mounted) {
          setState(() {
            pages = urls;
            isOffline = false;
            isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao carregar páginas online."))
          );
        }
      }
    }
  }

  // Navegação entre capítulos
  void _jumpToChapter(int index) {
    if (index < 0 || index >= widget.allChapters.length || !mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) => MangaReaderScreen(
          mangaId: widget.mangaId,
          chapterId: widget.allChapters[index]['id'],
          chapterNum: widget.allChapters[index]['attributes']['chapter'] ?? '?',
          allChapters: widget.allChapters,
          currentIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Área das Imagens
          GestureDetector(
            onTap: () => setState(() => showUI = !showUI),
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : pages.isEmpty
                    ? const Center(child: Text("Nenhuma página encontrada", style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          return isOffline
                              ? Image.file(File(pages[index]), fit: BoxFit.contain)
                              : Image.network(
                                  pages[index], 
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const SizedBox(
                                    height: 200,
                                    child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                                  ),
                                );
                        },
                      ),
          ),

          // Interface Superior (AppBar customizada)
          if (showUI)
            Positioned(
              top: 0, left: 0, right: 0,
              child: AppBar(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: const Color(0xFF1A1A1A), // Cor preta corrigida
                    value: widget.currentIndex,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                    items: List.generate(widget.allChapters.length, (i) {
                      final c = widget.allChapters[i];
                      return DropdownMenuItem(
                        value: i,
                        child: Text(
                          "Cap. ${c['attributes']['chapter'] ?? '?'}",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) _jumpToChapter(val);
                    },
                  ),
                ),
                actions: [
                  // Botão Anterior
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: widget.currentIndex > 0 
                        ? () => _jumpToChapter(widget.currentIndex - 1) 
                        : null,
                  ),
                  // Botão Próximo
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: widget.currentIndex < widget.allChapters.length - 1 
                        ? () => _jumpToChapter(widget.currentIndex + 1) 
                        : null,
                  ),
                ],
              ),
            ),
          
          // Indicador de modo Offline (opcional)
          if (showUI && isOffline)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("Modo Offline", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
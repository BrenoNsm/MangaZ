import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'manga_detail_screen.dart';

class MangaListScreen extends StatefulWidget {
  const MangaListScreen({super.key});

  @override
  State<MangaListScreen> createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List mangaList = [];
  bool isLoading = true;

  void _loadMangas(String q) async {
    setState(() => isLoading = true);
    try {
      final results = await _apiService.searchMangas(q); // Chamada correta
      setState(() {
        mangaList = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMangas("");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MangaDex'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar mangá...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                filled: true,
              ),
              onSubmitted: (val) => _loadMangas(val),
            ),
          ),
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView.builder(
            itemCount: mangaList.length,
            itemBuilder: (context, index) {
              final manga = mangaList[index];
              final title = manga['attributes']['title']['en'] ?? manga['attributes']['title'].values.first;
              
              // Lógica de extração da capa
              final relationships = manga['relationships'] as List;
              String? fileName;
              for (var rel in relationships) {
                if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
                  fileName = rel['attributes']['fileName'];
                }
              }
              final imageUrl = fileName != null 
                  ? 'https://uploads.mangadex.org/covers/${manga['id']}/$fileName.256.jpg'
                  : 'https://via.placeholder.com/256x360';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Image.network(imageUrl, width: 50, fit: BoxFit.cover),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MangaDetailScreen(
                      mangaData: manga,
                      title: title,
                      imageUrl: imageUrl,
                    )),
                  ),
                ),
              );
            },
          ),
    );
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "https://api.mangadex.org";

  Future<List<dynamic>> searchMangas(String query) async {
    String url = query.startsWith('?') 
        ? '$baseUrl/manga$query&includes[]=cover_art' 
        : '$baseUrl/manga?limit=20&includes[]=cover_art&title=$query';
    final r = await http.get(Uri.parse(url));
    return r.statusCode == 200 ? json.decode(r.body)['data'] : [];
  }

  Future<List<dynamic>> getChapters(String mangaId, String lang) async {
    final url = "$baseUrl/manga/$mangaId/feed?translatedLanguage[]=$lang&limit=500&order[chapter]=asc&contentRating[]=safe&contentRating[]=suggestive";
    final r = await http.get(Uri.parse(url));
    return r.statusCode == 200 ? json.decode(r.body)['data'] : [];
  }

  Future<List<String>> getChapterPages(String chapterId) async {
    final r = await http.get(Uri.parse('$baseUrl/at-home/server/$chapterId'));
    if (r.statusCode == 200) {
      final d = json.decode(r.body);
      final String b = d['baseUrl'], h = d['chapter']['hash'];
      final List f = d['chapter']['data'];
      return f.map((img) => "$b/data/$h/$img").toList();
    }
    return [];
  }
}
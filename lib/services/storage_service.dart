import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  // Busca o arquivo JSON de configuração
  Future<File> getConfigFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/manga_config.json');
  }

  // Carrega as configurações (favoritos, lidos, caminhos)
  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final file = await getConfigFile();
      if (await file.exists()) {
        final data = json.decode(await file.readAsString());
        data['favoritos'] ??= [];
        data['lidos'] ??= [];
        return data;
      }
    } catch (e) {
      debugPrint("Erro ao carregar config: $e");
    }
    return {"favoritos": [], "lidos": []};
  }

  // Salva as configurações no JSON
  Future<void> saveConfig(Map<String, dynamic> config) async {
    final file = await getConfigFile();
    await file.writeAsString(json.encode(config));
  }

  // Importa um arquivo JSON externo
  Future<bool> importConfig(File file) async {
    try {
      String content = await file.readAsString();
      Map<String, dynamic> newConfig = json.decode(content);
      if (newConfig.containsKey('favoritos')) {
        await saveConfig(newConfig);
        return true;
      }
    } catch (e) {
      debugPrint("Erro na importação: $e");
    }
    return false;
  }

  // Define onde os mangás são salvos
  Future<String> getBaseDownloadPath() async {
    final config = await loadConfig();
    if (config['download_path']?.toString().isNotEmpty ?? false) {
      return config['download_path'];
    }
    final dir = await getApplicationSupportDirectory();
    return "${dir.path}/downloads";
  }

  // Verifica se um capítulo específico está no disco
  Future<bool> isDownloaded(String mangaId, String chapterId) async {
    final base = await getBaseDownloadPath();
    return await Directory("$base/$mangaId/$chapterId").exists();
  }

  // Deleta um capítulo específico
  Future<void> deleteChapter(String mangaId, String chapterId) async {
    final base = await getBaseDownloadPath();
    final dir = Directory("$base/$mangaId/$chapterId");
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // --- O MÉTODO QUE ESTAVA DANDO ERRO ---
  // Deleta TODOS os mangás baixados de uma vez
  Future<void> deleteAllDownloads() async {
    try {
      final base = await getBaseDownloadPath();
      final dir = Directory(base);
      if (await dir.exists()) {
        // recursive: true garante que apague pastas e arquivos dentro
        await dir.delete(recursive: true);
        // Recriamos a pasta downloads vazia para evitar erros futuros
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint("Erro ao apagar todos os downloads: $e");
    }
  }
}
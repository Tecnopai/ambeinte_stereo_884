import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheManager {
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB máximo
  static const int cleanupThreshold =
      80 * 1024 * 1024; // Limpiar al llegar a 80 MB

  /// Verifica y limpia el cache si es necesario
  static Future<void> checkAndCleanCache() async {
    try {
      final currentSize = await _getAppCacheSize();
      if (kDebugMode) {
        print(
          '📊 Tamaño actual del cache: ${(currentSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
      }

      if (currentSize > cleanupThreshold) {
        if (kDebugMode) {
          print('🧹 Limpiando cache...');
        }
        await _performCleanup();
        final newSize = await _getAppCacheSize();
        if (kDebugMode) {
          print(
            '✅ Cache limpiado. Nuevo tamaño: ${(newSize / 1024 / 1024).toStringAsFixed(2)} MB',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en limpieza de cache: $e');
      }
    }
  }

  /// Limpieza forzada del cache
  static Future<void> forceCleanup() async {
    try {
      if (kDebugMode) {
        print('🧹 Forzando limpieza de cache...');
      }
      await _performCleanup();
      final newSize = await _getAppCacheSize();
      if (kDebugMode) {
        print(
          '✅ Cache forzadamente limpiado. Tamaño: ${(newSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en limpieza forzada: $e');
      }
    }
  }

  /// Obtiene el tamaño total del cache de la app
  static Future<int> _getAppCacheSize() async {
    int totalSize = 0;

    try {
      // Directorio de documentos de la app
      final appDocDir = await getApplicationDocumentsDirectory();
      totalSize += await _getDirectorySize(appDocDir);

      // Directorio temporal
      final tempDir = await getTemporaryDirectory();
      totalSize += await _getDirectorySize(tempDir);

      // Cache de imágenes (flutter_cache_manager)
      final cacheDir = await _getCacheManagerDirectory();
      if (cacheDir != null) {
        totalSize += await _getDirectorySize(cacheDir);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calculando tamaño: $e');
      }
    }

    return totalSize;
  }

  /// Obtiene el directorio del cache manager
  static Future<Directory?> _getCacheManagerDirectory() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (await cacheDir.exists()) {
        return cacheDir;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Calcula el tamaño de un directorio
  static Future<int> _getDirectorySize(Directory dir) async {
    try {
      if (!await dir.exists()) return 0;

      int size = 0;
      final files = dir.listSync(recursive: true);

      for (var file in files) {
        if (file is File) {
          try {
            size += await file.length();
          } catch (e) {
            // Ignorar archivos inaccesibles
          }
        }
      }
      return size;
    } catch (e) {
      return 0;
    }
  }

  /// Realiza la limpieza del cache
  static Future<void> _performCleanup() async {
    try {
      // 1. Limpiar cache de imágenes
      await DefaultCacheManager().emptyCache();

      // 2. Limpiar directorio temporal
      final tempDir = await getTemporaryDirectory();
      await _cleanDirectory(tempDir);

      // 3. Limpiar archivos temporales específicos de la app
      final appDocDir = await getApplicationDocumentsDirectory();
      await _cleanAppSpecificFiles(appDocDir);

      // 4. Forzar garbage collection
      _forceGarbageCollection();
    } catch (e) {
      if (kDebugMode) {
        print('Error en _performCleanup: $e');
      }
    }
  }

  /// Limpia un directorio manteniendo archivos esenciales
  static Future<void> _cleanDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) return;

      final entities = dir.listSync();
      for (var entity in entities) {
        if (entity is File) {
          // Mantener archivos de configuración esenciales
          if (!entity.path.contains('preferences') &&
              !entity.path.contains('settings') &&
              !entity.path.contains('user_data')) {
            await entity.delete();
          }
        } else if (entity is Directory) {
          // Limpiar subdirectorios excepto los esenciales
          if (!entity.path.contains('important_data')) {
            await _cleanDirectory(entity);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando directorio ${dir.path}: $e');
      }
    }
  }

  /// Limpia archivos específicos de la app manteniendo configuraciones
  static Future<void> _cleanAppSpecificFiles(Directory appDocDir) async {
    try {
      final entities = appDocDir.listSync();
      for (var entity in entities) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          // Eliminar archivos temporales, logs, cache
          if (fileName.endsWith('.tmp') ||
              fileName.endsWith('.log') ||
              fileName.endsWith('.cache') ||
              fileName.contains('temp_')) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando archivos específicos: $e');
      }
    }
  }

  /// Fuerza garbage collection
  static void _forceGarbageCollection() {
    try {
      // Incentivar garbage collection
      for (int i = 0; i < 3; i++) {
        List<dynamic> tempList = List.generate(1000, (index) => 'temp$index');
        tempList.clear();
      }
    } catch (e) {
      // Ignorar errores de GC
    }
  }
}

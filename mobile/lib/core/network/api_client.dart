import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auto-fallback interceptor: retries ONCE between local dev IPs only (not for cloud URLs)
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final currentBase = dio.options.baseUrl;
          // Never redirect a production cloud URL to local addresses
          if (currentBase.startsWith('https://')) {
            return handler.next(error);
          }

          final alreadyRetried = error.requestOptions.extra['has_retried_fallback'] == true;
          if (!alreadyRetried &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout)) {
            final fallbackBases = [
              'http://127.0.0.1:8000',
              'http://192.168.0.107:8000',
              'http://10.0.2.2:8000',
            ];
            final fallbackBase = fallbackBases.firstWhere(
              (b) => b != currentBase,
              orElse: () => 'http://127.0.0.1:8000',
            );

            try {
              final opts = error.requestOptions;
              opts.extra['has_retried_fallback'] = true;
              opts.baseUrl = fallbackBase;
              dio.options.baseUrl = fallbackBase;
              final cloned = await dio.fetch(opts);
              return handler.resolve(cloned);
            } catch (_) {
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) => debugPrint('[ORCA-API] $obj'),
        ),
      );
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      debugPrint('[ORCA-API] GET $path failed: ${e.message}');
      rethrow;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      debugPrint('[ORCA-API] POST $path failed: ${e.message}');
      rethrow;
    }
  }
}

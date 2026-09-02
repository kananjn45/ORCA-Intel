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
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auto-fallback interceptor: retries ONCE between 10.0.2.2 and 127.0.0.1 without infinite loops
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final alreadyRetried = error.requestOptions.extra['has_retried_fallback'] == true;
          if (!alreadyRetried &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout)) {
            final currentBase = dio.options.baseUrl;
            final fallbackBase = currentBase.contains('10.0.2.2')
                ? 'http://127.0.0.1:8000'
                : 'http://10.0.2.2:8000';

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

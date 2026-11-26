import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/errors/service_error.dart';

class NetworkHelper {
  final RetryConfig config;
  final Future<void> Function(Duration) _delay;

  NetworkHelper(this.config, {Future<void> Function(Duration)? delayFn})
      : _delay = delayFn ?? Future.delayed;

  /// Executes a network request with retry, backoff, and Retry-After handling.
  Future<http.StreamedResponse> sendWithRetry(
    http.Client client,
    Future<http.BaseRequest> Function() createRequest,
  ) async {
    int attempt = 0;
    final random = Random();

    while (true) {
      attempt++;
      http.BaseRequest? request;
      http.StreamedResponse? streamedResponse;

      try {
        request = await createRequest();
        streamedResponse = await client.send(request);

        // Check if status is a retryable status
        if (config.retryStatuses.contains(streamedResponse.statusCode) &&
            attempt <= config.maxRetries) {
          final delay = _calculateDelay(streamedResponse.headers, attempt, random);
          await _delay(delay);
          continue;
        }

        return streamedResponse;
      } on SocketException catch (e) {
        if (attempt <= config.maxRetries) {
          final delay = _calculateBackoffDelay(attempt, random);
          await _delay(delay);
          continue;
        }
        throw ServiceException(ServiceErrorCode.network, e.message);
      } on TimeoutException {
        if (attempt <= config.maxRetries) {
          final delay = _calculateBackoffDelay(attempt, random);
          await _delay(delay);
          continue;
        }
        throw const ServiceException(ServiceErrorCode.timeout);
      } on http.ClientException catch (e) {
        if (attempt <= config.maxRetries) {
          final delay = _calculateBackoffDelay(attempt, random);
          await _delay(delay);
          continue;
        }
        throw ServiceException(ServiceErrorCode.network, e.message);
      }
    }
  }

  Duration _calculateDelay(
    Map<String, String> headers,
    int attempt,
    Random random,
  ) {
    // 1. Honor Retry-After header if present
    final retryAfterHeader = headers['retry-after'];
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null && seconds > 0) {
        final cappedSeconds = min(seconds, config.maxRetryAfterSeconds);
        return Duration(seconds: cappedSeconds);
      }
    }

    // 2. Exponential backoff with jitter
    return _calculateBackoffDelay(attempt, random);
  }

  Duration _calculateBackoffDelay(int attempt, Random random) {
    final baseMs = config.initialBackoffMs * pow(config.backoffMultiplier, attempt - 1);
    final cappedMs = min(baseMs, config.maxBackoffMs.toDouble()).toInt();
    // Add up to 20% jitter
    final jitter = random.nextInt((cappedMs * 0.2).toInt() + 1);
    return Duration(milliseconds: cappedMs + jitter);
  }

  /// Helper to map HTTP status codes to typed ServiceErrorCode
  static ServiceErrorCode mapStatusCode(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return ServiceErrorCode.invalidApiKey;
    } else if (statusCode == 413) {
      return ServiceErrorCode.fileTooLarge;
    } else if (statusCode == 429) {
      return ServiceErrorCode.rateLimited;
    } else if (statusCode >= 500) {
      return ServiceErrorCode.server;
    }
    return ServiceErrorCode.unknown;
  }
}

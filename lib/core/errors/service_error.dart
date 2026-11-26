enum ServiceErrorCode {
  noApiKey,
  invalidApiKey,
  fileTooLarge,
  rateLimited,
  timeout,
  network,
  server,
  emptyResult,
  fileMissing,
  unknown,
}

class ServiceException implements Exception {
  final ServiceErrorCode code;
  final String? technicalDetails;

  const ServiceException(this.code, [this.technicalDetails]);

  @override
  String toString() {
    if (technicalDetails != null && technicalDetails!.isNotEmpty) {
      return 'ServiceException($code: $technicalDetails)';
    }
    return 'ServiceException($code)';
  }
}

class DataException implements Exception {
  final String operation;
  final Object? cause;

  const DataException(this.operation, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'DataException(operation: $operation, cause: $cause)';
    }
    return 'DataException(operation: $operation)';
  }
}

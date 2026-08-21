class ApiErrorInfo {
  final String message;
  final int? statusCode;
  final String? requestId;
  final bool degraded;

  const ApiErrorInfo({
    required this.message,
    this.statusCode,
    this.requestId,
    this.degraded = false,
  });
}

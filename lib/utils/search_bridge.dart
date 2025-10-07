class SearchBridge {
  static String? pendingQuery;
  static Map<String, dynamic>? pendingFilters;

  static void set(String query, Map<String, dynamic> filters) {
    pendingQuery = query;
    pendingFilters = Map.from(filters);
  }

  static Map<String, dynamic>? consumeFilters() {
    final f = pendingFilters;
    pendingFilters = null;
    return f;
  }

  static String? consumeQuery() {
    final q = pendingQuery;
    pendingQuery = null;
    return q;
  }
}

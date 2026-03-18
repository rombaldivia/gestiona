enum GeminiActionType { createQuote, createWorkOrder, addInventoryItem, changeQuoteStatus }

class GeminiAction {
  const GeminiAction({required this.type, required this.params, required this.description});
  final GeminiActionType     type;
  final Map<String, dynamic> params;
  final String               description;
}

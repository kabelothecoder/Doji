import 'package:doji_app/core/ai/ai_functions.dart';

/// [AiFunctions] without the network: answers from [respond], records calls.
class FakeAi implements AiFunctions {
  FakeAi(this.respond);

  final Map<String, dynamic> Function(String name, Map<String, Object?> body) respond;
  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> body) async {
    calls.add((name, body));
    return respond(name, body);
  }
}

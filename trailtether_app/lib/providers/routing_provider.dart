import 'package:flutter/material.dart';
import '../services/routing_service.dart';

enum RoutingStatus { idle, planning, busy, completed }

class RoutingProvider with ChangeNotifier {
  final RoutingService _service = RoutingService();

  RoutingStatus _status = RoutingStatus.idle;
  RoutingStatus get status => _status;

  final List<RoutingNode> _waypoints = [];
  List<RoutingNode> get waypoints => _waypoints;

  List<RoutingEdge> _calculatedPath = [];
  List<RoutingEdge> get calculatedPath => _calculatedPath;

  double get totalDistanceKm =>
      _calculatedPath.fold<double>(0.0, (sum, e) => sum + e.distanceKm);
  double get totalElevationGainM =>
      _calculatedPath.fold<double>(0.0, (sum, e) => sum + e.elevationGainM);

  Future<void> init() async {
    await _service.init();
    notifyListeners();
  }

  void startPlanning() {
    _status = RoutingStatus.planning;
    _waypoints.clear();
    _calculatedPath.clear();
    notifyListeners();
  }

  void addWaypoint(double lat, double lng) {
    if (_status != RoutingStatus.planning) return;

    final node = _service.findNearestNode(lat, lng);
    if (node != null) {
      _waypoints.add(node);
      _recalculatePath();
    }
    notifyListeners();
  }

  void removeLastWaypoint() {
    if (_waypoints.isNotEmpty) {
      _waypoints.removeLast();
      _recalculatePath();
    }
    notifyListeners();
  }

  void clear() {
    _status = RoutingStatus.idle;
    _waypoints.clear();
    _calculatedPath.clear();
    notifyListeners();
  }

  void _recalculatePath() {
    if (_waypoints.length < 2) {
      _calculatedPath = [];
      return;
    }

    List<RoutingEdge> fullPath = [];
    for (int i = 0; i < _waypoints.length - 1; i++) {
      final leg = _service.findPath(_waypoints[i], _waypoints[i + 1]);
      fullPath.addAll(leg);
    }
    _calculatedPath = fullPath;
  }
}

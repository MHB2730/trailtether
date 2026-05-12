import 'dart:convert';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RoutingNode {
  final double lat;
  final double lng;
  final String id;

  RoutingNode(this.lat, this.lng)
      : id = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingNode &&
          (lat - other.lat).abs() < 0.0001 &&
          (lng - other.lng).abs() < 0.0001;

  @override
  int get hashCode => id.hashCode;
}

class RoutingEdge {
  final RoutingNode from;
  final RoutingNode to;
  final double distanceKm;
  final double elevationGainM;
  final List<List<double>> coordinates; // [lng, lat, ele]
  final String trailId;

  RoutingEdge({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.elevationGainM,
    required this.coordinates,
    required this.trailId,
  });
}

class RoutingService {
  final Map<String, RoutingNode> nodes = {};
  final Map<RoutingNode, List<RoutingEdge>> adjacencyList = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/routes_cleaned.json');
      final List<dynamic> data = json.decode(jsonString);

      // In this version, we treat each trail as an edge between its start and end.
      // To handle intersections, we'd need to split trails where they meet.
      // For now, let's just do start/end nodes to keep it performant.

      for (var routeJson in data) {
        final trailId = routeJson['id'] as String;
        final coords = (routeJson['coords'] as List<dynamic>)
            .map((c) => (c as List).map((e) => (e as num).toDouble()).toList())
            .toList();
        if (coords.length < 2) continue;

        final first = coords.first;
        final last = coords.last;

        final nodeStart = _getOrCreateNode(first[1], first[0]);
        final nodeEnd = _getOrCreateNode(last[1], last[0]);

        final dist = (routeJson['distanceKm'] as num).toDouble();
        final gain = (routeJson['elevationGainM'] as num).toDouble();

        final edge = RoutingEdge(
          from: nodeStart,
          to: nodeEnd,
          distanceKm: dist,
          elevationGainM: gain,
          coordinates: coords,
          trailId: trailId,
        );

        adjacencyList.putIfAbsent(nodeStart, () => []).add(edge);

        // Drakensberg trails are usually out-and-back or loops.
        // We'll assume bidirectional for routing between trailheads.
        final revEdge = RoutingEdge(
          from: nodeEnd,
          to: nodeStart,
          distanceKm: dist,
          elevationGainM: (routeJson['elevationDescentM'] ??
                  routeJson['elevationLossM'] ??
                  gain)
              .toDouble(),
          coordinates: coords.reversed.toList(),
          trailId: trailId,
        );
        adjacencyList.putIfAbsent(nodeEnd, () => []).add(revEdge);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing RoutingService: $e');
    }
  }

  RoutingNode _getOrCreateNode(double lat, double lng) {
    final key = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    if (nodes.containsKey(key)) return nodes[key]!;

    // Check for "near" nodes (within ~10m) to snap intersections
    for (var existing in nodes.values) {
      if (_calculateDistance(lat, lng, existing.lat, existing.lng) < 0.01) {
        return existing;
      }
    }

    final newNode = RoutingNode(lat, lng);
    nodes[key] = newNode;
    return newNode;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  List<RoutingEdge> findPath(RoutingNode start, RoutingNode end) {
    final Map<RoutingNode, double> distances = {
      for (var node in nodes.values) node: double.infinity
    };
    final Map<RoutingNode, RoutingEdge?> previous = {
      for (var node in nodes.values) node: null
    };

    final queue = PriorityQueue<RoutingNode>(
        (a, b) => distances[a]!.compareTo(distances[b]!));

    distances[start] = 0;
    queue.add(start);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (current == end) break;
      if (distances[current] == double.infinity) break;

      for (var edge in adjacencyList[current] ?? []) {
        final alt = distances[current]! + edge.distanceKm;
        if (alt < distances[edge.to]!) {
          distances[edge.to] = alt;
          previous[edge.to] = edge;
          queue.add(edge.to);
        }
      }
    }

    final List<RoutingEdge> path = [];
    RoutingNode? curr = end;
    while (curr != null && curr != start) {
      final edge = previous[curr];
      if (edge == null) break;
      path.insert(0, edge);
      curr = edge.from;
    }

    return curr == start ? path : [];
  }

  RoutingNode? findNearestNode(double lat, double lng) {
    RoutingNode? nearest;
    double minDist = double.infinity;

    for (var node in nodes.values) {
      final d = _calculateDistance(lat, lng, node.lat, node.lng);
      if (d < minDist) {
        minDist = d;
        nearest = node;
      }
    }
    return minDist < 1.0 ? nearest : null; // Within 1km
  }
}

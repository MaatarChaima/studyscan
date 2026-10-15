// ============================================================
//  utils/route_observer.dart
//  Observateur de navigation : permet à l'accueil et à la
//  bibliothèque de se recharger quand on revient sur elles
//  (après un scan, un quiz, un changement de nom…)
// ============================================================

import 'package:flutter/widgets.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

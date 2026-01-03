import 'package:flutter/material.dart';
import 'home_state.dart';

class HomeController {
  final HomeState state;
  HomeController(this.state);

  Future<void> initialize({required String userName, required String userRole}) async {
    state.setUser(userName, userRole);
  }

  // API
  void toggleApiMode() {
    state.setApiMode(!state.useCloudApi);
  }

  void configureApiUrls({required String local, required String cloud}) {
    state.setApiUrls(local: local, cloud: cloud);
  }

  // Filtres & recherche
  void setQuery(String value) => state.setQuery(value);

  void toggleStatus(String status, bool selected) => state.toggleStatus(status, selected);

  void changeServer(String server) {
    if (server != state.userName) {
      state.setUser(server, state.userRole);
    }
  }
}



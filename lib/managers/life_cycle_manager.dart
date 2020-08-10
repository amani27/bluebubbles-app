import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class LifeCycleManager {
  factory LifeCycleManager() {
    return _manager;
  }

  static final LifeCycleManager _manager = LifeCycleManager._internal();

  bool _isAlive = false;

  bool get isAlive => _isAlive;

  LifeCycleManager._internal() {
    SocketManager().socketProcessUpdater.listen((event) {
      if (event.length == 0 && !_isAlive) {
        SocketManager().closeSocket();
      }
    });
  }

  startDownloader() {
    if (SocketManager().socket == null) {
      SocketManager().startSocketIO();
    }
  }

  finishDownloader() {
    if (!_isAlive) SocketManager().closeSocket();
  }

  opened() {
    if (!_isAlive && NotificationManager().chat != null) {
      NotificationManager().switchChat(NotificationManager().chat);
    }
    _isAlive = true;
    SocketManager().startSocketIO();
  }

  close() {
    debugPrint("finished setup ${SettingsManager().settings.finishedSetup}");
    if (SettingsManager().settings.finishedSetup) {
      _isAlive = false;
      SocketManager().closeSocket();
    }
  }
}

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models.dart';
import 'player.dart';

class WebMediaSession {
  WebMediaSession._();

  static web.MediaSession? get _session {
    if (!kIsWeb) return null;
    return web.window.navigator.mediaSession;
  }

  static void setMetadata(Media media) {
    final session = _session;
    if (session == null) return;

    final title = _titleFromUri(media.uri);
    session.metadata = web.MediaMetadata(web.MediaMetadataInit(
      title: title,
      artist: '',
      album: '',
      artwork: <web.MediaImage>[].toJS,
    ));
  }

  static void clearMetadata() {
    final session = _session;
    if (session == null) return;
    session.metadata = null;
  }

  static void setActionHandlers(Player player) {
    final session = _session;
    if (session == null) return;

    void onPlay() => player.play();
    void onPause() => player.pause();
    void onSeekForward() {
      final pos = player.state.position;
      player.seek(pos + const Duration(seconds: 30));
    }
    void onSeekBackward() {
      final pos = player.state.position;
      player.seek(pos - const Duration(seconds: 15));
    }
    void onSeekTo(JSAny details) {
      final raw = details.dartify();
      if (raw is Map && raw['seekTime'] is num) {
        player.seek(
          Duration(milliseconds: ((raw['seekTime'] as num) * 1000).round()),
        );
      }
    }

    session.setActionHandler('play', onPlay.toJS);
    session.setActionHandler('pause', onPause.toJS);
    session.setActionHandler('seekforward', onSeekForward.toJS);
    session.setActionHandler('seekbackward', onSeekBackward.toJS);
    session.setActionHandler('seekto', onSeekTo.toJS);
  }

  static void clearActionHandlers() {
    final session = _session;
    if (session == null) return;

    for (final action in ['play', 'pause', 'seekforward', 'seekbackward', 'seekto']) {
      session.setActionHandler(action, null);
    }
  }

  static void setPlaybackState(bool playing) {
    final session = _session;
    if (session == null) return;
    session.playbackState = playing ? 'playing' : 'paused';
  }

  static void setPositionState(Duration position, Duration duration, double playbackRate) {
    final session = _session;
    if (session == null) return;

    session.setPositionState(web.MediaPositionState(
      duration: duration.inMicroseconds / 1000000,
      playbackRate: playbackRate,
      position: position.inMicroseconds / 1000000,
    ));
  }

  static String _titleFromUri(String uri) {
    try {
      final segments = Uri.parse(uri).pathSegments;
      if (segments.isNotEmpty) {
        return segments.last.replaceAll(RegExp(r'[._]'), ' ');
      }
    } catch (_) {}
    return 'Finzy';
  }
}

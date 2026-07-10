import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '../models.dart';
import 'player.dart';
import 'player_state.dart';
import 'player_stream_controllers.dart';
import 'player_streams.dart';
import 'web_media_session.dart';

Player createWebPlayer() => PlayerWeb();

class PlayerWeb with PlayerStreamControllersMixin implements Player {
  static int _nextViewTypeId = 0;

  final String viewType;
  web.HTMLVideoElement? _videoElement;
  PlayerState _state = const PlayerState();
  bool _disposed = false;
  final List<StreamSubscription<web.Event>> _subscriptions = [];

  late final PlayerStreams _streams;

  PlayerWeb() : viewType = 'finzy-web-player-${_nextViewTypeId++}' {
    _streams = createStreams();
    _registerViewFactory();
  }

  @override
  PlayerState get state => _state;

  @override
  PlayerStreams get streams => _streams;

  @override
  int? get textureId => null;

  @override
  String? get webViewType => viewType;

  @override
  String get playerType => 'web';

  @override
  bool get disposed => _disposed;

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId, {Object? params}) {
        final video = web.HTMLVideoElement()
          ..controls = false
          ..preload = 'metadata'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000';
        video.style.setProperty('object-fit', 'contain');
        _videoElement = video;
        _attachEventListeners(video);
        return video;
      },
    );
  }

  void _attachEventListeners(web.HTMLVideoElement video) {
    _subscriptions.addAll([
      video.onPlay.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(playing: true);
        playingController.add(true);
      }),
      video.onPause.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(playing: false);
        playingController.add(false);
      }),
      video.onTimeUpdate.listen((_) {
        if (_disposed) return;
        final seconds = video.currentTime;
        if (seconds.isFinite) {
          final pos = Duration(milliseconds: (seconds * 1000).round());
          _state = _state.copyWith(position: pos);
          positionController.add(pos);
          WebMediaSession.setPositionState(pos, _state.duration, _state.rate);
        }
      }),
      video.onDurationChange.listen((_) {
        if (_disposed) return;
        final seconds = video.duration;
        if (seconds.isFinite && seconds > 0) {
          final dur = Duration(milliseconds: (seconds * 1000).round());
          _state = _state.copyWith(duration: dur);
          durationController.add(dur);
          WebMediaSession.setPositionState(_state.position, dur, _state.rate);
        }
      }),
      video.onEnded.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(completed: true, playing: false);
        completedController.add(true);
        playingController.add(false);
      }),
      video.onWaiting.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(buffering: true);
        bufferingController.add(true);
      }),
      video.onCanPlay.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(buffering: false);
        bufferingController.add(false);
      }),
      video.onVolumeChange.listen((_) {
        if (_disposed) return;
        final vol = (video.volume * 100).clamp(0.0, 100.0);
        _state = _state.copyWith(volume: vol);
        volumeController.add(vol);
      }),
      video.onRateChange.listen((_) {
        if (_disposed) return;
        final rate = video.playbackRate;
        _state = _state.copyWith(rate: rate);
        rateController.add(rate);
      }),
      video.onError.listen((_) {
        if (_disposed) return;
        final mediaError = video.error;
        final message = mediaError != null
            ? 'Video error code ${mediaError.code}: ${mediaError.message}'
            : 'Unknown video error';
        errorController.add(message);
      }),
      video.onLoadedData.listen((_) {
        if (_disposed) return;
        playbackRestartController.add(null);
      }),
      video.onSeeking.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(buffering: true);
        bufferingController.add(true);
      }),
      video.onSeeked.listen((_) {
        if (_disposed) return;
        _state = _state.copyWith(buffering: false);
        bufferingController.add(false);
      }),
    ]);
  }

  @override
  Future<void> open(Media media, {bool play = true, bool isLive = false}) async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    video.src = media.uri;
    if (media.start != null && media.start!.inSeconds > 0) {
      video.currentTime = media.start!.inMilliseconds / 1000;
    }

    _state = _state.copyWith(
      completed: false,
      buffering: true,
      position: Duration.zero,
      duration: Duration.zero,
    );
    completedController.add(false);
    bufferingController.add(true);
    positionController.add(Duration.zero);
    durationController.add(Duration.zero);

    WebMediaSession.setMetadata(media);
    WebMediaSession.setActionHandlers(this);

    if (play) {
      try {
        await video.play().toDart;
      } catch (e) {
        errorController.add('Playback failed: $e');
      }
    }
  }

  @override
  Future<void> play() async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    try {
      await video.play().toDart;
      WebMediaSession.setPlaybackState(true);
    } catch (e) {
      errorController.add('Play failed: $e');
    }
  }

  @override
  Future<void> pause() async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    video.pause();
    WebMediaSession.setPlaybackState(false);
  }

  @override
  Future<void> playOrPause() async {
    if (_disposed) return;
    if (_state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    video.pause();
    video.src = '';
    video.load();

    _state = _state.copyWith(
      playing: false,
      completed: false,
      position: Duration.zero,
      buffering: false,
    );
    playingController.add(false);
    completedController.add(false);
    positionController.add(Duration.zero);
    bufferingController.add(false);

    WebMediaSession.clearMetadata();
    WebMediaSession.clearActionHandlers();
  }

  @override
  Future<void> seek(Duration position) async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    video.currentTime = position.inMilliseconds / 1000;
    WebMediaSession.setPositionState(position, _state.duration, _state.rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    final clamped = volume.clamp(0.0, 100.0);
    video.volume = clamped / 100;
    video.muted = clamped == 0;
  }

  @override
  Future<void> setRate(double rate) async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    video.playbackRate = rate.clamp(0.5, 16.0);
  }

  @override
  Future<void> selectAudioTrack(AudioTrack track) async {
    // Browser manages audio track selection natively
  }

  @override
  Future<void> selectSubtitleTrack(SubtitleTrack track) async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    final tracks = video.textTracks;
    for (int i = 0; i < tracks.length; i++) {
      final textTrack = tracks[i];
      if (track.id == SubtitleTrack.off.id) {
        textTrack.mode = 'disabled';
      } else if (textTrack.label == track.title) {
        textTrack.mode = 'showing';
      } else {
        textTrack.mode = 'disabled';
      }
    }
  }

  @override
  Future<void> addSubtitleTrack({
    required String uri,
    String? title,
    String? language,
    bool select = false,
  }) async {
    final video = _videoElement;
    if (video == null || _disposed) return;

    video.addTextTrack('subtitles', title ?? 'Subtitle', language ?? 'und');
  }

  @override
  Future<void> setAudioDevice(AudioDevice device) async {
    // Browser manages audio output devices natively
  }

  @override
  Future<void> setAudioPassthrough(bool enabled) async {
    // Not applicable on web
  }

  @override
  Future<void> setProperty(String name, String value) async {
    // Web player has no equivalent of MPV properties
  }

  @override
  Future<String?> getProperty(String name) async => null;

  @override
  Future<void> setLogLevel(String level) async {
    // Not applicable on web
  }

  @override
  Future<void> command(List<String> args) async {
    // Not applicable on web
  }

  @override
  Future<void> configureSubtitleFonts() async {
    // Browser manages font rendering natively
  }

  @override
  Future<bool> setVisible(bool visible) async => true;

  @override
  Future<void> updateFrame() async {
    // Not applicable on web
  }

  @override
  Future<void> setVideoFrameRate(double fps, int durationMs) async {
    // Not applicable on web
  }

  @override
  Future<void> clearVideoFrameRate() async {
    // Not applicable on web
  }

  @override
  Future<bool> requestAudioFocus() async => true;

  @override
  Future<void> abandonAudioFocus() async {
    // Not applicable on web
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final video = _videoElement;
    if (video != null) {
      video.pause();
      video.src = '';
      video.load();
      video.removeAttribute('src');
      video.remove();

      for (final sub in _subscriptions) {
        await sub.cancel();
      }
      _subscriptions.clear();
    }

    _videoElement = null;
    WebMediaSession.clearMetadata();
    WebMediaSession.clearActionHandlers();
    await closeStreamControllers();
  }
}

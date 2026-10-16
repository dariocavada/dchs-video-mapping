import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'watchdog.dart';

abstract class PlaybackBackend extends ChangeNotifier {
  PlaybackSnapshot get snapshot;
  Widget get surface;
  Future<void> initialize(File file);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> configure({required bool loop, required double volume});
  Future<void> close();
}

class AndroidVideoBackend extends PlaybackBackend {
  VideoPlayerController? _controller;
  Widget _surface = const SizedBox.shrink();
  @override
  PlaybackSnapshot get snapshot {
    final v = _controller?.value;
    if (v == null) return const PlaybackSnapshot();
    return PlaybackSnapshot(
      ready: v.isInitialized,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      completed: v.isCompleted,
      position: v.position,
      duration: v.duration,
      error: v.errorDescription,
      width: v.size.width,
      height: v.size.height,
    );
  }

  @override
  Widget get surface => _surface;
  void _changed() => notifyListeners();
  @override
  Future<void> initialize(File file) async {
    final c = VideoPlayerController.file(
      file,
      viewType: VideoViewType.textureView,
    );
    _controller = c;
    c.addListener(_changed);
    await c.initialize();
    if (c.value.hasError ||
        !c.value.isInitialized ||
        c.value.duration <= Duration.zero ||
        c.value.size.isEmpty) {
      throw const FormatException('The decoder cannot open this video.');
    }
    _surface = VideoPlayer(c);
  }

  @override
  Future<void> play() async => _controller!.play();
  @override
  Future<void> pause() async => _controller!.pause();
  @override
  Future<void> seek(Duration position) async => _controller!.seekTo(position);
  @override
  Future<void> configure({required bool loop, required double volume}) async {
    await _controller!.setLooping(loop);
    await _controller!.setVolume(volume);
  }

  @override
  Future<void> close() async {
    final c = _controller;
    _controller = null;
    c?.removeListener(_changed);
    await c?.dispose();
    dispose();
  }
}

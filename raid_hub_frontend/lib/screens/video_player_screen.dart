import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final String _viewType;
  late final html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();

    _viewType = 'youtube-player-${widget.videoId}';

    _iframe = html.IFrameElement()
      ..src =
          'https://www.youtube.com/embed/${widget.videoId}'
          '?autoplay=1'
          '&mute=0'
          '&cc_lang_pref=en'
          '&cc_load_policy=1'
          '&color=white'
          '&controls=1'
          '&disablekb=0'
          '&enablejsapi=1'
          '&fs=1'
          '&hl=en'
          '&iv_load_policy=1'
          '&loop=0'
          '&modestbranding=1'
          '&playsinline=1'
          '&rel=1'
          '&origin=${Uri.base.origin}'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = true;

    _iframe.onLoad.listen((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _sendYoutubeCommand('setVolume', [20]);
        _showVolumeMessage();
      });
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
  }

  void _sendYoutubeCommand(String func, List<dynamic> args) {
    _iframe.contentWindow?.postMessage(
      '{"event":"command","func":"$func","args":${_toJsArray(args)}}',
      '*',
    );
  }

  String _toJsArray(List<dynamic> args) {
    return '[${args.map((e) => e is String ? '"$e"' : e).join(',')}]';
  }

  void _showVolumeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('소리가 20 으로 설정되었습니다.'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 80,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Player')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double playerWidth = constraints.maxWidth;
            double playerHeight = playerWidth * 9 / 16;

            if (playerHeight > constraints.maxHeight) {
              playerHeight = constraints.maxHeight;
              playerWidth = playerHeight * 16 / 9;
            }

            return Center(
              child: SizedBox(
                width: playerWidth,
                height: playerHeight,
                child: HtmlElementView(
                  viewType: _viewType,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
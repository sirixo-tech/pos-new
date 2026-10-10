import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;

Future<XFile?> showAdminPhotoCamera(BuildContext context) {
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    return picker.ImagePicker().pickImage(
      source: picker.ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  }
  return showDialog<XFile>(
    context: context,
    builder: (_) => const _PhotoCameraDialog(),
  );
}

class _PhotoCameraDialog extends StatefulWidget {
  const _PhotoCameraDialog();

  @override
  State<_PhotoCameraDialog> createState() => _PhotoCameraDialogState();
}

class _PhotoCameraDialogState extends State<_PhotoCameraDialog>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selected = 0;
  int _generation = 0;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_openCamera());
  }

  Future<void> _openCamera() async {
    final generation = ++_generation;
    final previous = _controller;
    setState(() {
      _controller = null;
      _error = null;
    });
    CameraController? camera;
    try {
      await previous?.dispose();
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera connected.');
      }
      camera = CameraController(
        _cameras[_selected],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted || generation != _generation) {
        await camera.dispose();
        return;
      }
      setState(() => _controller = camera);
    } catch (error) {
      await camera?.dispose();
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = error is CameraException && error.code == 'NoCamera'
            ? 'No camera connected. Connect a webcam or use Update photo.'
            : 'Could not open the camera. Check camera permissions and close other apps using it.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _generation++;
      final camera = _controller;
      setState(() => _controller = null);
      if (camera != null) unawaited(camera.dispose());
    } else if (state == AppLifecycleState.resumed && !_capturing) {
      unawaited(_openCamera());
    }
  }

  Future<void> _capture() async {
    final camera = _controller;
    if (camera == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await camera.takePicture();
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not take the photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    final camera = _controller;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Take photo'),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cameras.length > 1)
            DropdownButton<int>(
              isExpanded: true,
              value: _selected,
              items: [
                for (var i = 0; i < _cameras.length; i++)
                  DropdownMenuItem(value: i, child: Text('Camera ${i + 1}')),
              ],
              onChanged: _capturing
                  ? null
                  : (value) {
                      if (value == null) return;
                      _selected = value;
                      unawaited(_openCamera());
                    },
            ),
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.4).clamp(
              120.0,
              360.0,
            ),
            child: Center(
              child: _controller != null
                  ? CameraPreview(_controller!)
                  : _error != null
                  ? Text(_error!, textAlign: TextAlign.center)
                  : const CircularProgressIndicator(),
            ),
          ),
          if (_controller != null && _error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _capturing ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (_error != null && _controller == null)
        TextButton(onPressed: _openCamera, child: const Text('Retry')),
      FilledButton.icon(
        onPressed: _controller == null || _capturing ? null : _capture,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(_capturing ? 'Taking photo…' : 'Capture'),
      ),
    ],
  );
}

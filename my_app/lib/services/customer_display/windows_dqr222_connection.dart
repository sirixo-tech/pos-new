import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef Dqr222WorkerStarter =
    Future<Process> Function(String script, Map<String, String> environment);

/// Owns one Windows serial worker. Callers must serialize requests and close
/// this worker before giving the COM port to a binary media transfer.
class WindowsDqr222Connection {
  WindowsDqr222Connection({
    Dqr222WorkerStarter? startWorker,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _startWorker = startWorker ?? _start,
       _useRequestFiles = startWorker == null;

  final Dqr222WorkerStarter _startWorker;
  final bool _useRequestFiles;
  Directory? _requestDirectory;
  final Duration requestTimeout;
  Process? _process;
  String? _port;
  Completer<String>? _pending;
  int _requestId = 0;
  StreamSubscription<String>? _output;
  StreamSubscription<String>? _errors;

  String? get connectedPort => _process == null ? null : _port;

  static Future<Process> _start(
    String script,
    Map<String, String> environment,
  ) async {
    // Load the worker separately from its line-oriented stdin protocol.
    final directory = await Directory.systemTemp.createTemp('selfx_dqr_worker_');
    final file = File('${directory.path}/worker.ps1');
    try {
      await file.writeAsString('$_requestReader\n$script', flush: true);
      final process = await Process.start('powershell.exe', [
        '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', file.path,
      ], environment: environment);
      unawaited(process.exitCode.then((_) async {
        try { await directory.delete(recursive: true); } on Object { /* Best effort temp cleanup. */ }
      }));
      return process;
    } on Object {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<String> writeCommands(
    String port,
    List<String> commands, {
    required String script,
    required int baudRate,
    bool closeAfterWrite = false,
  }) async {
    if (_pending != null) {
      throw StateError('Serial request already in progress.');
    }
    if (!RegExp(r'^COM\d+$').hasMatch(port) ||
        commands.any(
          (command) => command.contains('\n') || command.contains('\r'),
        )) {
      throw ArgumentError('Invalid serial port or command.');
    }
    if (_port != port) await close();
    final elapsed = Stopwatch()..start();
    final warm = _process != null;
    try {
      if (_process == null) {
        if (_requestDirectory != null) await close();
        if (_useRequestFiles) {
          _requestDirectory = await Directory.systemTemp.createTemp('selfx_dqr_requests_');
        }
        final process = await _startWorker(script, {
          ...Platform.environment,
          'SELFX_DQR222_PORT': port,
          'SELFX_DQR222_BAUD': '$baudRate',
          if (_requestDirectory != null)
            'SELFX_DQR222_REQUEST_DIR': _requestDirectory!.path,
          'SELFX_DQR222_PARENT_PID': '$pid',
        });
        _process = process;
        _port = port;
        _output = process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              if (_process != process) return;
              try {
                final message = jsonDecode(line) as Map<String, dynamic>;
                debugPrint('[DQR222][WORKER] responseId=${message['id']} expectedId=$_requestId');
                if (message['id'] != _requestId) return;
                final pending = _pending;
                if (pending == null || pending.isCompleted) return;
                if (message['error'] != null) {
                  pending.completeError(StateError('${message['error']}'));
                } else {
                  debugPrint(
                    '[DQR222][TIMING] '
                    'qrWriteMs=${message['qrWriteMs']} '
                    'workerTotalMs=${message['elapsedMs']}',
                  );
                  pending.complete(message['response'] as String? ?? '');
                }
              } on Object catch (error) {
                _fail(error);
              }
            }, onError: (Object error) => _fail(error));
        _errors = process.stderr
            .transform(utf8.decoder)
            .listen((text) => debugPrint('[DQR222][WORKER] $text'));
        unawaited(
          process.exitCode.then((code) {
            if (_process != process) return;
            _fail(StateError('Display serial connection closed (code $code).'));
            _process = null;
            _port = null;
          }),
        );
      }
      final pending = Completer<String>();
      _pending = pending;
      final id = ++_requestId;
      // Attach the timeout/error listener before flush or any other await.
      final response = pending.future.timeout(requestTimeout);
      try {
        final request = jsonEncode({'id': id, 'commands': commands});
        if (_requestDirectory != null) {
          final temporary = File('${_requestDirectory!.path}/request.tmp');
          await temporary.writeAsString(request, flush: true);
          await temporary.rename('${_requestDirectory!.path}/request.json');
        } else {
          _process!.stdin.writeln(request);
        }
        debugPrint('[DQR222][WORKER] queued requestId=$id');
        unawaited(
          _process!.stdin.flush().then<void>((_) { debugPrint('[DQR222][WORKER] flushed requestId=$id'); }).catchError((Object error) => _fail(error)),
        );
      } on Object catch (error) {
        _fail(error);
      }
      final result = await response;
      if (closeAfterWrite) await close();
      return result;
    } on Object {
      await close();
      rethrow;
    } finally {
      _pending = null;
      debugPrint(
        '[DQR222][TIMING] port=$port warm=$warm '
        'requestTotalMs=${elapsed.elapsedMilliseconds}',
      );
    }
  }

  void _fail(Object error) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.completeError(error);
  }

  Future<void> close() async {
    final process = _process;
    _process = null;
    _port = null;
    if (process != null) {
      _fail(StateError('Display serial connection released.'));
      // Stop the mailbox worker (or close test stdin), then wait until its
      // SerialPort is disposed before allowing a binary media transfer.
      if (_requestDirectory != null) {
        await File('${_requestDirectory!.path}/stop').writeAsString('');
      }
      unawaited(process.stdin.close().catchError((Object _) {}));
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill();
        await process.exitCode;
      }
    }
    await _output?.cancel();
    await _errors?.cancel();
    _output = null;
    _errors = null;
    final directory = _requestDirectory;
    _requestDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

// A file mailbox avoids Windows PowerShell's redirected-stdin buffering on
// the second request. Atomic rename ensures the worker sees complete JSON.
const _requestReader = r'''
function Read-SelfxRequest {
  $directory = $env:SELFX_DQR222_REQUEST_DIR
  $requestPath = Join-Path $directory 'request.json'
  while (-not (Test-Path -LiteralPath (Join-Path $directory 'stop'))) {
    if (-not (Get-Process -Id ([int]$env:SELFX_DQR222_PARENT_PID) -ErrorAction SilentlyContinue)) { return $null }
    if (Test-Path -LiteralPath $requestPath) {
      $text = [System.IO.File]::ReadAllText($requestPath)
      [System.IO.File]::Delete($requestPath)
      return $text
    }
    Start-Sleep -Milliseconds 25
  }
  return $null
}
''';

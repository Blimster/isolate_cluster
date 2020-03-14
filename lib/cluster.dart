part of isolate_cluster;

///
/// Create an instance of this class to start a node of an isolate cluster. All isolates spawned by any node of the same
/// cluster will be able to communicate with each other using the provided API.
///
class IsolateCluster {
  final Logger _log = Logger('isolate_cluster.cluster');
  final Map<Uri, _IsolateInfo> _isolateInfos = {};
  final Queue<Function> _taskQueue = Queue();
  bool _queueing = false;
  bool _up = false;

  ///
  /// Creates the node for a single-node cluster. The returned cluster is up and usable.
  ///
  IsolateCluster.singleNode() {
    _log.fine('[singleNode]');
    _up = true;
  }

  get up => _up;

  ///
  /// Spawns a new isolate in the cluster this node belongs to. The provided
  /// [entryPointOrUri] has be an [EntryPoint] or an [URI].
  ///
  /// In the first case, the [EntryPoint] is called after the isolate is spawned.
  /// The entry point is executed in spawned isolate.
  ///
  /// In the second case, the main(args, message) function of the given target file is called. In
  /// the main function, the first call should be [bootstrapIsolate(dynamic, EntryPoint)]
  /// to bootstrap the cluster environment. The first parameter has to be the [message] parameter
  /// of the main(args, message) function. When the environment is up, the given [EntryPoint] is called.
  ///
  /// You can provide some [properties] optionally.
  ///
  /// This method returns a future which completes with an reference to the isolate. The future completes
  /// when the new isolate is spawned, but the [EntryPoint] of the new isolate may not be completely executed.
  ///
  Future<IsolateRef> spawnIsolate(Uri path, dynamic entryPointOrUri, [Map<String, dynamic> properties]) async {
    _log.fine('[spawnIsolate] path=$path, entryPointOrUri=$entryPointOrUri, properties=$properties ');

    // create a copy of the provided map or an empty one, if the caller do not provide properties
    if (properties != null) {
      properties = Map.from(properties);
    } else {
      properties = {};
    }

    // validate path param
    if (path == null) {
      throw ArgumentError.notNull('path');
    }
    if (!path.hasAbsolutePath) {
      throw ArgumentError('parameter [path] must be an absolte uri!');
    }

    // this method returns a future that completes to an isolate ref. the completer helps to create that future.
    Completer<IsolateRef> completer = Completer();

    // create the function that spawns the isolate.
    var spawnFunction = () async {
      if (!_up) {
        completer.completeError(StateError("node is down!"));
        return;
      }
      if (path.pathSegments.last.isEmpty) {
        // path ends with a slash(/). add an segment to the path, so the path is
        // unique
        var temp = path.resolve(Uuid().v4());
        while (_isolateInfos.containsKey(temp)) {
          temp = path.resolve(Uuid().v4());
        }
        path = temp;
      } else {
        // path does not end with a slash (/). is the path already in use?
        if (_isolateInfos.containsKey(path)) {
          completer.completeError(ArgumentError.value(path?.path, 'path', 'path already in use!'));
          return;
        }
      }

      // create receive port for the bootstrap response
      var receivePortBootstrap = ReceivePort();

      // create a container for isolate object
      var isolateInfo = _IsolateInfo();

      // create a port to receive messages from the isolate
      isolateInfo.receivePort = ReceivePort();

      // spawn the isolate and wait for it
      if (entryPointOrUri is EntryPoint) {
        EntryPoint entryPoint = entryPointOrUri;
        isolateInfo.isolate = await Isolate.spawn(
            _bootstrapIsolate,
            _IsolateBootstrapMsg(
                receivePortBootstrap.sendPort, isolateInfo.receivePort.sendPort, entryPoint, path, properties));
      } else if (entryPointOrUri is Uri) {
        Uri uri = entryPointOrUri;
        isolateInfo.isolate = await Isolate.spawnUri(
            uri, [], [receivePortBootstrap.sendPort, isolateInfo.receivePort.sendPort, path, properties]);
      } else {
        throw ArgumentError("parameter 'target' must be of type Uri or EntryPoint!");
      }

      // wait for the first message from the spawned isolate
      final isolateBootstrappedMsg =
          _IsolateBootstrappedMsg.fromMap(await receivePortBootstrap.first as Map<String, dynamic>);

      // create and store a reference to the spawned isolate
      isolateInfo.isolateRef = IsolateRef._internal(isolateBootstrappedMsg.sendPort, path, properties);

      // start listening to messages from the isolate
      isolateInfo.receivePort.listen((msg) => _processMessage(isolateInfo.isolateRef, msg));

      // send isolate up msg to all already existing isolates
      _isolateInfos.values
          .map((i) => i.isolateRef)
          .where((ref) => ref != isolateInfo.isolateRef)
          .forEach((ref) => ref._sendPort.send(_IsolateUpMsg(isolateInfo.isolateRef).toMap()));

      // store isolate info
      _isolateInfos[path] = isolateInfo;

      // complete the future returned by the parent function.
      completer.complete(isolateInfo.isolateRef);
    };

    // add the spawn function to the queue and start processing the queue.
    _processQueue(spawnFunction);

    // return a future that completes with the isolate ref created by the spawn function above.
    return completer.future;
  }

  ///
  /// Looks up an isolate by its path.
  ///
  /// The returned future completes with a [IsolateRef], if an isolate with the given path is present in this cluster.
  /// If no isolate is found, the future completes with [null].
  ///
  /// The given [path] should not end with a slash (/).
  ///
  Future<IsolateRef> lookupIsolate(Uri path) async {
    _log.fine('[lookupIsolate] path=$path');
    if (!_up) {
      throw StateError('node is down!');
    }
    return Future.value(_isolateInfos[path]?.isolateRef);
  }

  ///
  /// Looks up one or more isolates by its path.
  ///
  /// The returned furutre complets with a [List] of [IsolateRef], if any isolate beneath the given path is present in
  /// this cluster. If no isolate is fopund, the future completes with an empty [List].
  ///
  /// The given [path] must end with a slash (/).
  ///
  Future<List<IsolateRef>> lookupIsolates(Uri path) async {
    _log.fine('[lookupIsolates] path=$path');
    if (!_up) {
      throw StateError('node is down!');
    }

    if (path == null) {
      throw ArgumentError('parameter [path] not set!');
    }
    if (!path.hasAbsolutePath) {
      throw ArgumentError('parameter [path] must be an absolte uri!');
    }
    if (path.pathSegments.last.isNotEmpty) {
      throw ArgumentError('parameter [path] must end with a slash (/)!');
    }

    final result = <IsolateRef>[];
    _isolateInfos.forEach((isolatePath, isolateInfo) {
      // add every isolate ref which path is beneath the given path
      if (isolatePath.toString().startsWith(path.toString())) {
        result.add(isolateInfo.isolateRef);
      }
    });

    return Future.value(result);
  }

  ///
  /// Shuts down this node of the cluster. Every isolate spawned by this node will receive a request for shutdown. When
  /// all isolates have accepted the request, the future returned completes with [true].
  ///
  /// If any isolate do not accept the shut down request within the given [timeout], the future returned completes with
  /// [false].
  ///
  /// In both cases, when the future is completed, all isolates of this node are killed.
  ///
  Future<bool> shutdown({Duration timeout}) {
    _log.fine('[shutdown] timeout=$timeout');

    if (!_up) {
      throw StateError("node is already down!");
    }

    // node is no longer up
    _up = false;

    // set default timeout if not provided
    if (timeout == null) {
      timeout = Duration(seconds: 5);
    }

    // send a shutdown request to all isolates
    _isolateInfos.values
        .map((i) => i.isolateRef)
        .forEach((ref) => ref._sendPort.send(_IsolateShutdownRequestMsg.INSTANCE.toMap()));

    var completer = Completer<bool>();

    var sw = Stopwatch()..start();
    var shutdownCompleteWatcher = (Timer timer) {
      if (_isolateInfos.isEmpty) {
        timer.cancel();
        completer.complete(true);
      } else if (sw.elapsed >= timeout) {
        _isolateInfos.values.toList().forEach((info) => _killIsolate(info));
        timer.cancel();
        completer.complete(false);
      }
    };
    Timer.periodic(Duration(milliseconds: 10), shutdownCompleteWatcher);

    return completer.future;
  }

  _processMessage(IsolateRef ref, var msg) async {
    _log.fine('[_processMessage] ref=$ref, msg=$msg');
    if (msg is Map<String, dynamic>) {
      final Map<String, dynamic> map = msg;
      final String type = map[_MSG_TYPE];
      switch (type) {
        case _ISOLATE_READY_FOR_SHUTDOWN_MSG:
          _killIsolate(_isolateInfos[ref.path]);
          break;
        case _NODE_SHUTDOWN_REQUEST_MSG:
          final _NodeShutdownRequestMsg nodeShutdownRequestMsg = _NodeShutdownRequestMsg.fromMap(map);
          await shutdown(timeout: nodeShutdownRequestMsg.duration);
          break;
        case _ISOLATE_SPAWN_MSG:
          final _IsolateSpawnMsg isolateSpawnMsg = _IsolateSpawnMsg.fromMap(map);
          try {
            final spawnedIsolate = await spawnIsolate(
                isolateSpawnMsg.path, isolateSpawnMsg.entryPoint ?? isolateSpawnMsg.uri, isolateSpawnMsg.properties);
            ref._sendPort.send(_IsolateSpawnedMsg(isolateSpawnMsg.correlationId, spawnedIsolate, null).toMap());
          } catch (error) {
            ref._sendPort.send(
                _IsolateSpawnedMsg(isolateSpawnMsg.correlationId, null, error is String ? error : error.toString())
                    .toMap());
          }
          break;
        case _ISOLATE_LOOK_UP_MSG:
          final _IsolateLookUpMsg isolateLookUpMsg = _IsolateLookUpMsg.fromMap(map);

          final isolateRefs = <IsolateRef>[];
          if (isolateLookUpMsg.singleIsolate) {
            isolateRefs.add(_isolateInfos[isolateLookUpMsg.path].isolateRef);
          } else {
            isolateRefs.addAll(await lookupIsolates(isolateLookUpMsg.path));
          }

          ref._sendPort.send(_IsolateLookedUpMsg(
                  isolateLookUpMsg.correlationId, isolateLookUpMsg.singleIsolate, isolateLookUpMsg.path, isolateRefs)
              .toMap());
          break;
      }
    }
  }

  _killIsolate(_IsolateInfo isolate) {
    _log.fine('[_killIsolate] isolate=$isolate');
    isolate.isolate.kill();
    isolate.receivePort.close();
    _isolateInfos.remove(isolate.isolateRef._path);
  }

  _processQueue([Function newTask]) {
    _log.fine('[_processQueue] newTask=$newTask');
    if (newTask != null) {
      _taskQueue.addLast(newTask);
    }
    Future(() async {
      // ensure that the queue processing is started only once.
      if (!_queueing) {
        _queueing = true;
        try {
          // as long as there are functions in the queue...
          while (_taskQueue.isNotEmpty) {
            // remove the function, execute it and wait until it is completed.
            var taskFunction = _taskQueue.removeFirst();
            await taskFunction();
          }
        } finally {
          _queueing = false;
        }
      }
    });
  }
}

class _IsolateInfo {
  Isolate isolate;
  ReceivePort receivePort;
  IsolateRef isolateRef;

  String toString() => '[_IsolateInfo: isolate=$isolate, receivePort=$receivePort, isolateRef=$isolateRef]';
}

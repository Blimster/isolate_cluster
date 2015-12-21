part of isolate_cluster;

/**
 * Create an instance of this class to start a node of an isolate cluster. All isolates spawned by any node of the same
 * cluster will be able to communicate with each other using the provided API.
 */
class IsolateCluster {

  Map<Uri, _IsolateInfo> _isolateInfos = {};
  Queue<Function> _spawnQueue = new Queue();
  bool _spawning = false;

  /**
   * Creates the node for a single-node cluster. After the is constructed, the the cluster is up and usable.
   */
  IsolateCluster.singleNode();

  /**
   * Spawns a new isolate in the cluster this node belongs to. The provided
   * [EntryPoint] is called after the isolate is spawned. The entry point is
   * executed in spawned isolate.
   *
   * You can provide some [properties] optionally.
   *
   * This method returns a future which completes with an reference to the isolate.
   */
  Future<IsolateRef> spawnIsolate(Uri path, EntryPoint entryPoint,
      [Map<String, dynamic> properties]) async {
    // create a copy of the provided map or an empty one, if the caller do not provide properties
    if (properties != null) {
      properties = new Map.from(properties);
    } else {
      properties = {};
    }

    // validate path param
    if (path == null) {
      throw new ArgumentError.notNull('path');
    }
    if (!path.hasAbsolutePath) {
      throw new ArgumentError.value(
          path.hasAbsolutePath, 'path.hasAbsolutePath');
    }

    // this method returns a future that completes to an isolate ref. the completer helps to create that future.
    Completer<IsolateRef> completer = new Completer();

    // add the function that spawns the isolate to a queue. the functions in the queue are executed one by one.
    _spawnQueue.addLast(() async {
      if (path.pathSegments.last.isEmpty) {
        // path ends with a slash(/). add an segment to the path, so the path is
        // unique
        var temp = path.resolve(new Uuid().v4());
        while (_isolateInfos.containsKey(temp)) {
          temp = path.resolve(new Uuid().v4());
        }
        path = temp;
      } else {
        // path does not end with a slash (/). is the path already in use?
        if (_isolateInfos.containsKey(path)) {
          throw new ArgumentError.value(path, 'path', 'path already in use!');
        }
      }

      // create receive port for the bootstrap response
      var receivePortBootstrap = new ReceivePort();

      // create a container for isolate object
      var isolateInfo = new _IsolateInfo();
      _isolateInfos[path] = isolateInfo;

      // create a port to receive messages from the isolate
      isolateInfo.receivePort = new ReceivePort();

      // spawn the isolate and wait for it
      isolateInfo.isolate = await Isolate.spawn(
          _bootstrapIsolate,
          new _BootstrapIsolateMsg(receivePortBootstrap.sendPort,
              isolateInfo.receivePort.sendPort, entryPoint, path, properties));

      // wait for the first message from the spawned isolate
      var isolateSpawnedMsg =
      await receivePortBootstrap.first;

      // create and store a reference to the spawned isolate
      isolateInfo.isolateRef = new IsolateRef._internal(isolateSpawnedMsg.sendPort, path, properties);

      // start listening to messages from the isolate
      isolateInfo.receivePort.listen((msg) => _onIsolateMessage(isolateInfo.isolateRef, msg));

      // send isolate up msg to all already existing isolates
      _isolateInfos.values
          .map((i) => i.isolateRef)
          .where((ref) => ref != isolateInfo.isolateRef)
          .forEach((ref) => ref._sendPort.send(new _IsolateUpMsg(isolateInfo.isolateRef)));

      // complete the future returned by the parent function.
      completer.complete(isolateInfo.isolateRef);
    });

    // we added a function to the queue. schedule queue processing.
    new Future(() async {
      // ensure that the queue processing is started only once.
      if (!_spawning) {
        _spawning = true;
        try {
          // as long as there are functions in the queue...
          while (_spawnQueue.isNotEmpty) {
            // remove the function, execute it and wait until it is completed.
            var spawnFunction = _spawnQueue.removeFirst();
            await spawnFunction();
          }
        } finally {
          _spawning = false;
        }
      }
    });

    // return a future that completes with the isolate ref created by the spawn function above.
    return completer.future;
  }

  /**
   * Looks up an isolate by its path. The returned future completes with a [IsolateRef], if an isolate with the given
   * path is present in this cluster. If no isolate is found, the future completes with [null].
   */
  Future<IsolateRef> lookupIsolate(Uri path) async {
    return new Future.value(_isolateInfos[path].isolateRef);
  }

  /**
   * Shuts down this node of the cluster. Every isolate spawned by this node will receive a request for shutdown. When
   * all isolates have accepted the request, the future returned completes with [true].
   *
   * If any isolate do not accept the shut down request within the given [timeout], the future returned completes with
   * [false].
   *
   * In both cases, when the future is completed, all isolates of this node are killed.
   */
  Future<bool> shutdown({Duration timeout}) {
    // set default timeout if not provided
    if (timeout == null) {
      timeout = new Duration(seconds: 5);
    }

    // send a shutdown request to all isolates
    _isolateInfos.values.map((i) => i.isolateRef).forEach(
        (ref) => ref._sendPort.send(_IsolateShutdownRequestMsg.INSTANCE));

    var completer = new Completer<bool>();

    var sw = new Stopwatch()
      ..start();
    var shutdownCompleteWatcher = (Timer timer) {
      if (_isolateInfos.isEmpty) {
        timer.cancel();
        completer.complete(true);
      } else if (sw.elapsed >= timeout) {
        new List.from(_isolateInfos.values.map((i) => i.isolateRef).toSet()).forEach((ref) => _killIsolate(ref));
        timer.cancel();
        completer.complete(false);
      }
    };
    new Timer.periodic(new Duration(milliseconds: 10), shutdownCompleteWatcher);

    return completer.future;
  }

  _onIsolateMessage(IsolateRef ref, var msg) {
    if (msg is _IsolateReadyForShutdownMsg) {
      _killIsolate(_isolateInfos[ref.path]);
    } else if (msg is _NodeShutdownRequestMsg) {
      shutdown(timeout: (msg as _NodeShutdownRequestMsg).duration);
    }
  }

  _killIsolate(_IsolateInfo isolate) {
    isolate.isolate.kill();
    isolate.receivePort.close();
    _isolateInfos.remove(isolate.isolateRef._path);
  }
}

class _IsolateInfo {
  Isolate isolate;
  ReceivePort receivePort;
  IsolateRef isolateRef;
}
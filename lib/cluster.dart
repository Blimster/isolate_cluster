part of isolate_cluster;

/**
 * Create an instance of this class to start a node of an isolate cluster. All isolates spawned by any node of the same
 * cluster will be able to communicate with each other using the provided API.
 */
class IsolateCluster {

  final Logger _log = new Logger('net.blimster.isolatecluster.IsolateCluster');
  final Map<Uri, _IsolateInfo> _isolateInfos = {};
  final Queue<Function> _taskQueue = new Queue();
  bool _queueing = false;
  bool _up = false;

  /**
   * Creates the node for a single-node cluster. After the is constructed, the the cluster is up and usable.
   */
  IsolateCluster.singleNode() {
    _log.fine('[singleNode]');
    _up = true;
  }

  /**
   * Spawns a new isolate in the cluster this node belongs to. The provided
   * [EntryPoint] is called after the isolate is spawned. The entry point is
   * executed in spawned isolate.
   *
   * You can provide some [properties] optionally.
   *
   * This method returns a future which completes with an reference to the isolate.
   */
  Future<IsolateRef> spawnIsolate(Uri path, EntryPoint entryPoint, [Map<String, dynamic> properties]) async {
    _log.fine('[spawnIsolate] path=$path, properties=$properties ');

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
      throw new ArgumentError.value(path.hasAbsolutePath, 'path.hasAbsolutePath');
    }

    // this method returns a future that completes to an isolate ref. the completer helps to create that future.
    Completer<IsolateRef> completer = new Completer();

    // create the function that spawns the isolate.
    var spawnFunction = () async {
      if (!_up) {
        throw new StateError("node is down!");
      }
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

      // create a port to receive messages from the isolate
      isolateInfo.receivePort = new ReceivePort();

      // spawn the isolate and wait for it
      isolateInfo.isolate = await Isolate.spawn(
          _bootstrapIsolate,
          new _BootstrapIsolateMsg(
              receivePortBootstrap.sendPort,
              isolateInfo.receivePort.sendPort,
              entryPoint,
              path,
              properties));

      // wait for the first message from the spawned isolate
      var isolateSpawnedMsg = await receivePortBootstrap.first;

      // create and store a reference to the spawned isolate
      isolateInfo.isolateRef = new IsolateRef._internal(isolateSpawnedMsg.sendPort, path, properties);

      // start listening to messages from the isolate
      isolateInfo.receivePort.listen((msg) => _processMessage(isolateInfo.isolateRef, msg));

      // send isolate up msg to all already existing isolates
      _isolateInfos.values
          .map((i) => i.isolateRef)
          .where((ref) => ref != isolateInfo.isolateRef)
          .forEach((ref) => ref._sendPort.send(new _IsolateUpMsg(isolateInfo.isolateRef)));

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

  /**
   * Looks up an isolate by its path. The returned future completes with a [IsolateRef], if an isolate with the given
   * path is present in this cluster. If no isolate is found, the future completes with [null].
   */
  Future<IsolateRef> lookupIsolate(Uri path) async {
    _log.fine('[lookupIsolate] path=$path');
    return new Future.value(_isolateInfos[path]?.isolateRef);
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
    _log.fine('[shutdown] timeout=$timeout');

    if (!_up) {
      throw new StateError("node is down!");
    }

    // node is no longer up
    _up = false;

    // set default timeout if not provided
    if (timeout == null) {
      timeout = new Duration(seconds: 5);
    }

    // send a shutdown request to all isolates
    _isolateInfos.values
        .map((i) => i.isolateRef)
        .forEach((ref) => ref._sendPort.send(_IsolateShutdownRequestMsg.INSTANCE));

    var completer = new Completer<bool>();

    var sw = new Stopwatch()
      ..start();
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
    new Timer.periodic(new Duration(milliseconds: 10), shutdownCompleteWatcher);

    return completer.future;
  }

  _processMessage(IsolateRef ref, var msg) async {
    _log.fine('[_processMessage] ref=$ref, msg=$msg');
    if (msg is _IsolateReadyForShutdownMsg) {
      _killIsolate(_isolateInfos[ref.path]);
    } else if (msg is _NodeShutdownRequestMsg) {
      shutdown(timeout: (msg as _NodeShutdownRequestMsg).duration);
    } else if (msg is _IsolateSpawnMsg) {
      try {
        var spawnedIsolate = await spawnIsolate(msg.path, msg.entryPoint, msg.properties);
        ref._sendPort.send(new _IsolateSpawnedMsg(msg.correlationId, spawnedIsolate, null));
      } catch (error) {
        ref._sendPort.send(new _IsolateSpawnedMsg(msg.correlationId, null, error));
      }
    } else if (msg is _IsolateLookUpMsg) {
      var isolateLookUpMsg = (msg as _IsolateLookUpMsg);
      ref._sendPort.send(
          new _IsolateLookedUpMsg(
              isolateLookUpMsg.correlationId,
              isolateLookUpMsg.path,
              _isolateInfos[isolateLookUpMsg.path].isolateRef));
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
    new Future(() async {
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
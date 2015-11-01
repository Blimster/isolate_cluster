part of isolate_cluster;

/**
 * Create an instance of this class to start a node of an isolate cluster. All isolates spawned by any node of the same
 * cluster will be able to communicate with each other using the provided API.
 */
class IsolateCluster {
  Map<IsolateRef, ReceivePort> _receivePorts = {};
  List<IsolateRef> _isolateRefs = [];
  Queue<Function> _spawnQueue = new Queue();
  bool _spawning = false;

  /**
   * Creates the node for a single-node cluster. After the is constructed, the the cluster is up and usable.
   */
  IsolateCluster.singleNode();

  /**
   * Spawns a new isolate in the cluster this node belongs to. The provided [entryPoint] is called after the isolate is
   * spawned.
   *
   * You have to provide an [EntryPoint], that is called after the isolate is spawned. The entry point is executed in
   * spawned isolate.
   *
   * You can provide some [properties] optionally.
   *
   * This method returns a future which completes with an reference to the isolate.
   */
  Future<IsolateRef> spawnIsolate(EntryPoint entryPoint,
      [Map<String, dynamic> properties]) async {
    // create a copy of the provided map or an empty one, if the caller do not provide properties
    if (properties != null) {
      properties = new Map.from(properties);
    } else {
      properties = {};
    }

    // this method returns a future that completes to an isolate ref. the completer helps to create that future.
    Completer<IsolateRef> completer = new Completer();

    // add the function that spawns the isolate to a queue. the functions in the queue are executed one by one.
    _spawnQueue.addLast(() async {
      // create receive port for the bootstrap response
      ReceivePort receivePortBootstrap = new ReceivePort();

      // create a port to receive messages from the isolate
      ReceivePort receivePort = new ReceivePort();

      // spawn the isolate and wait for it
      Isolate isolate = await Isolate.spawn(
          _bootstrapIsolate,
          new _BootstrapIsolateMsg(receivePortBootstrap.sendPort,
              receivePort.sendPort, entryPoint, properties));

      // wait for the first message from the spawned isolate
      _IsolateBootstrappedMsg isolateSpawnedMsg =
          await receivePortBootstrap.first;

      // create and store a reference to the spawned isolate
      IsolateRef newRef = new IsolateRef._internal(
          isolate, isolateSpawnedMsg.sendPort, properties);
      _isolateRefs.add(newRef);

      // store the receiver and start listening to messages from the isolate
      _receivePorts[newRef] = receivePort;
      receivePort.listen((msg) => _onIsolateMessage(newRef, msg));

      // send isolate up msg to all already existing isolates
      _isolateRefs
          .where((ref) => ref != newRef)
          .forEach((ref) => ref._sendPort.send(new _IsolateUpMsg(newRef)));

      // complete the future returned by the parent function.
      completer.complete(newRef);
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
            Function spawnFunction = _spawnQueue.removeFirst();
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
   * Shuts down this node of the cluster. Every isolate spawned by this node will receive a request for shutdown. When
   * all isolates have accepted the request, the future returned completes with [true].
   *
   * If any isolate do not accept the shut down request within the given [timeout], the future returned completes with
   * [false].
   *
   * In both cases, then the future completes, all isolates of this node are killed.
   */
  Future<bool> shutdown({Duration timeout}) {
    // set default timeout if not provided
    if (timeout == null) {
      timeout = new Duration(seconds: 5);
    }

    // send a shutdown request to all isolates
    _isolateRefs.forEach(
        (ref) => ref._sendPort.send(_IsolateShutdownRequestMsg.INSTANCE));

    Completer<bool> completer = new Completer();

    Stopwatch sw = new Stopwatch()..start();
    var shutdownCompleteWatcher = (Timer timer) {
      if (_receivePorts.isEmpty) {
        timer.cancel();
        completer.complete(true);
      } else if (sw.elapsed >= timeout) {
        new List.from(_isolateRefs).forEach((ref) => _killIsolate(ref));
        timer.cancel();
        completer.complete(false);
      }
    };
    new Timer.periodic(new Duration(milliseconds: 10), shutdownCompleteWatcher);

    return completer.future;
  }

  _onIsolateMessage(IsolateRef ref, var msg) {
    if (msg is _IsolateReadyForShutdownMsg) {
      _killIsolate(ref);
    } else if (msg is _NodeShutdownRequestMsg) {
      shutdown(timeout: (msg as _NodeShutdownRequestMsg).duration);
    }
  }

  _killIsolate(IsolateRef ref) {
    ref._isolate.kill();
    _isolateRefs.remove(ref);
    ReceivePort receivePort = _receivePorts.remove(ref);
    receivePort.close();
  }
}

_bootstrapIsolate(_BootstrapIsolateMsg msg) {
  ReceivePort receivePort = new ReceivePort();

  msg.sendPortBootstrap.send(new _IsolateBootstrappedMsg(receivePort.sendPort));
  msg.entryPoint(new IsolateContext._internal(
      msg.sendPortPayload, receivePort, msg.properties));
}

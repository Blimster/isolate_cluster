part of isolate_cluster;

/**
 * Create an instance of this class to start an isolate cluster. All isolates spawned by the same instance of an
 * IsolateCluster will know each other and are able to send messages to each other.
 */
class IsolateCluster {

  Map<IsolateRef, ReceivePort> _receivePorts = {};
  List<IsolateRef> _isolateRefs = [];
  Queue<Function> _spawnQueue = new Queue();
  bool _spawning = false;

  IsolateCluster.singleNode();

  Future<IsolateRef> spawnIsolate(EntryPoint entryPoint, [Map<String, dynamic> properties]) async {

    // create a copy of the provided map or an empty one, if the caller do not provide properties
    if(properties != null) {
      properties = new Map.from(properties);
    }
    else {
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
      Isolate isolate = await Isolate.spawn(_bootstrapIsolate, new _BootstrapIsolateMsg(receivePortBootstrap.sendPort, receivePort.sendPort, entryPoint, properties));

      // wait for the first message from the spawned isolate
      _IsolateBootstrappedMsg isolateSpawnedMsg = await receivePortBootstrap.first;

      // create and store a reference to the spawned isolate
      IsolateRef newRef = new IsolateRef._internal(isolate, isolateSpawnedMsg.sendPort, properties);
      _isolateRefs.add(newRef);

      // store the receiver and start listening to messages from the isolate
      _receivePorts[newRef] = receivePort;
      receivePort.listen((msg) => _onIsolateMessage(newRef, msg));

      // send isolate up msg to all already existing isolates
      _isolateRefs.where((ref) => ref != newRef).forEach((ref) => ref._sendPort.send(new _IsolateUpMsg(newRef)));

      // complete the future returned by the parent function.
      completer.complete(newRef);
    });

    // we added a function to the queue. schedule queue processing.
    new Future(() async {
      // ensure that the queue processing is started only once.
      if(!_spawning) {
        _spawning = true;
        try {
          // as long as there are functions in the queue...
          while(_spawnQueue.isNotEmpty) {
            // remove the function, execute it and wait until it is completed.
            Function spawnFunction = _spawnQueue.removeFirst();
            await spawnFunction();
          }
        }
        finally {
          _spawning = false;
        }
      }
    });

    // return a future that completes with the isolate ref created by the spawn function above.
    return completer.future;
  }

  shutdown() {
    _isolateRefs.forEach((ref) => ref._sendPort.send(_ShutdownRequestMsg.INSTANCE));
  }

  _onIsolateMessage(IsolateRef ref, var msg) {
    if(msg is _ReadyForShutdownMsg) {
      ref._isolate.kill();
      _isolateRefs.remove(ref);
      ReceivePort receivePort = _receivePorts.remove(ref);
      receivePort.close();
    }
  }

}

_bootstrapIsolate(_BootstrapIsolateMsg msg) {

  ReceivePort receivePort = new ReceivePort();

  msg.sendPortBootstrap.send(new _IsolateBootstrappedMsg(receivePort.sendPort));
  msg.entryPoint(new IsolateContext._internal(msg.sendPortPayload, receivePort, msg.properties));

}


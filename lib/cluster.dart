part of isolate_cluster;

/**
 * Create an instance of this class to start an isolate cluster. All isolates spawned by the same instance of an
 * IsolateCluster will know each other and are able to send messages to each other.
 */
class IsolateCluster {

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

    Completer<IsolateRef> completer = new Completer();

    _spawnQueue.addLast(() async {

      // create receive port for the bootstrap response
      ReceivePort receivePortBootstrap = new ReceivePort();

      // create receive port for payload messages from the isolate to be spawned
      ReceivePort receivePort = new ReceivePort();
      receivePort.listen((msg) => print('msg from isolate received: $msg'));

      // spawn the isolate and wait for it
      Isolate isolate = await Isolate.spawn(_bootstrapIsolate, new _BootstrapIsolateMsg(receivePortBootstrap.sendPort, receivePort.sendPort, entryPoint, properties, new Set.from(_isolateRefs)));

      // wait for the first message from the spawned isolate
      _IsolateBootstrappedMsg isolateSpawnedMsg = await receivePortBootstrap.first;

      // create and store a reference to the spawned isolate
      IsolateRef newRef = new IsolateRef._internal(isolate, isolateSpawnedMsg.sendPort, properties);
      _isolateRefs.add(newRef);

      // send isolate up msg to all already existing isolates
      _isolateRefs.where((ref) => ref != newRef).forEach((ref) => ref._sendPort.send(new _IsolateUpMsg(newRef)));

      // return the ref to the spawned isolate
      completer.complete(newRef);
    });

    new Future(() async {
      if(!_spawning) {
        _spawning = true;
        try {
          while(_spawnQueue.isNotEmpty) {
            Function spawnFunction = _spawnQueue.removeFirst();
            await spawnFunction();
          }
        }
        finally {
          _spawning = false;
        }
      }
    });

    return completer.future;

  }

}

_bootstrapIsolate(_BootstrapIsolateMsg msg) {

  ReceivePort receivePort = new ReceivePort();

  msg.sendPortBootstrap.send(new _IsolateBootstrappedMsg(receivePort.sendPort));
  msg.entryPoint(new IsolateContext._internal(msg.sendPortPayload, receivePort, msg.properties, msg.existingRefs));

}


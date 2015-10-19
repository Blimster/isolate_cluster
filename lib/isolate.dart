part of isolate_cluster;

/**
 * The entry point for an isolate spawned by IsolateCluster.
 */
typedef EntryPoint(IsolateContext context);

/**
 * A reference to an isolate spawned by IsolateCluster.
 */
class IsolateRef {

  final Isolate _isolate;
  final SendPort _sendPort;
  final Map<String, dynamic> _properties;

  const IsolateRef._internal(this._isolate, this._sendPort, this._properties);

  send(String message) {
    _sendPort.send(new _PayloadMsg(message));
  }

  property(String key) {
    return _properties[key];
  }

}

/**
 * This context is provided to the entry point of an isolate spawned by IsolateCluster.
 */
class IsolateContext {

  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Map<String, dynamic> _properties;
  StreamController<String> _payloadStreamController;
  StreamController<IsolateRef> _isolateUpStreamController;

  IsolateContext._internal(this._sendPort, this._receivePort, this._properties, Iterable<IsolateRef> existingRefs) {
    _payloadStreamController = new StreamController();
    _receivePort.listen((msg) => _processMessage(msg));

    _isolateUpStreamController = new StreamController();
    existingRefs.forEach((ref) => _isolateUpStreamController.add(ref));
  }

  property(String key) => _properties[key];

  Stream<String> get onMessage => _payloadStreamController.stream;

  Stream<IsolateRef> get onIsolateUp => _isolateUpStreamController.stream;

  _processMessage(var msg) {
    if(msg is _PayloadMsg) {
      _payloadStreamController.add((msg as _PayloadMsg).payload);
    }
    else if(msg is _IsolateUpMsg) {
      _isolateUpStreamController.add((msg as _IsolateUpMsg).isolateRef);
    }
  }

}

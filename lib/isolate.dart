part of isolate_cluster;

/**
 * The entry point for an isolate spawned by IsolateCluster.
 */
typedef EntryPoint(IsolateContext context);

/**
 * A listener to a request for shutdown an isolate. Such a listener should release resource acquired by the isolate
 * and call IsolateContext.shutdown() finally.
 */
typedef ShutdownRequestListener();

/**
 * A reference to an isolate spawned by IsolateCluster.
 */
class IsolateRef {

  final Isolate _isolate;
  final SendPort _sendPort;
  final Map<String, dynamic> _properties;

  const IsolateRef._internal(this._isolate, this._sendPort, this._properties);

  /**
   * Sends a message to the isolate represented by this reference.
   */
  send(String message) {
    _sendPort.send(new _PayloadMsg(message));
  }

  /**
   * Returns the value of a property of the represented isolate.
   */
  property(String key) {
    return _properties[key];
  }

}

/**
 * This context is provided to the [EntryPoint] of an isolate spawned by [IsolateCluster]. A context is bound to a single
 * isolate.
 */
class IsolateContext {

  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Map<String, dynamic> _properties;
  final StreamController<String> _payloadStreamController = new StreamController();
  final StreamController<IsolateRef> _isolateUpStreamController  = new StreamController();
  ShutdownRequestListener _shutdownRequestListener;


  IsolateContext._internal(this._sendPort, this._receivePort, this._properties) {
    _receivePort.listen((msg) => _processMessage(msg));
  }


  /**
   * Returns the value of a property of the isolate this context is bound to.
   */
  property(String key) => _properties[key];

  /**
   * A stream of message sent to the isolate this context is bound to.
   */
  Stream<String> get onMessage => _payloadStreamController.stream;

  /**
   * A stream of isolate up events.
   */
  Stream<IsolateRef> get onIsolateUp => _isolateUpStreamController.stream;

  /**
   * The [ShutdownRequestListener] is called, when the isolate this context is bound to, receives a shutdown request.
   */
  set shutdownRequestListener(ShutdownRequestListener listener) => _shutdownRequestListener = listener;

  /**
   * Shuts down the isolate this context is bound to.
   */
  shutdownIsolate() {
    _payloadStreamController.close();
    _isolateUpStreamController.close();
    _sendPort.send(_IsolateReadyForShutdownMsg.INSTANCE);
  }

  /**
   * Shuts down the node of the isolate this context is bound to.
   */
  shutdownNode({Duration timeout}) {
    _sendPort.send(new _NodeShutdownRequestMsg(timeout));
  }

  _processMessage(var msg) {
    if(msg is _PayloadMsg) {
      _payloadStreamController.add((msg as _PayloadMsg).payload);
    }
    else if(msg is _IsolateUpMsg) {
      _isolateUpStreamController.add((msg as _IsolateUpMsg).isolateRef);
    }
    else if(msg is _IsolateShutdownRequestMsg) {
      if(_shutdownRequestListener != null) {
        _shutdownRequestListener();
      }
      else {
        _sendPort.send(_IsolateReadyForShutdownMsg.INSTANCE);
      }
    }
  }

}

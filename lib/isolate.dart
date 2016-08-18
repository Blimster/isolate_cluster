part of isolate_cluster;

/**
 * The entry point for an isolate spawned by IsolateCluster.
 */
typedef EntryPoint();

/**
 * A listener to a request for shutdown an isolate. Such a listener should release resource acquired by the isolate
 * and call IsolateContext.shutdown() finally.
 */
typedef ShutdownRequestListener();

/**
 * A message sent to an isolate containing the [sender], [replyTo], [content] and the [type].
 */
class Message {

  final IsolateRef _sender;
  final IsolateRef _replyTo;
  final String _content;
  final String _type;

  const Message._internal(this._sender, this._replyTo, this._content, this._type);

  /**
   * Returns an isolate ref to the the sender of this messages.
   */
  IsolateRef get sender => _sender;

  /**
   * Returns an isolate ref the receiver of this message should reply to.
   */
  IsolateRef get replyTo => _replyTo;

  /**
   * Returns the content of this message.
   */
  String get content => _content;

  /**
   * Returns the type of content of this message.
   */
  String get type => _type;

  String toString() {
    return '[Message][sender=${_sender?.path}, replyTo=${_replyTo?.path}, content=$_content, type=$_type]';
  }

}

/**
 * A reference to an isolate spawned by IsolateCluster.
 */
class IsolateRef {

  final SendPort _sendPort;
  final Uri _path;
  final Map<String, dynamic> _properties;

  IsolateRef._internal(this._sendPort, this._path, this._properties);

  /**
   * Returns the path of the isolate represented by this reference.
   */
  Uri get path => _path;

  /**
   * Sends a [message] to the isolate represented by this reference.
   */
  send(String message, {String type, IsolateRef replyTo}) {
    _isolateRefLog.fine('[${_localIsolateRef}][send] message=$message, type=$type, replyTo=$replyTo');
    _sendPort.send(new _PayloadMsg(_localIsolateRef, replyTo ?? _localIsolateRef, message, type));
  }

  /**
   * Returns the value of a property of the represented isolate.
   */
  String property(String key) {
    return _properties[key];
  }

  String toString() {
    return _path.toString();
  }

}

/**
 * This context is provided to the [EntryPoint] of an isolate spawned by [IsolateCluster]. A context is bound to a single
 * isolate.
 */
class IsolateContext {

  final Logger _log = new Logger('net.blimster.isolatecluster.IsolateContext');
  final Map<int, Completer<IsolateRef>> _pendingCompleters = {};
  final Map<Uri, IsolateRef> _isolateRefs = {};
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Uri _path;
  final Map<String, dynamic> _properties;
  final StreamController<Message> _payloadStreamController = new StreamController();
  final StreamController<IsolateRef> _isolateUpStreamController = new StreamController();
  int nextCompleterRef = 0;
  ShutdownRequestListener _shutdownRequestListener;


  IsolateContext._internal(this._sendPort, this._receivePort, this._path, this._properties) {
    _receivePort.listen((msg) => _processMessage(msg));
  }

  /**
   * Returns the path of the isolate this context is bound to.
   */
  Uri get path => _path;

  /**
   * Returns the value of a property of the isolate this context is bound to.
   */
  dynamic property(String key) => _properties[key];

  /**
   * A stream of message sent to the isolate this context is bound to.
   */
  Stream<Message> get onMessage => _payloadStreamController.stream;

  /**
   * A stream of isolate up events.
   */
  Stream<IsolateRef> get onIsolateUp => _isolateUpStreamController.stream;

  /**
   * The [ShutdownRequestListener] is called, when the isolate this context is bound to, receives a shutdown request.
   */
  set shutdownRequestListener(ShutdownRequestListener listener) => _shutdownRequestListener = listener;

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
    _log.fine('[${_localIsolateRef}][spawnIsolate] path=$path, properties=$properties');
    nextCompleterRef++;
    _sendPort.send(new _IsolateSpawnMsg(nextCompleterRef, path, entryPoint, properties));
    var completer = new Completer<IsolateRef>();
    _pendingCompleters[nextCompleterRef] = completer;
    return completer.future;
  }

  /**
   * Looks up an isolate by its path. The returned future completes with a [IsolateRef], if an isolate with the given
   * path is present in this cluster. If no isolate is found, the future completes with [null].
   */
  Future<IsolateRef> lookupIsolate(Uri path) async {
    _log.fine('[${_localIsolateRef}][lookupIsolate] path=$path');
    if (path == null) {
      return new Future.value(null);
    }
    var isolateRef = _isolateRefs[path];
    if (isolateRef != null) {
      return new Future.value(isolateRef);
    }
    nextCompleterRef++;
    _sendPort.send(new _IsolateLookUpMsg(nextCompleterRef, path));
    var completer = new Completer<IsolateRef>();
    _pendingCompleters[nextCompleterRef] = completer;
    return completer.future;
  }

  /**
   * Shuts down the isolate this context is bound to.
   */
  shutdownIsolate() {
    _log.fine('[${_localIsolateRef}][shutdownIsolate]');
    _payloadStreamController.close();
    _isolateUpStreamController.close();
    _sendPort.send(_IsolateReadyForShutdownMsg.INSTANCE);
  }

  /**
   * Shuts down the node of the isolate this context is bound to.
   */
  shutdownNode({Duration timeout}) {
    _log.fine('[${_localIsolateRef}][shutdownNode] timeout=$timeout');
    _sendPort.send(new _NodeShutdownRequestMsg(timeout));
  }

  _processMessage(var msg) {
    _log.fine('[${_localIsolateRef}][_processMessage] msg=$msg');
    if (msg is _PayloadMsg) {
      _payloadStreamController.add(new Message._internal(
          msg.sender, msg.replyTo, msg.payload, msg.type));
    } else if (msg is _IsolateUpMsg) {
      _isolateUpStreamController.add(msg.isolateRef);
    } else if (msg is _IsolateShutdownRequestMsg) {
      if (_shutdownRequestListener != null) {
        _shutdownRequestListener();
      } else {
        shutdownIsolate();
      }
    } else if (msg is _IsolateSpawnedMsg) {
      var completer = _pendingCompleters.remove(msg.correlationId);
      if (msg.error != null) {
        completer.completeError(msg.error);
      } else {
        _isolateRefs[msg.isolateRef.path] = msg.isolateRef;
        completer.complete(msg.isolateRef);
      }
    } else if (msg is _IsolateLookedUpMsg) {
      if (msg.isolateRef != null) {
        _isolateRefs[msg.path] = msg.isolateRef;
        var completer = _pendingCompleters.remove(msg.correlationId);
        completer.complete(msg.isolateRef);
      }
    }
  }

  String toString() => _path.toString();

}

/**
 * Getter for the local [IsolateContext].
 */
IsolateContext get isolateContext => _context;

// this function is called after the new isolate is spawned
_bootstrapIsolate(_BootstrapIsolateMsg msg) {
  var receivePort = new ReceivePort();

  // initialize the local isolate ref
  _localIsolateRef = new IsolateRef._internal(receivePort.sendPort, msg.path, msg.properties);

  // create the context and store it local to this isolate
  _context = new IsolateContext._internal(msg.sendPortPayload, receivePort, msg.path, msg.properties);

  // send the send port of this isolate to the node
  msg.sendPortBootstrap.send(new _IsolateBootstrappedMsg(receivePort.sendPort));

  // call entry point
  msg.entryPoint();
}

// this isolate ref represents the local isolate.
IsolateRef _localIsolateRef;

// isolate context for the local isolate
IsolateContext _context;

// logger for IsolateRef (it is not part of the class, because the class is sent to other isolates)
Logger _isolateRefLog = new Logger('net.blimster.isolatecluster.IsolateRef');

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

  const Message._internal(
      this._sender, this._replyTo, this._content, this._type);

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
  SendPort _sendPort;
  Uri _path;
  Map<String, dynamic> _properties;

  IsolateRef._internal(this._sendPort, this._path, this._properties);

  IsolateRef._fromMap(Map<String, dynamic> map) {
    _sendPort = map[_SEND_PORT];
    _path = Uri.parse(map[_PATH]);
    _properties = map[_PROPERTIES];
  }

  Map<String, dynamic> _toMap() {
    return {
      _SEND_PORT: _sendPort,
      _PATH: _path?.toString(),
      _PROPERTIES: _properties
    };
  }

  /**
   * Returns the path of the isolate represented by this reference.
   */
  Uri get path => _path;

  /**
   * Sends a [message] to the isolate represented by this reference.
   */
  send(String message, {String type, IsolateRef replyTo}) {
    _isolateRefLog.fine(
        '[${_localIsolateRef}][send] message=$message, type=$type, replyTo=$replyTo');
    _sendPort.send(new _PayloadMsg(
            _localIsolateRef, replyTo ?? _localIsolateRef, message, type)
        .toMap());
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
  final StreamController<Message> _payloadStreamController =
      new StreamController();
  final StreamController<IsolateRef> _isolateUpStreamController =
      new StreamController();
  int _nextCompleterRef = 0;
  ShutdownRequestListener _shutdownRequestListener;

  IsolateContext._internal(
      this._sendPort, this._receivePort, this._path, this._properties) {
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
  set shutdownRequestListener(ShutdownRequestListener listener) =>
      _shutdownRequestListener = listener;

  /**
   * Spawns a new isolate in the cluster this node belongs to. The provided
   * [entryPointOrUri] can be an [EntryPoint] or an [URI]. 
   *
   * In the first case, the [EntryPoint] is called after the isolate is spawned. 
   * The entry point is executed in spawned isolate.
   *
   * In the second case, the main(List args) function of the give target file is called. In 
   * the main funtion, the first call should be [bootstrapIsolate(List,EntryPoint)]
   * to bootstrap the cluster environment. The first parameter has to be the [args] parameter
   * provided to the main() function. When the environment is up, the given [EntryPoint] is called. 
   *
   * You can provide some [properties] optionally.
   *
   * This method returns a future which completes with an reference to the isolate.
   */
  Future<IsolateRef> spawnIsolate(Uri path, dynamic entryPointOrUri,
      [Map<String, dynamic> properties]) async {
    _log.fine(
        '[${_localIsolateRef}][spawnIsolate] path=$path, endPointOrUri=$entryPointOrUri, properties=$properties');
    _nextCompleterRef++;
    _sendPort.send(new _IsolateSpawnMsg(
            _nextCompleterRef,
            path,
            entryPointOrUri is EntryPoint ? entryPointOrUri : null,
            entryPointOrUri is Uri ? entryPointOrUri : null,
            properties)
        .toMap());
    final completer = new Completer<IsolateRef>();
    _pendingCompleters[_nextCompleterRef] = completer;
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
    _nextCompleterRef++;
    _sendPort.send(new _IsolateLookUpMsg(_nextCompleterRef, path).toMap());
    var completer = new Completer<IsolateRef>();
    _pendingCompleters[_nextCompleterRef] = completer;
    return completer.future;
  }

  /**
   * Shuts down the isolate this context is bound to.
   */
  shutdownIsolate() {
    _log.fine('[${_localIsolateRef}][shutdownIsolate]');
    _payloadStreamController.close();
    _isolateUpStreamController.close();
    _sendPort.send(_IsolateReadyForShutdownMsg.INSTANCE.toMap());
  }

  /**
   * Shuts down the node of the isolate this context is bound to.
   */
  shutdownNode({Duration timeout}) {
    _log.fine('[${_localIsolateRef}][shutdownNode] timeout=$timeout');
    _sendPort.send(new _NodeShutdownRequestMsg(timeout).toMap());
  }

  _processMessage(var msg) {
    _log.fine('[${_localIsolateRef}][_processMessage] msg=$msg');
    if (msg is Map) {
      Map<String, dynamic> map = msg;
      String type = map[_MSG_TYPE];
      switch (type) {
        case _PAYLOAD_MSG:
          final _PayloadMsg payloadMsg = new _PayloadMsg.fromMap(map);
          _payloadStreamController.add(new Message._internal(payloadMsg.sender,
              payloadMsg.replyTo, payloadMsg.payload, payloadMsg.type));
          break;
        case _ISOLATE_UP_MSG:
          final _IsolateUpMsg isolateUpMsg = new _IsolateUpMsg.fromMap(map);
          _isolateUpStreamController.add(isolateUpMsg.isolateRef);
          break;
        case _ISOLATE_SHUTDOWN_REQUEST_MSG:
          if (_shutdownRequestListener != null) {
            _shutdownRequestListener();
          } else {
            shutdownIsolate();
          }
          break;
        case _ISOLATE_SPAWNED_MSG:
          final _IsolateSpawnedMsg isolateSpawnedMsg =
              new _IsolateSpawnedMsg.fromMap(map);
          final completer =
              _pendingCompleters.remove(isolateSpawnedMsg.correlationId);
          if (isolateSpawnedMsg.error != null) {
            completer.completeError(isolateSpawnedMsg.error);
          } else {
            _isolateRefs[isolateSpawnedMsg.isolateRef.path] =
                isolateSpawnedMsg.isolateRef;
            completer.complete(isolateSpawnedMsg.isolateRef);
          }
          break;
        case _ISOLATE_LOOKED_UP_MSG:
          final _IsolateLookedUpMsg isolateLookedUpMsg =
              new _IsolateLookedUpMsg.fromMap(map);
          if (isolateLookedUpMsg.isolateRef != null) {
            _isolateRefs[isolateLookedUpMsg.path] =
                isolateLookedUpMsg.isolateRef;
            final completer =
                _pendingCompleters.remove(isolateLookedUpMsg.correlationId);
            completer.complete(isolateLookedUpMsg.isolateRef);
          }
          break;
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
_bootstrapIsolate(_IsolateBootstrapMsg msg) {
  var receivePort = new ReceivePort();

  // initialize the local isolate ref
  _localIsolateRef =
      new IsolateRef._internal(receivePort.sendPort, msg.path, msg.properties);

  // create the context and store it local to this isolate
  _context = new IsolateContext._internal(
      msg.sendPortPayload, receivePort, msg.path, msg.properties);

  // send the send port of this isolate to the node
  msg.sendPortBootstrap
      .send(new _IsolateBootstrappedMsg(receivePort.sendPort).toMap());

  // call entry point
  msg.entryPoint();
}

/**
 * This function is supposed to be called as first operation in a main() function of an isolate,
 * if the isolate is spawned using an uri.
 */
bootstrapIsolate(List args, EntryPoint entryPoint) {
  final bootstrapMsg =
      new _IsolateBootstrapMsg(args[0], args[1], entryPoint, args[2], args[3]);
  _bootstrapIsolate(bootstrapMsg);
}

// this isolate ref represents the local isolate.
IsolateRef _localIsolateRef;

// isolate context for the local isolate
IsolateContext _context;

// logger for IsolateRef (it is not part of the class, because the class is sent to other isolates)
Logger _isolateRefLog = new Logger('net.blimster.isolatecluster.IsolateRef');

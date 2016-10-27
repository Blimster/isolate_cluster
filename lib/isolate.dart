part of isolate_cluster;

///
/// The entry point for an isolate spawned by the isolate cluster.
///
/// The entry point will be executed after the isolate was spawned. An entry points a good
/// location to register listeners for cluster events (e.g. message or isolate up). As long
/// as the entry point is executed, no events will be dispatched to registered listeners.
/// Events occuring while the entry point is executing will be buffered and dispatched as soon
/// as the entry point is completely executed.
///
typedef void EntryPoint(IsolateContext);

///
/// A listener to a request for shutdown an isolate.
///
/// Such a listener should release resources acquired by the isolate and call
/// [IsolateContext.shutdownIsolate] finally.
///
typedef void ShutdownRequestListener();

typedef void _EventPublisher(dynamic);

/**
 * A message sent to an isolate containing the [sender], [replyTo], [content] and the [type].
 */
class Message {
  final IsolateRef _sender;
  final IsolateRef _replyTo;
  final String _content;
  final String _type;
  final String _correlationId;

  const Message._internal(this._sender, this._replyTo, this._content, this._type, this._correlationId);

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

  /**
   * Returns the correlationId of this message.
   */
  String get correlationId => _correlationId;

  String toString() {
    return '[Message][sender=${_sender?.path}, replyTo=${_replyTo?.path}, content=$_content, type=$_type, correlationId=$correlationId]';
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
    _properties = map[_PROPERTIES] as Map<String, dynamic>;
  }

  Map<String, dynamic> _toMap() {
    return {_SEND_PORT: _sendPort, _PATH: _path?.toString(), _PROPERTIES: _properties};
  }

  /**
   * Returns the path of the isolate represented by this reference.
   */
  Uri get path => _path;

  /**
   * Sends a [message] to the isolate represented by this reference.
   */
  send(String message, {String type, String correlationId, IsolateRef replyTo}) {
    _isolateRefLog.fine(
        '[${_localIsolateRef}][send] message=$message, type=$type, correlationId=$correlationId, replyTo=$replyTo');
    _sendPort
        .send(new _PayloadMsg(_localIsolateRef, replyTo ?? _localIsolateRef, message, type, correlationId).toMap());
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
  final Logger _log = new Logger('isolate_cluster.context');
  final Map<int, Completer<dynamic>> _pendingCompleters = {};
  final Map<Uri, IsolateRef> _isolateRefs = {};
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Uri _path;
  final Map<String, dynamic> _properties;
  final StreamController<Message> _payloadEvents = new StreamController.broadcast();
  final StreamController<IsolateRef> _isolateUpEvents = new StreamController.broadcast();
  int _nextCompleterRef = 0;
  ShutdownRequestListener _shutdownRequestListener;
  _EventPublisher _publishEvent;

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
   * Returns the [IsolateRef] for this isolate.
   */
  IsolateRef get isolateRef => _localIsolateRef;

  /**
   * A broadcast stream of message sent to the isolate this context is bound to.
   */
  Stream<Message> get onMessage => _payloadEvents.stream;

  /**
   * A broadcast stream of isolate up events.
   */
  Stream<IsolateRef> get onIsolateUp => _isolateUpEvents.stream;

  /**
   * The [ShutdownRequestListener] is called, when the isolate this context is bound to, receives a shutdown request.
   */
  set shutdownRequestListener(ShutdownRequestListener listener) => _shutdownRequestListener = listener;

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
   * This method returns a future which completes with an reference to the isolate. The future completes 
   * when the new isolate is spawned, but the [EntryPoint] of the new isolate may not be completely executed. 
   */
  Future<IsolateRef> spawnIsolate(Uri path, dynamic entryPointOrUri, [Map<String, dynamic> properties]) async {
    _log.fine('[${_localIsolateRef}][spawnIsolate] path=$path, endPointOrUri=$entryPointOrUri, properties=$properties');
    _nextCompleterRef++;
    _sendPort.send(new _IsolateSpawnMsg(_nextCompleterRef, path, entryPointOrUri is EntryPoint ? entryPointOrUri : null,
            entryPointOrUri is Uri ? entryPointOrUri : null, properties)
        .toMap());
    final completer = new Completer<IsolateRef>();
    _pendingCompleters[_nextCompleterRef] = completer;
    return completer.future;
  }

  /// Looks up an isolate by its path.
  ///
  /// The returned future completes with a [IsolateRef], if an isolate with the given path is present in this cluster.
  /// If no isolate is found, the future completes with [null].
  ///
  /// The given [path] must end with a slash (/).
  ///
  Future<IsolateRef> lookupIsolate(Uri path) async {
    _log.fine('[${_localIsolateRef}][lookupIsolate] path=$path');
    if (path == null) {
      throw new ArgumentError('parameter [path] must not be null!');
    }

    // maybe we already now the isolate
    var isolateRef = _isolateRefs[path];
    if (isolateRef != null) {
      return new Future.value(isolateRef);
    }

    // the isolate is not know, forward the request to the cluster
    _nextCompleterRef++;
    _sendPort.send(new _IsolateLookUpMsg(_nextCompleterRef, true, path).toMap());
    var completer = new Completer<IsolateRef>();
    _pendingCompleters[_nextCompleterRef] = completer;
    return completer.future;
  }

  /// Looks up one or more isolates by its path.
  ///
  /// The returned furutre complets with a [List] of [IsolateRef], if any isolate beneath the given path is present in
  /// this cluster. If no isolate is fopund, the future completes with an empty [List].
  ///
  /// The given [path] has to end with a slash (/).
  ///
  Future<List<IsolateRef>> lookupIsolates(Uri path) async {
    _log.fine('[${_localIsolateRef}][lookupIsolates] path=$path');
    if (path == null) {
      throw new ArgumentError('parameter [path] must not be null!');
    }
    if (!path.hasAbsolutePath) {
      throw new ArgumentError('parameter [path] must be an absolute uri!');
    }
    if (!path.pathSegments.last.isEmpty) {
      throw new ArgumentError('parameter [path] must end with a slash (/)!');
    }

    _nextCompleterRef++;
    _sendPort.send(new _IsolateLookUpMsg(_nextCompleterRef, false, path).toMap());
    var completer = new Completer<List<IsolateRef>>();
    _pendingCompleters[_nextCompleterRef] = completer;
    return completer.future;
  }

  /**
   * Shuts down the isolate this context is bound to.
   */
  shutdownIsolate() {
    _log.fine('[${_localIsolateRef}][shutdownIsolate]');
    _payloadEvents.close();
    _isolateUpEvents.close();
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
    if (msg is Map<String, dynamic>) {
      Map<String, dynamic> map = msg;
      String type = map[_MSG_TYPE];
      switch (type) {
        case _PAYLOAD_MSG:
          final _PayloadMsg payloadMsg = new _PayloadMsg.fromMap(map);
          _publishEvent(new Message._internal(
              payloadMsg.sender, payloadMsg.replyTo, payloadMsg.payload, payloadMsg.type, payloadMsg.correlationId));
          break;
        case _ISOLATE_UP_MSG:
          _publishEvent(new _IsolateUpMsg.fromMap(map).isolateRef);
          break;
        case _ISOLATE_SHUTDOWN_REQUEST_MSG:
          if (_shutdownRequestListener != null) {
            _shutdownRequestListener();
          } else {
            shutdownIsolate();
          }
          break;
        case _ISOLATE_SPAWNED_MSG:
          final _IsolateSpawnedMsg isolateSpawnedMsg = new _IsolateSpawnedMsg.fromMap(map);
          final completer = _pendingCompleters.remove(isolateSpawnedMsg.correlationId);
          if (isolateSpawnedMsg.error != null) {
            completer.completeError(isolateSpawnedMsg.error);
          } else {
            _isolateRefs[isolateSpawnedMsg.isolateRef.path] = isolateSpawnedMsg.isolateRef;
            completer.complete(isolateSpawnedMsg.isolateRef);
          }
          break;
        case _ISOLATE_LOOKED_UP_MSG:
          final _IsolateLookedUpMsg isolateLookedUpMsg = new _IsolateLookedUpMsg.fromMap(map);
          if (isolateLookedUpMsg.isolateRefs != null) {
            isolateLookedUpMsg.isolateRefs.forEach((ref) => _isolateRefs[ref._path] = ref);
            final completer = _pendingCompleters.remove(isolateLookedUpMsg.correlationId);
            if (isolateLookedUpMsg.singleIsolate) {
              completer.complete(isolateLookedUpMsg.isolateRefs.first);
            } else {
              completer.complete(isolateLookedUpMsg.isolateRefs);
            }
          }
          break;
      }
    }
  }

  String toString() => _path.toString();
}

// this function is called after the new isolate is spawned
_bootstrapIsolate(_IsolateBootstrapMsg msg) {
  var receivePort = new ReceivePort();

  // initialize the local isolate ref
  _localIsolateRef = new IsolateRef._internal(receivePort.sendPort, msg.path, msg.properties);

  // create the context and store it local to this isolate
  _context = new IsolateContext._internal(msg.sendPortPayload, receivePort, msg.path, msg.properties);

  // send the send port of this isolate to the node
  msg.sendPortBootstrap.send(new _IsolateBootstrappedMsg(receivePort.sendPort).toMap());

  // before the entry point is completely executed, buffer incoming event in a queue
  Queue eventQueue = new Queue();
  _context._publishEvent = (event) {
    eventQueue.add(event);
  };

  // call entry point
  msg.entryPoint(_context);

  // entry point is executed. from now on publish event directly to the stream
  _context._publishEvent = (event) {
    if (event is Message) {
      _context._payloadEvents.add(event);
    } else if (event is IsolateRef) {
      _context._isolateUpEvents.add(event);
    }
  };
  while (eventQueue.isNotEmpty) {
    _context._publishEvent(eventQueue.removeFirst());
  }
}

/**
 * This function is supposed to be called as first operation in a main(args, message) function of an isolate,
 * if the isolate is spawned using an uri. You have to provide the second argument ([message]) to this function.
 */
bootstrapIsolate(dynamic message, EntryPoint entryPoint) {
  final bootstrapMsg =
      new _IsolateBootstrapMsg(message[0], message[1], entryPoint, message[2], message[3] as Map<String, dynamic>);
  _bootstrapIsolate(bootstrapMsg);
}

// this isolate ref represents the local isolate.
IsolateRef _localIsolateRef;

// isolate context for the local isolate
IsolateContext _context;

// logger for IsolateRef (it is not part of the class, because the class is sent to other isolates)
Logger _isolateRefLog = new Logger('isolate_cluster.ref');

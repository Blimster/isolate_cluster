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
 * A message sent to an isolate containing the [sender], [replyTo] and the [content].
 */
class Message {

  final IsolateRef _sender;
  final IsolateRef _replyTo;
  final String _content;

  const Message._internal(this._sender, this._replyTo, this._content);

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

  String toString() {
    return '[Message][sender=${_sender?.path}, replyTo=${_replyTo
        ?.path}, content=$_content]';
  }

}

/**
 * A reference to an isolate spawned by IsolateCluster.
 */
class IsolateRef {

  final SendPort _sendPort;
  final Uri _path;
  final Map<String, dynamic> _properties;

  IsolateRef._internal(this._sendPort, this._path,
      this._properties);

  /**
   * Returns the path of the isolate represented by this reference.
   */
  Uri get path => _path;

  /**
   * Sends a [message] to the isolate represented by this reference.
   */
  send(String message, {IsolateRef replyTo}) {
    _sendPort.send(new _PayloadMsg(_localIsolateRef, replyTo ?? _localIsolateRef, message));
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

  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Uri _path;
  final Map<String, dynamic> _properties;
  final StreamController<Message> _payloadStreamController = new StreamController();
  final StreamController<IsolateRef> _isolateUpStreamController = new StreamController();
  ShutdownRequestListener _shutdownRequestListener;


  IsolateContext._internal(this._sendPort, this._receivePort, this._path,
      this._properties) {
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
    if (msg is _PayloadMsg) {
      _PayloadMsg payloadMsg = (msg as _PayloadMsg);
      _payloadStreamController.add(new Message._internal(
          payloadMsg.sender, payloadMsg.replyTo, payloadMsg.payload));
    }
    else if (msg is _IsolateUpMsg) {
      var isolateUpMsg = (msg as _IsolateUpMsg);
      _isolateUpStreamController.add(isolateUpMsg.isolateRef);
    }
    else if (msg is _IsolateShutdownRequestMsg) {
      if (_shutdownRequestListener != null) {
        _shutdownRequestListener();
      }
      else {
        _sendPort.send(_IsolateReadyForShutdownMsg.INSTANCE);
      }
    }
  }

  String toString() {
    return _path.toString();
  }

}

/**
 * Getter for the local [IsolateContext].
 */
IsolateContext get context => _context;

// this function is called after the new isolate is spawned
_bootstrapIsolate(_BootstrapIsolateMsg msg) {
  var receivePort = new ReceivePort();

  // initialize the local isolate ref
  _localIsolateRef = new IsolateRef._internal(
      receivePort.sendPort, msg.path, msg.properties);

  // create the context and store it local to this isolate
  _context = new IsolateContext._internal(
      msg.sendPortPayload, receivePort, msg.path, msg.properties);

  msg.sendPortBootstrap.send(new _IsolateBootstrappedMsg(receivePort.sendPort));
  msg.entryPoint();
}

// this isolate ref represents the local isolate.
IsolateRef _localIsolateRef;

// isolate context for the local isolate
IsolateContext _context;
part of isolate_cluster;

Map<String, IsolateRefGroup> _groups = {};

enum _IsolateRefGroupState {
  CREATED, //
  INITIALIZING, //
  INITIALIZED
}

///
/// A group of isolate beneath an URI.
///
/// Use this class to access isolates of same type as if they were one. Isolates of same
/// type should be beneath the same URI path (ending with a slash) a should have the same API.
///
class IsolateRefGroup {
  final Uri path;
  final Map<Uri, IsolateRef> _isolates = new SplayTreeMap((k1, k2) => k1.toString().compareTo(k2.toString()));
  _IsolateRefGroupState _state = _IsolateRefGroupState.CREATED;
  int _isolateIndex = 0;

  IsolateRefGroup._internal(Uri path) : this.path = path {
    if (_context == null) {
      throw new StateError('no context available!');
    }
    if (path.pathSegments.last.isNotEmpty) {
      throw new ArgumentError('param [path] must end with a slash (/)!');
    }
  }

  Future<IsolateRefGroup> _init() async {
    _state = _IsolateRefGroupState.INITIALIZING;
    List<IsolateRef> refs = await _context.lookupIsolates(path);
    refs.forEach((ref) => _isolates[ref.path] = ref);
    _context.onIsolateUp.where((ref) => ref.path.path.startsWith(path.toString())).listen(_onIsolateUp);
    _state = _IsolateRefGroupState.INITIALIZED;
    return new Future.value(this);
  }

  _onIsolateUp(IsolateRef ref) {
    _isolates.putIfAbsent(ref.path, () => ref);
  }

  ///
  /// Send a message to one of the isolates of this group.
  ///
  /// By default, messages are sent using a round robin strategy.
  ///
  send(String message, {String type, String correlationId, IsolateRef replyTo}) {
    _isolateIndex++;
    if (_isolateIndex >= _isolates.length) {
      _isolateIndex = 0;
    }
    final isolateRef = _isolates.values.elementAt(_isolateIndex);
    isolateRef.send(message, type: type, correlationId: correlationId, replyTo: replyTo);
  }
}

///
/// Returns an [IsolateRefGroup] for the given path.
///
Future<IsolateRefGroup> isolateRefGroupFor(Uri path) async {
  var result = _groups[path.toString()];
  if (result == null) {
    result = new IsolateRefGroup._internal(path);
    if (result._state == _IsolateRefGroupState.CREATED) {
      await result._init();
    }
    _groups[path.toString()] = result;
  }
  return new Future.value(result);
}

///
/// To register to a [MessageDispatcher] to handle a message of a specific type.
///
typedef Future MessageHandler(Message msg);

///
/// Dispatches a message to a handler registered for a specific type.
///
class MessageDispatcher {
  Map<String, MessageHandler> _handlers = {};

  ///
  /// Dispatches the given [Message] to a [MessageHandler].
  ///
  /// The returned future will complete with [false] if no handler was registered for the
  /// type of the given [Message].
  ///
  /// If a handler was registered, the futured will complete with [true] when the handler
  /// has completed to handle the message.
  ///
  Future<bool> dispatch(Message message) async {
    final handler = _handlers[message.type];
    if (handler == null) {
      return new Future.value(false);
    }
    await handler(message);
    return new Future.value(true);
  }

  ///
  /// Sets a [MessageHandler] for a message type.
  ///
  /// It is an error to register a handler for a type another handler is already registered to.
  ///
  void setHandler(String type, MessageHandler handler) {
    if (type == null || type.trim().isEmpty) {
      throw new ArgumentError('param [type] must not be null or empty!');
    }
    if (handler == null) {
      throw new ArgumentError('param [handler] must not be null!');
    }
    _handlers[type.trim()] = handler;
  }

  ///
  /// Removes a [MessageHandler] for a type of message.
  ///
  void removeHandler(String type) {
    _handlers.remove(type);
  }
}

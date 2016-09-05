part of isolate_cluster;

const _ISOLATE_BOOTSTRAP_MSG = 'isolateBootstrapMsg';
const _ISOLATE_BOOTSTRAPPED_MSG = 'isolateBootstrappedMsg';
const _ISOLATE_UP_MSG = 'isolateUpMsg';
const _ISOLATE_SPAWN_MSG = 'isolateSpawnMsg';
const _ISOLATE_SPAWNED_MSG = 'isolateSpawnedMsg';
const _ISOLATE_LOOK_UP_MSG = 'isolateLookUpMsg';
const _ISOLATE_LOOKED_UP_MSG = 'isolateLookedUpMsg';
const _ISOLATE_SHUTDOWN_REQUEST_MSG = 'isolateShutdownRequestMsg';
const _ISOLATE_READY_FOR_SHUTDOWN_MSG = 'isolateReadyForShutdownMsg';
const _PAYLOAD_MSG = 'payloadMsg';
const _NODE_SHUTDOWN_REQUEST_MSG = 'nodeShutdownRequestMsg';

const _MSG_TYPE = 'msgType';
const _SEND_PORT = 'sendPort';
const _SEND_PORT_BOOTSTRAP = 'sendPortBootstrap';
const _SEND_PORT_PAYLOAD = 'sendPortPayload';
const _PATH = 'path';
const _ENTRY_POINT = 'entryPoint';
const _PROPERTIES = 'properties';
const _CORRELATION_ID = 'correlationId';
const _SENDER = 'sender';
const _REPLY_TO = 'replyTo';
const _PAYLOAD = 'payload';
const _TYPE = 'type';
const _ISOLATE_REF = 'isolateRef';
const _ERROR = 'error';
const _DURATION = 'duration';
const _URI = 'uri';

class _IsolateBootstrapMsg {

  final SendPort sendPortBootstrap;
  final SendPort sendPortPayload;
  final Uri path;
  final EntryPoint entryPoint;
  final Map<String, dynamic> properties;

  _IsolateBootstrapMsg(this.sendPortBootstrap, this.sendPortPayload,
      this.entryPoint, this.path, this.properties);

  _IsolateBootstrapMsg.fromMap(Map<String, dynamic> map)
      : sendPortBootstrap = map[_SEND_PORT_BOOTSTRAP],
        sendPortPayload = map[_SEND_PORT_PAYLOAD],
        path = Uri.parse(map[_PATH]),
        entryPoint = map[_ENTRY_POINT],
        properties = map[_PROPERTIES];

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_BOOTSTRAP_MSG,
      _SEND_PORT_BOOTSTRAP: sendPortBootstrap,
      _SEND_PORT_PAYLOAD: sendPortPayload,
      _PATH: path?.toString(),
      _ENTRY_POINT: entryPoint,
      _PROPERTIES: properties
    };
  }

  String toString() => '[_BootstrapIsolateMsg: path=$path, entryPoint=$entryPoint, properties=$properties]';

}

class _IsolateBootstrappedMsg {

  final SendPort sendPort;

  _IsolateBootstrappedMsg(this.sendPort);

  _IsolateBootstrappedMsg.fromMap(Map<String, dynamic> map)
      : sendPort = map[_SEND_PORT];

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_BOOTSTRAPPED_MSG,
      _SEND_PORT: sendPort
    };
  }

  toString() => '[_IsolateBootstrappedMsg]';

}

class _PayloadMsg {

  final IsolateRef sender;
  final IsolateRef replyTo;
  final String payload;
  final String type;

  _PayloadMsg(this.sender, this.replyTo, this.payload, this.type);

  _PayloadMsg.fromMap(Map<String, dynamic> map)
      : sender = map[_SENDER] != null ? new IsolateRef._fromMap(map[_SENDER]) : null,
        replyTo = map[_REPLY_TO] != null ? new IsolateRef._fromMap(map[_REPLY_TO]) : null,
        payload = map[_PAYLOAD],
        type = map[_TYPE];


  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _PAYLOAD_MSG,
      _SENDER: sender?._toMap(),
      _REPLY_TO: replyTo?._toMap(),
      _PAYLOAD: payload,
      _TYPE: type
    };
  }

  String toString() => '[_PayloadMsg: sender=$sender, replyTo=$replyTo, payload=$payload, type=$type]';

}

class _IsolateSpawnMsg {

  final int correlationId;
  final Uri path;
  final EntryPoint entryPoint;
  final Uri uri;
  final Map<String, dynamic> properties;

  _IsolateSpawnMsg(this.correlationId, this.path, this.entryPoint, this.uri, this.properties);

  _IsolateSpawnMsg.fromMap(Map<String, dynamic> map)
      : correlationId = map[_CORRELATION_ID],
        path = Uri.parse(map[_PATH]),
        entryPoint = map[_ENTRY_POINT],
        uri = map[_URI],
        properties = map[_PROPERTIES];

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_SPAWN_MSG,
      _CORRELATION_ID: correlationId,
      _PATH: path?.toString(),
      _ENTRY_POINT: entryPoint,
      _URI: uri,
      _PROPERTIES: properties
    };
  }

  String toString() => '[_IsolateSpawnMsg: correlationId=$correlationId, path=$path, entryPoint=$entryPoint, properties=$properties]';

}

class _IsolateSpawnedMsg {

  final int correlationId;
  final IsolateRef isolateRef;
  final String error;

  _IsolateSpawnedMsg(this.correlationId, this.isolateRef, this.error);

  _IsolateSpawnedMsg.fromMap(Map<String, dynamic> map)
      : correlationId = map[_CORRELATION_ID],
        isolateRef = map[_ISOLATE_REF] != null ? new IsolateRef._fromMap(map[_ISOLATE_REF]) : null,
        error = map[_ERROR];

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_SPAWNED_MSG,
      _CORRELATION_ID: correlationId,
      _ISOLATE_REF: isolateRef?._toMap(),
      _ERROR: error
    };
  }

  String toString() => '[_IsolateSpawnedMsg: correlationId=$correlationId, isolateRef=$isolateRef, error=$error]';

}

class _IsolateLookUpMsg {

  final int correlationId;
  final Uri path;

  _IsolateLookUpMsg(this.correlationId, this.path);

  _IsolateLookUpMsg.fromMap(Map<String, dynamic> map)
      : correlationId = map[_CORRELATION_ID],
        path = Uri.parse(map[_PATH]);

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_LOOK_UP_MSG,
      _CORRELATION_ID: correlationId,
      _PATH: path?.toString()
    };
  }

  String toString() => '[_IsolateLookUpMsg: correlationId=$correlationId, path=$path]';

}

class _IsolateLookedUpMsg {

  final int correlationId;
  final Uri path;
  final IsolateRef isolateRef;

  _IsolateLookedUpMsg(this.correlationId, this.path, this.isolateRef);

  _IsolateLookedUpMsg.fromMap(Map<String, dynamic> map)
      : correlationId = map[_CORRELATION_ID],
        path = Uri.parse(map[_PATH]),
        isolateRef = map[_ISOLATE_REF] != null ? new IsolateRef._fromMap(map[_ISOLATE_REF]) : null;

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_LOOKED_UP_MSG,
      _CORRELATION_ID: correlationId,
      _PATH: path?.toString(),
      _ISOLATE_REF: isolateRef?._toMap()
    };
  }

  String toString() => '[_IsolateLookedUpMsg: correlationId=$correlationId, path=$path, isolateRef=$isolateRef]';

}

class _IsolateUpMsg {

  final IsolateRef isolateRef;

  _IsolateUpMsg(this.isolateRef);

  _IsolateUpMsg.fromMap(Map<String, dynamic> map)
      : isolateRef = map[_ISOLATE_REF] != null ? new IsolateRef._fromMap(map[_ISOLATE_REF]) : null;

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_UP_MSG,
      _ISOLATE_REF: isolateRef._toMap()
    };
  }

  String toString() => '[_IsolateUpMsg: isolateRef=$isolateRef]';

}

class _IsolateShutdownRequestMsg {

  static const _IsolateShutdownRequestMsg INSTANCE = const _IsolateShutdownRequestMsg();

  const _IsolateShutdownRequestMsg();

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_SHUTDOWN_REQUEST_MSG
    };
  }

  String toString() => '[_IsolateShutdownRequestMsg]';

}

class _IsolateReadyForShutdownMsg {

  static const _IsolateReadyForShutdownMsg INSTANCE = const _IsolateReadyForShutdownMsg();

  const _IsolateReadyForShutdownMsg();

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _ISOLATE_READY_FOR_SHUTDOWN_MSG
    };
  }

  String toString() => '[_IsolateReadyForShutdownMsg]';

}

class _NodeShutdownRequestMsg {

  final Duration duration;

  _NodeShutdownRequestMsg(this.duration);

  _NodeShutdownRequestMsg.fromMap(Map<String, dynamic> map)
      : duration = map[_DURATION] != null ? new Duration(milliseconds: map[_DURATION]) : null;

  Map<String, dynamic> toMap() {
    return {
      _MSG_TYPE: _NODE_SHUTDOWN_REQUEST_MSG,
      _DURATION: duration?.inMilliseconds
    };
  }

  String toString() => '[_NodeShutdownRequestMsg: duration=$duration]';

}

part of isolate_cluster;

class _BootstrapIsolateMsg {

  final SendPort sendPortBootstrap;
  final SendPort sendPortPayload;
  final Uri path;
  final EntryPoint entryPoint;
  final Map<String, dynamic> properties;

  const _BootstrapIsolateMsg(this.sendPortBootstrap, this.sendPortPayload,
      this.entryPoint, this.path, this.properties);

  String toString() => '[_BootstrapIsolateMsg: path=$path, properties=$properties]';

}

class _IsolateBootstrappedMsg {

  final SendPort sendPort;

  const _IsolateBootstrappedMsg(this.sendPort);

  toString() => '[_IsolateBootstrappedMsg]';

}

class _PayloadMsg {

  final IsolateRef sender;
  final IsolateRef replyTo;
  final String payload;

  const _PayloadMsg(this.sender, this.replyTo, this.payload);

  String toString() => '[_PayloadMsg: sender=$sender, replyTo=$replyTo, payload=$payload]';

}

class _IsolateSpawnMsg {

  final dynamic correlationId;
  final Uri path;
  final EntryPoint entryPoint;
  final Map<String, dynamic> properties;

  const _IsolateSpawnMsg(this.correlationId, this.path, this.entryPoint, this.properties);

  String toString() => '[_IsolateSpawnMsg: correlationId=$correlationId, path=$path, properties=$properties]';

}

class _IsolateSpawnedMsg {

  final dynamic correlationId;
  final IsolateRef isolateRef;
  final dynamic error;

  const _IsolateSpawnedMsg(this.correlationId, this.isolateRef, this.error);

  String toString() => '[_IsolateSpawnedMsg: correlationId=$correlationId, isolateRef=$isolateRef, error=$error]';

}

class _IsolateLookUpMsg {

  final dynamic correlationId;
  final Uri path;

  const _IsolateLookUpMsg(this.correlationId, this.path);

  String toString() => '[_IsolateLookUpMsg: correlationId=$correlationId, path=$path]';

}

class _IsolateLookedUpMsg {

  final dynamic correlationId;
  final Uri path;
  final IsolateRef isolateRef;

  const _IsolateLookedUpMsg(this.correlationId, this.path, this.isolateRef);

  String toString() => '[_IsolateLookedUpMsg: correlationId=$correlationId, path=$path, isolateRef=$isolateRef]';

}

class _IsolateUpMsg {

  final IsolateRef isolateRef;

  const _IsolateUpMsg(this.isolateRef);

  String toString() => '[_IsolateUpMsg: isolateRef=$isolateRef]';

}

class _IsolateShutdownRequestMsg {

  static const _IsolateShutdownRequestMsg INSTANCE =
  const _IsolateShutdownRequestMsg();

  const _IsolateShutdownRequestMsg();

  String toString() => '[_IsolateShutdownRequestMsg]';

}

class _IsolateReadyForShutdownMsg {

  static const _IsolateReadyForShutdownMsg INSTANCE =
  const _IsolateReadyForShutdownMsg();

  const _IsolateReadyForShutdownMsg();

  String toString() => '[_IsolateReadyForShutdownMsg]';

}

class _NodeShutdownRequestMsg {

  final Duration duration;

  const _NodeShutdownRequestMsg(this.duration);

  String toString() => '[_NodeShutdownRequestMsg: duration=$duration]';

}

part of isolate_cluster;

class _BootstrapIsolateMsg {

  final SendPort sendPortBootstrap;
  final SendPort sendPortPayload;
  final EntryPoint entryPoint;
  final Map<String, dynamic> properties;

  const _BootstrapIsolateMsg(this.sendPortBootstrap, this.sendPortPayload, this.entryPoint, this.properties);

}

class _IsolateBootstrappedMsg {

  final SendPort sendPort;

  const _IsolateBootstrappedMsg(this.sendPort);

}

class _PayloadMsg {

  final String payload;

  const _PayloadMsg(this.payload);

}

class _IsolateUpMsg {

  final IsolateRef isolateRef;

  const _IsolateUpMsg(this.isolateRef);

}

class _ShutdownRequestMsg {

  static const _ShutdownRequestMsg INSTANCE = const _ShutdownRequestMsg();

  const _ShutdownRequestMsg();

}

class _ReadyForShutdownMsg {

  static const _ReadyForShutdownMsg INSTANCE = const _ReadyForShutdownMsg();

  const _ReadyForShutdownMsg();

}

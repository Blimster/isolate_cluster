part of isolate_cluster;

class _BootstrapIsolateMsg {
  final SendPort sendPortBootstrap;
  final SendPort sendPortPayload;
  final Uri path;
  final EntryPoint entryPoint;
  final Map<String, dynamic> properties;

  const _BootstrapIsolateMsg(this.sendPortBootstrap, this.sendPortPayload,
      this.entryPoint, this.path, this.properties);
}

class _IsolateBootstrappedMsg {
  final SendPort sendPort;

  const _IsolateBootstrappedMsg(this.sendPort);
}

class _PayloadMsg {
  final IsolateRef sender;
  final IsolateRef replyTo;
  final String payload;

  const _PayloadMsg(this.sender, this.replyTo, this.payload);
}

class _IsolateUpMsg {
  final IsolateRef isolateRef;

  const _IsolateUpMsg(this.isolateRef);
}

class _IsolateShutdownRequestMsg {
  static const _IsolateShutdownRequestMsg INSTANCE =
      const _IsolateShutdownRequestMsg();

  const _IsolateShutdownRequestMsg();
}

class _IsolateReadyForShutdownMsg {
  static const _IsolateReadyForShutdownMsg INSTANCE =
      const _IsolateReadyForShutdownMsg();

  const _IsolateReadyForShutdownMsg();
}

class _NodeShutdownRequestMsg {
  final Duration duration;

  const _NodeShutdownRequestMsg(this.duration);
}

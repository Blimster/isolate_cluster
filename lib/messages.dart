part of isolate_cluster;

class _BootstrapIsolateMsg {

  final SendPort sendPortBootstrap;
  final SendPort sendPortPayload;
  final EntryPoint entryPoint;
  final Map<String, dynamic> properties;
  final Iterable<IsolateRef> existingRefs;

  const _BootstrapIsolateMsg(this.sendPortBootstrap, this.sendPortPayload, this.entryPoint, this.properties, this.existingRefs);

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

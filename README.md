# Isolate Cluster

A library to build up a cluster of isolates. It provides easy communication between the isolates of the cluster. Furthermore,
an isolate can register itself as a listener for cluster events.

## How to use

Here is a quick overview of the feature implemented so far:

```dart

import 'package:isolate_cluster/isolate_cluster.dart';

main() async {
  // create a single node cluster (the only type currently supported).
  final cluster = new IsolateCluster.singleNode();

  // spawn 3 isolates. you have to provide a top-level function. optionally, properties
  // can be provided. the properties can be accessed from the IsolateContext and the IsolateRef.
  cluster.spawnIsolate(new Uri(path: '/sender/1'), sender, {'msg': 'foo'});
  cluster.spawnIsolate(new Uri(path: '/sender/2'), sender, {'msg': 'bar'});
  IsolateRef receiverRef = await cluster
      .spawnIsolate(new Uri(path: '/receiver'), receiver, {'type': 'receiver'});

  // Look up an isolate by path.
  IsolateRef lookedUp = await cluster.lookupIsolate(new Uri(path: '/receiver'));
  print('[main] looked up isolate: $lookedUp');

  // send a message to the isolate using the IsolateRef.
  receiverRef.send('foo bar', type: 'string');
}

// the entry point for the receiver isolate
receiver(IsolateContext isolateContext) {
  print('[$isolateContext] receiver started');

  // counter for received messages
  int msgCount = 0;

  // register a listener for messages sent to this isolate.
  isolateContext.onMessage.listen((message) async {
    print('[${isolateContext.path}] message received: ${message}');

    // reply message to sender
    message.replyTo?.send('re: ${message.content}');

    if (message.sender != null) {
      // look up sender by path
      IsolateRef lookedUpSender =
          await isolateContext.lookupIsolate(message.sender.path);
      print('[$isolateContext] looked up sender: $lookedUpSender');
    } else {
      IsolateRef spawnedIsolate =
          await isolateContext.spawnIsolate(new Uri(path: "/spawned"), spawned);
      spawnedIsolate.send("hello spawned!");
    }

    // if 3 messages received, shutdown the cluster node.
    msgCount++;
    if (msgCount == 3) {
      isolateContext.shutdownNode();
    }
  });

  // register a shutdown request listener
  isolateContext.shutdownRequestListener = () {
    print('[$isolateContext] shutdown requested!');
    isolateContext.shutdownIsolate();
  };
}

sender(IsolateContext isolateContext) {
  print('[${isolateContext}] sender started');

  // listen to replies from receiver
  isolateContext.onMessage.listen(
      (msg) => print('[${isolateContext.path}] message received: $msg'));

  // register a listener for isolate up events. a reference to the newly spawned isolate is provided to the listener. the listener
  // has access to the properties of the spawned isolate and can send messages to it via the IsolateRef.
  isolateContext.onIsolateUp
      .where((ref) => ref.property('type') == 'receiver')
      .listen((ref) => ref.send(isolateContext.property('msg')));
}

spawned(IsolateContext isolateContext) {
  print('[$isolateContext] spawned started');
  isolateContext.onMessage
      .listen((msg) => print('[$isolateContext] message received: $msg'));
}

```
  
## Roadmap

These feature will be implemented in the (near) future:

- **Supervision:** Every isolate has a supervisor, that will be informed in the case of a failure
- **Multi-Node:** Support for clusters distributed over multiple DartVMs

# Isolate Cluster

A library to build up a cluster of isolates. It provides easy communication between the isolates of the cluster. Furthermore,
an isolate can register itself as a listener for cluster events.

## How to use

Here is a quick overview of the feature implemented so far:

```dart
import 'package:isolate_cluster/isolate_cluster.dart';

main() async {

  // create a single node cluster (the only type of cluster currently supported).
  var cluster = new IsolateCluster.singleNode();

  // spawn 3 isolates. you have to provide a top-level function that accepts an IsolateContext.
  // optionally, properties can be provided. The properties can be accessed from the IsolateContext and
  // the IsolateRef.
  cluster.spawnIsolate(sender, {'id': 1});
  cluster.spawnIsolate(sender, {'id': 2});
  IsolateRef receiverRef = await cluster.spawnIsolate(receiver, {'type': 'receiver'});

  // send a message to the isolate using the IsolateRef. 
  receiverRef.send('message from main isolate');
}

// The entry point for the receiver isolate
receiver(IsolateContext context) {

  print('receiver started');

  // register a listener for messages sent to this isolate.
  context.onMessage.listen((msg) => print('received message: $msg'));

}

sender(IsolateContext context) {

  print('sender started id = ${context.property('id')}');

  // register a listener for isolate up events. a reference to the newly spawned isolate is provided to the listener. the listener
  // has access to the properties of the spawned isolate and can send messages to it via the IsolateRef.
  context.onIsolateUp.where((ref) => ref.property('type') == 'receiver').listen((ref) => ref.send('message from sender ${context.property('id')}'));

}

```
  
## Roadmap

These feature will be implemented in the (near) future:

- Access isolates via paths
- Shutdown of a cluster (currently, when the cluster is created, the DartVM can not stop normally)
- Support for multi-node clusters (start nodes in different DartVMs)

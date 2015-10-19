# Isolate Cluster

A library to build up a cluster of isolates. It provides easy communication between the isolates of the cluster. Furthermore,
an isolate can register itself as a listener for cluster events.

## How to use

Here is a quick overview of the feature implemented so far:

```dart
import 'package:isolate_cluster/isolate_cluster.dart';

main() {

  var cluster = new IsolateCluster.singleNode();
  cluster.spawnIsolate(sender, { 'id': 1});
  cluster.spawnIsolate(sender, { 'id': 2});
  cluster.spawnIsolate(receiver, { 'type': 'receiver'});

}

receiver(IsolateContext context) async {

  print('started receiver');
  context.onMessage.listen((msg) => print('received message: $msg'));

}

sender(IsolateContext context) async {

  print('started sender id = ${context.property('id')}');
  context.onIsolateUp.where((ref) => ref.property('type') == 'receiver').listen((ref) => ref.send('message from sender ${context.property('id')}'));
}

```
  

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

  // spawn 3 isolates. you have to provide a top-level function that accepts an IsolateContext. optionally, properties
  // can be provided. the properties can be accessed from the IsolateContext and the IsolateRef.
  cluster.spawnIsolate(new Uri(path: '/sender/1'), sender, {'msg': 'foo'});
  cluster.spawnIsolate(new Uri(path: '/sender/2'), sender, {'msg': 'bar'});
  IsolateRef receiverRef = await cluster.spawnIsolate(new Uri(path: '/receiver'), receiver, {'type': 'receiver'});

  // Look up an isolate by path.
  IsolateRef lookedUp = await cluster.lookupIsolate(new Uri(path: '/receiver'));
  print('[main] looked up isolate: $lookedUp');

  // send a message to the isolate using the IsolateRef.
  receiverRef.send('foo bar');
}

// The entry point for the receiver isolate
receiver() {
  print('[$context] receiver started');

  // counter for received messages
  int msgCount = 0;

  // register a listener for messages sent to this isolate.
  context.onMessage.listen((message) async {
    print('[${context.path}] message received: ${message}');

    // reply message to sender
    message.replyTo?.send('re: ${message.content}');

    if (message.sender != null) {
      // look up sender by path
      IsolateRef lookedUpSender = await context.lookupIsolate(message.sender.path);
      print('[$context] looked up sender: $lookedUpSender');
    }
    else {
      IsolateRef spawnedIsolate = await context.spawnIsolate(new Uri(path: "/spawned"), spawned);
      spawnedIsolate.send("hello spawned!");
    }

    // if 3 messages received, shutdown the cluster node.
    msgCount++;
    if (msgCount == 3) {
      context.shutdownNode();
    }
  });

  // register a shutdown request listener
  context.shutdownRequestListener = () {
    print('[$context] shutdown requested!');
    context.shutdownIsolate();
  };
}

sender() {
  print('[${context}] sender started');

  // listen to replies from receiver
  context.onMessage.listen((msg) => print('[${context.path}] message received: $msg'));

  // register a listener for isolate up events. a reference to the newly spawned isolate is provided to the listener. the listener
  // has access to the properties of the spawned isolate and can send messages to it via the IsolateRef.
  context.onIsolateUp
      .where((ref) => ref.property('type') == 'receiver')
      .listen((ref) => ref.send(context.property('msg')));
}

spawned() {
  print('[$context] spawned started');
  context.onMessage.listen((msg) => print('[$context] message received: $msg'));
}

```
  
## Roadmap

These feature will be implemented in the (near) future:

- **Supervision:** Every isolate has a supervisor, that will be informed in the case of a failure
- **Multi-Node:** Support for clusters distributed over multiple DartVMs

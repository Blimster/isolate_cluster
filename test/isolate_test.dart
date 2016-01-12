library isolate_test;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:isolate_cluster/isolate_cluster.dart';
import 'package:test/test.dart';

main() {
  IsolateCluster isolateCluster;

  setUp(() {
    isolateCluster = new IsolateCluster.singleNode();
  });

  tearDown(() {
    if (isolateCluster.up) {
      isolateCluster.shutdown();
    }
  });

  test('IsolateRef.send() sends a message to the isolate reference', () async {
    var messages = awaitMessagesInTest(1);
    IsolateRef isolateRef = await isolateCluster.spawnIsolate(new Uri(path: '/foo'), entrypoint);
    isolateRef.send('message');
    expect(messages, completion(orderedEquals(['null,null,message'])));
  });

  test('send() provides references to sender and replyTo, when used by another isolate', () async {
    var messages = awaitMessagesInTest(2);
    await isolateCluster.spawnIsolate(new Uri(path: '/receiver'), receiver);
    await isolateCluster.spawnIsolate(new Uri(path: '/replyTo'), replyTo);
    await isolateCluster.spawnIsolate(new Uri(path: '/sender'), sender);
    expect(messages, completion(unorderedEquals(['replyTo:message','sender:message'])));
  });
}

entrypoint() {
  context.onMessage.listen((msg) async => sendMessageToTest('${msg.sender},${msg.replyTo},${msg.content}'));
}

sender() async {
  context.onMessage.listen((msg) => sendMessageToTest(msg.content));
  IsolateRef replyTo = await context.lookupIsolate(new Uri(path: '/replyTo'));
  IsolateRef receiver = await context.lookupIsolate(new Uri(path: '/receiver'));
  receiver.send('message', replyTo: replyTo);
}

replyTo() async {
  context.onMessage.listen((msg) => sendMessageToTest(msg.content));
}

receiver() async {
  context.onMessage.listen((msg) {
    msg.replyTo.send('replyTo:${msg.content}');
    msg.replyTo.send('sender:${msg.content}');
  });
}

sendMessageToTest(String msg, {int port: 5000}) async {
  var socket = await Socket.connect('localhost', port);
  socket.write(msg);
  socket.close();
}

awaitMessagesInTest(int msgCount, {int port: 5000, int timeout: 3000}) async {
  var messages = [];
  var completer = new Completer();
  var timer = new Timer(new Duration(milliseconds: timeout), () => completer.completeError('timeout after ${timeout}ms'));
  var serverSocket = await ServerSocket.bind('localhost', port);
  serverSocket.listen((socket) {
    socket.transform(UTF8.decoder).listen((data) {
      messages.add(data);
      socket.close();
      serverSocket.close();
      if(messages.length == msgCount) {
        completer.complete(messages);
        timer.cancel();
      }
    });
  });
  return completer.future;
}
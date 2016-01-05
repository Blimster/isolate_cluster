library cluster_test;

import 'package:isolate_cluster/isolate_cluster.dart';
import 'package:test/test.dart';

main() {

  IsolateCluster isolateCluster;

  setUp(() {
    isolateCluster = new IsolateCluster.singleNode();
  });

  tearDown(() {
    isolateCluster.shutdown();
  });

  test('spawnIsolate() returns an IsolateRef', () async {
    IsolateRef isolateRef = await isolateCluster.spawnIsolate(new Uri(path: '/foo'), entryPoint, { 'key': 'value' });
    expect(isolateRef, isNotNull);
    expect(isolateRef.path.path, equals('/foo'));
    expect(isolateRef.property('key'), equals('value'));
  });

  test('if the provided path ends with a /, spawnIsolate() adds 1 segment to the path to make the path unique', () async {
    IsolateRef isolateRef1 = await isolateCluster.spawnIsolate(new Uri(path: '/foo/'), entryPoint);
    IsolateRef isolateRef2 = await isolateCluster.spawnIsolate(new Uri(path: '/foo/'), entryPoint);
    expect(isolateRef1.path.path, startsWith('/foo/'));
    expect(isolateRef1.path.path, isNot(endsWith('/')));
    expect(isolateRef2.path.path, startsWith('/foo/'));
    expect(isolateRef2.path.path, isNot(endsWith('/')));
    expect(isolateRef1.path.path, isNot(equals(isolateRef2.path.path)));
  });

}

entryPoint() {

}
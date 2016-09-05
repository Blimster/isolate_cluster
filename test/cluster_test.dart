library cluster_test;

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

  test('spawnIsolate() spawns an IsolateRef', () async {
    var isolateRef = await isolateCluster.spawnIsolate(new Uri(path: '/foo'), entryPoint, { 'key': 'value'});
    expect(isolateRef, isNotNull);
    expect(isolateRef.path.path, equals('/foo'));
    expect(isolateRef.property('key'), equals('value'));
  });

  test('spawnIsolate() throws an error, if an isolate this the same path already is spawned ', () async {
    var isolateRef = await isolateCluster.spawnIsolate(new Uri(path: '/foo'), entryPoint);
    expect(isolateRef.path.path, equals('/foo'));
    expect(isolateCluster.spawnIsolate(new Uri(path: '/foo'), entryPoint), throwsArgumentError);
  });

  test('spawnIsolate() extends a path by an unique segment, if the path ends with a slash', () async {
    var isolateRef1 = await isolateCluster.spawnIsolate(new Uri(path: '/foo/'), entryPoint);
    var isolateRef2 = await isolateCluster.spawnIsolate(new Uri(path: '/foo/'), entryPoint);
    expect(isolateRef1.path.path, startsWith('/foo/'));
    expect(isolateRef1.path.path, isNot(endsWith('/')));
    expect(isolateRef2.path.path, startsWith('/foo/'));
    expect(isolateRef2.path.path, isNot(endsWith('/')));
    expect(isolateRef1.path.path, isNot(equals(isolateRef2.path.path)));
  });

  test('spawnIsolate() throws an error, if the node is alredy shut down', () async {
    isolateCluster.shutdown();
    expect(isolateCluster.spawnIsolate(new Uri(path: '/foo'), entryPoint), throwsStateError);
  });

  test('lookupIsolate() returns an existing isolate', () async {
    var createdIsolateRef = await isolateCluster.spawnIsolate(new Uri(path: '/foo'), entryPoint);
    var lookedUpIsolateRef = await isolateCluster.lookupIsolate(new Uri(path: '/foo'));
    expect(lookedUpIsolateRef, equals(createdIsolateRef));
  });

  test('lookupIsolate() returns null, if no isolate exists for the given path', () async {
    var lookedUpIsolateRef = await isolateCluster.lookupIsolate(new Uri(path: '/foo'));
    expect(lookedUpIsolateRef, isNull);
  });

  test('lookupIsolate() throws an error, if node is already down', () async {
    isolateCluster.shutdown();
    expect(isolateCluster.lookupIsolate(new Uri(path: '/foo')), throwsStateError);
  });

}

entryPoint(IsolateContext isolateContext) {
}
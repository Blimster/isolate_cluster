import 'package:isolate_cluster/isolate_cluster.dart';

IsolateContext _context;

/**
 * When an isolate is spawned using an URI, the script located by the 
 * give URI has to provide a function main(args, message). The [message] 
 * parameter has to be delegated to the function bootstrapIsolate(). The second
 * argument has to be an [EntryPoint]. It is called after the cluster
 * environment is up and ready to use.    
 */
main(args, message) {
  bootstrapIsolate(message, init);
}

init(IsolateContext context) {
  _context = context;
  print('[$context] spawned!');
}
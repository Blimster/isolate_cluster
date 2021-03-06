# Version 0.17.2+2

- More improvement of pub.dev score

# Version 0.17.2+1

- Improved pub.dev score

# Version 0.17.2

- Fix for breaking change in Dart SDK 2.5.0
- Dart SDK 2.4.0 is required
- Updated dependencies
- Fixed some formatting and comments to increase package scoring

# Version 0.17.1

- Updated SDK constraints to Dart 2 stable

# Version 0.17.0

- Updated upper bound of SDK constraints to <3.0.0

# Version 0.16.3

- Downgraded dependency to package 'uuid' to be compatible with package 'mongo_dart'

# Version 0.16.2

- Dart 2 strong mode alignments.

# Version 0.16.1

- Dart SDK constraint is now >=2.0.0-dev.40.0 to support Dart package analysis.

# Version 0.16.0

- Updates to be Dart 2 compliant.
- BREAKING CHANGE: The return type of EntryPoint is now FutureOr<void>.
- Fixed some documentation issues.

# Version 0.15.1

- Bugfix: Fixed an exception in AllIsolateRefSelector.

# Version 0.15.0

- It is now possible to provide a selector to IsolateRefGroup.send() to support different target selection strategies.

# Version 0.14.0

- BREAKING CHANGE: Renamed class Message to IsolateMessage.
- It is now possible to register an (isolate local) error listener to listen to errors occured (and not catched) in the context of the isolate. If no listener is registered, the error is logged as a WARNING.

# Version 0.13.0

- Now supports Dart strong mode. 

# Version 0.12.0

- Added getter for a local isolate ref to the isolate content. 

# Version 0.11.1

- Bugfix: fixed hard-coded paths

# Version 0.11.0

- Added helper to send messages to a group of isolate of 'same type' using a round robin strategy.
- Added helper to dispatch messages received by an isolate to handlers based on the message type.

# Version 0.10.0

- BREAKING CHANGE: Streams returned by IsolateContext.onMessage and IsolateContext.onIsolateUp are now broadcast streams and start emitting events after the entry point of the isolate was completely executed.

# Version 0.9.0

- Bugfix: Fixed broken argument check in lookupIsolates()

# Version 0.8.0

- BREAKING CHANGE: Changed logger names to be shorter.
- Added lookupIsolates() to look up all isolates of a given path.

# Version 0.7.0

- A message to an isolate can now have a correlationId. 

# Version 0.6.0

- BREAKING CHANGE: The getter isolateContext was not able to provide a valid context in all situations. Instead, the context is now a parameter of the EntryPoint function. 
- It is now possible to spawn an isolate by an URI.
- All messages are now valid to be sent over a SendPort.

# Version 0.5.0

- BREAKING CHANGE: Renamed content to isolateContext
- A message to an isolate can now have a type

# Version 0.4.0

- BREAKING CHANGE: Very isolate now has a path
- Isolates can be looked up by path
- Isolates can spawn and look up other isolates
- Added documentation comments to all parts of the public API.
- Added logging
- Fixed a couple of bugs

# Version 0.3.0

- A cluster can now be stopped by calling IsolateCluster.shutdown()
- Fixed typo in change log (again).

# Version 0.2.1

- Fixed typos in change log.

# Version 0.2.0

- BREAKING CHANGE: Newly spawned isolates no longer receive IsolateUp events for isolates that are already part of the cluster.

# Version 0.1.0

- Initial implementation.

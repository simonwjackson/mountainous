# Mountainous service placement

Mountainous runs persistent applications across a fleet of hosts. Service placement separates an application's identity and state from the machine that runs it.

## Language

**Service**:
An application capability with its own identity, persistent state, and runtime requirements. A service is not its host.

**Placement**:
The chosen host that runs a service. Changing placement does not create a new service or reset its configuration.

**Service state**:
The information a service must retain across restarts and moves. It includes application records, credentials, configuration, queue state, and its network identity.

**Controlled move**:
An operator-approved change of placement that preserves service identity and state. The handoff permits only one active owner and includes a rollback path.
_Avoid_: Automatic failover

**Staging**:
The downloader's work storage for partial downloads, unpacking, and completed files awaiting import. Staging follows the downloader's placement.
_Avoid_: Media library

**Media library**:
Imported media retained for playback. Its location is independent of downloader staging and application placement.
_Avoid_: Staging

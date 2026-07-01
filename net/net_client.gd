extends Node
## Stage 0 placeholder. Stage 7 (M4) implements the real thin REST client
## wrapping Firebase Auth/Firestore/Storage/Functions via HTTPRequest (see
## PROJECT_BRIEF §6.4). All Firebase access must go through this autoload —
## no other script should touch Firebase transport directly.

## Stub. Always returns false until Stage 7 wires up the real Firebase client.
func is_online() -> bool:
	return false

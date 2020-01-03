# System

Actors are the unit of identity in games / scenes. Actors can be added and removed interactively. Behaviors define ... actor behavior. Components exist at the intersection of actors and behaviors. Per-actor-per-behavior properties exist in components. There are also behavior-global properties.

Behaviors are notified of events. Events include "perform", "draw", "collision", ...

Some behaviors are 'tools'. Icons for these behaviors appear in the toolbar if their dependencies are satisfied. Components for these behaviors only exist at actors that are currently 'selected' and only while the tool is selected in the toolbar.

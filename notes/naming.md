---
title: Naming
---

## What is named?

* Checkpoints
* Fan-in bitmap
* GC bitmap

## Terms

-------    ---------- 
Function   A node in the execution graph, containing particular user defined function and incoming and outgoing edges 
Instance   An excatly-once execution of a function (potentially backed by more than one invocations) deriving from a specific set of parent functions. The outputs from instances are unique, but functions may appear multiple times during an execution due to, e.g. cycles.
Invocation A particular invocation of a function instance
-------    ---------- 

## Functions

```
def instance_name(function_name: string,
                  iteration: int,
                  branches: Vec<int>,
                  session_id: string):
    ...
```

GC and fan-in bitmap use `${previous_instance_name}.gc` and `${next_instance_name}.fanin` respectively.

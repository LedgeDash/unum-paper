---
title: Garbage Collection
---

Our scheme for providing exactly-once workflow execution ensures that each node
the execution graph invokes the same subsequent nodes with the same inputs even
if it is invoked more the once. It does so by atomically checkpointing the
result of the first run of the user function and always using that checkpoint in
subsequent invocations of the node, regardless of the output of the user function.

This poses a garbage collection challenge. The checkpoints are numerous in a
workflow and only temporally useful, so unum should avoid incurring resource
overhead/charges indefinitely. However, the node producing the checkpoint cannot
know when it is safe to delete the checkpoint without compromising exactly-once
execution, as it cannot guarantee that subsequent invocations of itself are not
outstanding.

However, while the checkpointing node cannot know when the checkpoint is no
longer necessary, subsequent (next) nodes can! Once all subsequent nodes have
produced their own checkpoints, and thus committed to some _particular_ output
of their own, it is safe for them to be invoked again with different inputs as
they will always produce the same output (the checkpoint value).

In other words, we relax the constraint that nodes always output the same value.
Instead, they must output the same value _until_ all subsequent nodes have
committed to their own outputs.

In non-fan-out cases, once a node checkpoints its result, it can delete the
previous checkpoint:

```python
def egress(result):
    result = _checkpoint(result)
    _do_next(result)
    database_delete(prev_checkpoint)
```

Fan-out cases (one parent node with multiple children) are more complicated
because deleting the checkpoint must wait until _all_ children have committed to
an output (by checkpointing). Note that this is similar to a fan-in and unum
repurposes the same technique. Sibling nodes coordinate via an atomic bitmap
that each sets after checkpointing. Any node that reads a full bitmap deletes
the parent's checkpoint. This guarantees that the parent's checkpoint is deleted
_and_ ensures that all siblings have first checkpointed.

```python

def egress(result):
    result = _checkpoint(result)
    _do_next(result)

    completion_bitmap_after = write_bitmap_read_result(fan_out_gc_bitmap, fan_out_index)
    if all_complete(completion_bitmap_after):
        database_delete(prev_checkpoint)
```

Each unum node must know not only about it's subsequent nodes, but also about
its immediate parents and siblings.  Moreover, whether a node is part of a
fan-out pattern, how big that fan-out is, and which index in the bitmap
represents it are all _dynamic information_ (branching in the parent node, and
map both can result in different numbers of invokees or different patterns).
Finally, a node may be part of multiple patterns: it may be the resul of a
_fan-in_ from multiple nodes, each of which may also have fanned-out to other
nodes. As a result, this graph information is passed by an invoking node in the
unum request payload to each subsequent node.

```rust
struct RequestPayload {
    header: {
        is_fan_out: bool,
        gc_bitmap: optional "${workflow_id}/${node_name}.gc",
        sibling_idx: optional int,
    },
    user_value: Blob,
}
```

So an _invoked_ node receives in it's request, a list of payloads (one from each
parent), each with the above format---including meta-data about the checkpoint.

```python
def egress(request, result):
    result = _checkpoint(result)
    _do_next(result)

    for checkpoint_name in request.payloads:
        payload = database_read(checkpoint_name) # this will have already been read in ingress
        if payload.is_fan_out:
            completion_bitmap_after = write_bitmap_read_result(payload.gc_bitmap, payload.user_value)
            if all_complete(completion_bitmap_after):
                database_delete(checkpoint_name)
        else:
            database_delete(checkpoint_name)
```

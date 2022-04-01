---
title: Exactly-Once Workflow Execution
---

FaaS platforms guarantee at-least once execution of individual functions. If the
machine running a function instance crashes, or the network is partitioned, for
example, that instance may never complete. FaaS platforms ensure that at-least
one such instance _does_ complete for every function invocation. It may run
several instances concurrently or retry execution if an instance does not return
a result after a certain timeout. However, this also means that a invocation may
result in _more than_ one execution of a particular function and, because
functions may not be deterministic, this can result in multiple results for the
same invocation.

One of the benefits of an orchestrator is to provide _exactly-once_ execution
semantics for a _workflow_. While individual functions within a workflow may
execute more than once, an orchestrator chooses which single result of these
executions to use as input to downstream functions. At the end of the workflow,
it produces exactly one final result.

Because orchestrators are a centralized service that interpose on
all communication between workflow stages and are solely responsible for moving
a workflow state machine forward, providing _exactly-once_ workflow semantics is
straightforward---though doing so in a fault-tolerant and scalable manner may
require serious engineering efforts.

A key challenge for Unum is to provide the same semantics in a decentralized
manner. Moreover, because failures and, thus, retries are the exception, not the
rule, Unum should provide these semantics without expensive
coordination---function instances should be able to proceed without blocking to
avoid unnecessary resource usage and cost in the common case.


  * What's the "trick"? What's the insight?
    * Functions can run multiple times and yield different results due to
      non-determinism or operations with side-effects (e.g. reading a timestamp,
      fetching dynamic data from the web, generating a random number, etc)
    * A _workflow_ has exactly-once semantics as long as there is one result
      from the entire workflow that results from using _one_ output at every
      node in the workflow graph. For example, a fan-out node that passes its
      results to _multiple_ other nodes (e.g. a map) might run multiple times
      and result in different outputs each time, but each subsequent node in the
      fan-out must run with the same output as its input.
    * The key idea is to ensure that once a workflow node has committed to a
      particular output by invoking any subsequent nodes, any concurrent or
      future instances of the function will use the same output, regardless of
      the result of their user function.
  * Unum achieves this by atomically checkpointing the result of the user
    computation before invoking next nodes. If a checkpoint already exists, that
    means a concurrent instance has already completed and may have invoked a
    subsequent node, and the current node uses the value in the checkpoint as its output instead.
  * Unum relies on the datastore providing some form of an atomic add operation
    where writing to a key succeeds only if the key does not yet exist. Many
    FaaS datastores provide exactly such an operation, but the same semantics
    can be achieved using versioned writes (as is the case in Unum's
    implementation for S3) or using single-key transactions.

Listing XYZ (below) shows pseudo code for Unum's egress responsible for exactly once semantics.

```python
checkpoint_name = f'{workflow_id}/{function_name}-unumIndex-{unumIndex}'

def egress(result):
    if not datastore_atomic_add(checkpoint_name, result):
      result = datastore_get(checkpoint_name)
    _do_next(result)
    
def _do_next(result)
    for f in next_functions:
        faas.async_invoke(f, result)
        
```

Unum employs a simple optimization that avoids running user code if a checkpoint
already exists. In `ingress`, Unum reads the checkpoint key and, if it exists,
uses its value to bypass running user code:

```python
checkpoint_name = f'{workflow_id}/{function_name}-unumIndex-{unumIndex}'

def ingress():
    result = datastore_get(checkpoint_name):
    if result:
        _do_next(result)
    else:
        egress(function.handle())
```



## Fault-tolerance

When there are no faults, unum runs the function runs its user code, writes the
results to a checkpoint and invokes the downstream functions.

If the function crashes after user code completes but before creating the
checkpoint, the retry execution will not find an existing checkpoint and proceed
as though it is the first execution.

If the function crashes after creating a checkpoint, subsequent retry executions
will find the checkpoint either during `ingress`, in which case it skips user
code or after running user code in `egress`. In both cases, unum uses the
checkpoint value (rather than a newly computed result from running user code) to
invoke downstream functions

If the function crashes after invoking some or all of the downstream functions,
the retry will similarly use the existing checkpoint as its output and try to
invoke all downstream function again. Note that this is safe and satisfies the
exactly-once semantics because the downstream functions are invoked with
identical input and Unum's deduplication mechanism works to ensure only one
result is produced by the downstream functions as if they only execute once.

Lastly, duplicate executions can happen without faults. For instance, the FaaS
engine can incorrectly determine an invocation crashed and retry the function.
This case is identical to the previous scenario where a function crashes after
invoking all downstream functions, and Unum can therefore still ensure
exactly-once semantics.

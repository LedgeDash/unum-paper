---
title: Exactly-Once Workflow Execution
---

FaaS platforms guarantee at-least-execution of individual functions. If the
machine running a function instance crashes, or the network is partition, for
example, that instance may never complete. FaaS platforms ensure that at-least
one such instance _does_ complete for every function invocation. It may run
several instances concurrently or retry execution if an instance does not return
a result after a certain timeout. However, this also means that a invocation may
result in _more than_ one execution of a particular function and, because
functions may not be deterministic, this can result in multiple results for the
same invocation.

One of the benefits of an orchestrator is to provide _exactly-one_ execution
semantics for a _workflow_. While individual functions within a workflow may
execute more than once, an orchestrator chooses which single result of these
executions to use as input to downstream functions. At the end of the workflow,
it uses exactly one final result.

Because centralized orchestrators are a centralized service that interpose on
all communication between workflow stages and are solely responsible for moving
a workflow state machine forward, providing _exactly-once_ workflow semantics is
straightforward---though doing so in a fault-tolerant manner and scalably may
require  a serious engineering effort.

A key challenge for Unum is to provide the same semantics in a decentralized
manner. Moreover, because failures and, thus, retries are the exception, not the
rule, Unum should provide these semantics without expensive
coordination---function instances should be able to proceed without blocking to
avoid unnecessary resource usage and cost in the common case.

---

  * What's the "trick"? What's the insight?
    * Functions can run multiple times and yield different results due to
      non-determinism or operations with side-effects (e.g. reading a timestamp,
      fetching dynamic data from the web, generating a random number, etc)
    * A _workflow_ has exactly-once semantics as long as there is one result
      from the entire workflow that results from using _one_ output at every
      node in the workflow DAG. For example, a fan-out node that passes its
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
    subsequent node, and the current node uses this output instead.
  * Unum relies on the datastore providing some form of an atomic add operation
    where writing to a key succeeds only if the key does not yet exist. Many
    FaaS datastores provide exactly such an operation, but the same semantics
    can be achieved using versioned writes (as is the case in Unum's
    implementation for S3) or using single-key transactions.

Listing XYZ (below) shows pseudo code for Unum's egress responsible for exactly once semantics.

```python
checkpoint_name = "${workflow_id}/${function_name}-${unumIndex}"

def egress(result):
    if not datastore_atomic_add(checkpoint, result):
      result = datastore_get(checkpoint)
    _do_next(result)
    
def _do_next(result)
    for f in next_functions:
        faas.async_invoke(f, result)

def ingress():
    result = datastore_get(checkpoint_name):
    if result:
        _do_next(result)
    else:
        egress(function.handle())
        
```

Unum employs a simple optimization that avoids running user code if an output
already exists. In `ingress`, Unum reads the checkpoint key and, if it exists,
uses its value to bypass running user code.

* Cases:
  * No retries
  * Retry with failure before checkpoint
  * Retry with failure after checkpoint but before invoking
  * Retry with failure after invoking some/all next nodes
  * (Retry with no failure, i.e., an unnecessary retry, is the same as the last one above)

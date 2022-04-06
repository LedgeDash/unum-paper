---
title: Fan-in / Aggregation
---

Aggregation is an important and common pattern in applications that allows
computation on the outputs of many upstream tasks. For example, to build an
index of a large corpus, the application might process chunks in parallel and
aggregate the results at the end.

Aggregation in FaaS applications involves many upstream functions and one
aggregation function. When all upstream branches complete, their outputs are
passed into the aggregate function in a particular order and format.

To achieve this functionality, consensus is needed on when all inputs to the
aggregation function is ready and what the input values are. 

Additionally, the aggregate function should only start when all upstream
branches have completed. Because,

1. It avoids idle-billing when the aggregate function is waiting for upstream
   branches to finish.
2. Starting an aggregation function to wait for upstream branches' output is
   often not possible on many FaaS platforms due to the lack of direct
   addressing of individual function instances. Sending data to a particular
   function instance is often considered an anti-pattern to the event-driven
   design of FaaS.

An orchestrator supports aggregation by having all functions return outputs to
it. The orchestrator then formats (for instance, Step Functions uses an ordered
list) the outputs of all branches and invokes the aggregation function.

Due to this centralized design where the orchestrator interposes on all
communication (receiving results and initiating invocations), the orchestrator
serves as the synchronization point and consensus mechanism where it dictates
when all the values are ready and what the values are. An orchestrator can
invoke the aggregation function when it receives the output from all upstream
branches, and thus avoids idle-billing.



However, depending on the implementation, orchestrators fan-in support can
impose restrictions. For example, as the currently most popular serverless
orchestrator, AWS Step Functions

1. Cannot retry individual branches. If any one of the branches fails, the
   entire `Map` or `Parallel` state fails and all branches are stopped
   immediately.
2. Restricts the expressiveness of fan-in patterns (or pipeline parallelism?).
   That is, you can only fan-in all branches of a `Map` or `Parallel` state. You
   cannot, for instance, aggregate the adjacent branches in a reversed-tree
   pattern.

Unum supports the same semantics without a centralized process and removes the
retry and expressiveness restrictions.

In Unum, branches in fan-in reaches consensus on when all outputs are ready and
what the values are in a decentralized way. We piggybacks on the checkpointing
mechanism in ensuring exactly-once semantics. Each branch creates a unique
checkpoint file that's guaranteed to be the same value for a particular workflow
execution. The existence of a checkpoint signifies the completion of its
function, and each function can access the checkpoint of any other functions in
the same application.

In practice, the input payload to each branch contains its index in the fan-out
and the size of the fan-out. For instance, the 1st branch in a map of 3 `encode`
functions will receive the following payload

```json
{
    "Data": {
        "Source": "http",
        "Value": {
            "bucket": "excamera-input",
            "key":"chunk-0"
        }
    },
    "Session": "9dd5548",
	"Fan-out": {
        "Type": "Map",
        "Index": 0,
        "Size": 3
    }
}
```

This function will create a checkpoint named `9dd5548/encode-unumIndex-0` where
`encode` is its function name and `0` is its `Index` number in the `Fan-out`
field from the input payload. Unum's exactly-once semantics guarantee that once
`9dd5548/encode-unumIndex-0` is created, its values does not change for the
entire workflow execution. Thus, consensus is reached on what the final output
value of the 1st branch is.

Moreover, the 1st `encode` function knows that to invoke the aggregation
function, checkpoints with the name `9dd5548/encode-unumIndex-1` and
`9dd5548/encode-unumIndex-2` must also exist. Similarly, the 2nd and 3rd
`encode` functions knows to verify the existence of the other `encode`
functions' checkpoints before invoking the aggregation function. Thus, the
consensus on when all inputs to the aggregation function is ready is determined
by the existence of upstream branches' checkpoints.



Additionally, Unum provides consensus on who the last-to-finish branch is, so that in the absence of faults, the aggregation function is only invoked *once* by the last-to-finish branch. Unum uses an atomic bitmap that returns its values immediately after an update. Each branch sets the bit at its index to 1 and then checks the updated value of the bitmap, all in a single atomic operation. In the absences of faults and retries, only the last-to-finish branch will read an all-1's bitmap and therefore invoke the aggregation function.

The first-to-finish branch will create the bitmap using the same conditional create operation for checkpoints. Subsequent branch will update and read the bitmap in one atomic operation.

The last-to-finish branch will invoke the aggregation function by passing in the names of the checkpoints of all branches in an ordered list. In the previous example, the aggregation function will be invoked with:

```json
{
    "Data": {
        "Source": "dynamodb",
        "Value": ["9dd5548/encode-unumIndex-0", "9dd5548/encode-unumIndex-1", "9dd5548/encode-unumIndex-2"]
    },
    "Session": "9dd5548"
}
```

The Unum runtime on the aggregation function then reads from the 3 checkpoints, and passes the values of the checkpoints as a list to the user code.

```python
checkpoint_name = f'{workflow_id}/{function_name}-unumIndex-{unumIndex}'
fan_in_bitmap = f'{next_function_instance_name}'

def egress(result):
    if not datastore_atomic_add(checkpoint_name, result):
        result = datastore_get(checkpoint_name)
    
    completion_bitmap_after = write_bitmap_read_result(fan_in_bitmap, my_index)
    if all_complete(completion_bitmap_after):
        _do_next(expand_names(result))

def _do_next(result)
    for f in next_functions:
        faas.async_invoke(f, result)
        
```

1. The `write_bitmap_read_result()` function, *in one atomic operation*, writes the bitmap by updating the bit at the function instances' index to 1 and then returns the resultant bitmap immediately *after* the write.
2. `write_bitmap_read_result()` happens after checkpointing.
3. In the *absence* of faults, `write_bitmap_read_result()` guarantees that only the last-to-finish instance will see an all-1's bitmap and subsequently invoke the the downstream function.
4. The `write_bitmap_read_result()` operation needs to be idempotent because functions might crash after `write_bitmap_read_result()` and the retry execution will run `write_bitmap_read_result()` again.
   1. As a counter-example, data structures that are not safe to use include atomic counters where each finishing instance increments the counter by 1.
5. The fan in bitmap is named as `'{workflow_id}/{function_name}-*-fan-in'` for map fan-ins, and `'{workflow_id}/{function_name1}-{function_name2}-...-fan-in'` for fan-out fan-ins.
   1. In the case of fan-out, the number of branches, the names of the branches and the order of the branches are known at compile time because they're stored in the Unum configuration (i.e., the IR). Therefore, each branch can create the bitmap with the correct length during `write_bitmap_read_result()` and knows its index to update in the bitmap.
   2. In the case map, the number of branches are not known until runtime. Therefore, we use a `-*-` in the name of the bitmap. However, each branch does know the total number of branches, and its index in the branch at runtime because the information is passed in the input payload (specifically, the `Fan-out` field). Thus, similar to the fan-out scenario, each branch in a map can also create the bitmap during `write_bitmap_read_result()` and knows its index to update in the bitmap.
6. Different from non-aggregation patterns, the invoker passes a list of pointers to the invokee, as opposed to the invoker's result. Unum expands names in the invoker.



## Fault-tolerance

Each branch handles faults independently. 

If a branch crashes during execution, that branch will be retried without affecting other branches.

Similar to exactly-once mechanism, if a branch fails before creating a checkpoint, the retry will run the user code again and write user code result into a checkpoint. If a branch fails after creating a checkpoint but before `write_bitmap_read_result()`, the retry will skip user code and instead use the existing checkpoint as the output. Then, the retry execution will `write_bitmap_read_result()`  and if it sees an all-1's bitmap, invoke the aggregation function.

If the branch fails after `write_bitmap_read_result()`, the retry will similarly use the existing checkpoint as its output, and run `write_bitmap_read_result()` again. This is safe because `write_bitmap_read_result()` is idempotent. Also similarly,  if the retry sees an all-1's bitmap, it will invoke the aggregation function.

If a branch fails after `write_bitmap_read_result()`, its retry might invoke the aggregation function a second time after another successful branch sees the failed branch's completion and invokes the aggregation function. This is also safe and satisfies the exactly-once semantics because the aggregation function is invoked with identical input and Unum's deduplication mechanism works to ensure only one result is produced by the aggregation function as if the function only executed once.

In the case of repeated failure, the failing branch writes its error to a `FINALRESULT` directory and noting the stage it failed at (e.g., did it produce a checkpoint and updating the completion bitmap). It terminates the branch without invoking the aggregation function.


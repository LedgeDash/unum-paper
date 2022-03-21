# Fan-in / Aggregation

Aggregation is an important and common pattern in applications that allows computation on the outputs of many upstream tasks. For example, to build an index of a large corpus, the application might process chunks in parallel and aggregate the results at the end.

Aggregation in FaaS applications involves many upstream functions and one aggregation function. When all upstream branches complete, their outputs are passed into the aggregate function in a particular order and format.

To achieve this functionality, consensus is needed on when all inputs to the aggregation function is ready and what the input values are. 

Additionally, the aggregate function should only start when all upstream branches have completed. Because,

1. It avoids idle-billing when the aggregate function is waiting for upstream branches to finish.
2. Starting an aggregation function to wait for upstream branches' output is often not possible on many FaaS platforms due to the lack of direct addressing of individual function instances. Sending data to a particular function instance is often considered an anti-pattern to the event-driven design of FaaS.



An orchestrator supports aggregation by having all functions return outputs to it. The orchestrator then formats (for instance, Step Functions uses an ordered list) the outputs of all branches and invokes the aggregation function.

Due to this centralized design where the orchestrator mediates all results and invocation, the orchestrator serves as the synchronization point and consensus mechanism where it dictates when all the values are ready and what the values are. An orchestrator can invoke the aggregation function only when receives the output from all upstream branches, and thus avoids idle-billing.



However, depending on the implementation, orchestrators fan-in support can impose restrictions. For example, as the currently most popular serverless orchestrator, AWS Step Functions

1. Cannot retry individual branches. If any one of the branches fails, the entire `Map` or `Parallel` state fails and all branches are stopped immediately.
2. Restricts the expressiveness of fan-in patterns (or pipeline parallelism?). That is, you can only fan-in all branches of a `Map` or `Parallel` state. You cannot, for instance, aggregate the adjacent branches in a reversed-tree pattern.



Unum supports the same semantics without a centralized process and removes the retry and expressiveness restrictions.

In Unum, branches in fan-in reaches consensus on when all outputs are ready and what the values are in a decentralized way. We piggybacks on the checkpoint files in ensuring exactly-once semantics. Each branch creates a unique checkpoint file that's guaranteed to be the same value for a particular workflow execution. The existence of a checkpoint signifies the completion of its function, and each function can access the checkpoint of any other functions in the same application.

In practice, the input payload to each branch contains its index in the fan-out and the size of the fan-out. For instance, the 1st branch in a map of 3 `encode` functions will receive the following payload

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

This function will create a checkpoint named `9dd5548/encode-unumIndex-0` where `encode` is its function name and `0` is its `Index` number in the `Fan-out` field from the input payload. And it knows that to invoke the aggregation function, checkpoints with the name `9dd5548/encode-unumIndex-1` and `9dd5548/encode-unumIndex-2` must also exist.

Unum's exactly-once semantics guarantee that once `9dd5548/encode-unumIndex-0` is created, its values does not change for the entire workflow execution.



Additionally, Unum provides consensus on who the last-to-finish branch is, so that in the absence of faults, the aggregation function is only invoked once by the last-to-finish branch. Unum uses an atomic bitmap that returns its values immediately after an update. Each branch sets the bit at its index to 1 and then checks the updated value of the bitmap. In the absences of faults and retries, only the last-to-finish branch will read an all-1's bitmap and therefore invoke the aggregation function.

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

The Unum runtime on the aggregation function then reads from the 3 checkpoints, and pass the values of the checkpoints as a list to the user code.



```python
checkpoint_name = f'{workflow_id}/{function_name}-unumIndex-{unumIndex}'
fan_in_bitmap = f'{workflow_id}/{function_name}-*-fan-in'

def egress(result):
    if not datastore_atomic_add(checkpoint_name, result):
        result = datastore_get(checkpoint_name)
    
    completion_bitmap_after = mark_complete(fan_in_bitmap, my_index)
    if all_complete(completion_bitmap_after):
        _do_next(expand_names(result))

def _do_next(result)
    for f in next_functions:
        faas.async_invoke(f, result)
        
```

1. The `mark_complete()` function, in one atomic operation, writes the bitmap by updating the bit at the function instances' index to 1 and then returns the resultant bitmap immediately *after* the write.
2. In the *absence* of faults, `mark_complete()` guarantees that only the last-to-finish instance will see an all-1's bitmap and subsequently invoke the the downstream function.
3. The `mark_complete()` operation needs to be idempotent because functions might crash after `mark_complete()` and the retry execution will run `mark_complete()` again.
   1. As a counter-example, data structures that are not safe to use include atomic counters where each finishing instance increments the counter by 1.
4. The fan in bitmap is named as `'{workflow_id}/{function_name}-*-fan-in'` for map fan-ins, and `'{workflow_id}/{function_name1}-{function_name2}-...-fan-in'` for fan-out fan-ins.
   1. In the case of fan-out, the number of branches, the names of the branches and the order of the branches are known at compile time because they're stored in the Unum configuration (i.e., the IR). Therefore, each branch can create the bitmap with the correct length during `mark_complete()` and knows its index to update in the bitmap.
   2. In the case map, the number of branches are not known until runtime. Therefore, we use a `-*-` in the name of the bitmap. However, each branch does know the total number of branches, and its index in the branch at runtime because the information is passed in the input payload (specifically, the `Fan-out` field). Thus, similar to the fan-out scenario, each branch in a map can also create the bitmap during `mark_complete()` and knows its index to update in the bitmap.
5. Different from non-aggregation patterns, the invoker passes a list of pointers to the invokee, as opposed to the invoker's result. Unum expands names in the invoker.



TODO: walkthrough retry and faults.

TODO: more on the expressiveness of Unum's fan-in




---
title: Garbage Collection
---

Non fan-out:

```python
def egress(result):
    result = _checkpoint(result)
    _do_next(result)
    database_delete(prev_checkpoint)
```

Fan-out:

```python
fan_out_bitmap = f'{workflow_id}/{prev_function_name}-*-fan-out'

def egress(result):
    result = _checkpoint(result)
    _do_next(result)

    completion_bitmap_after = write_bitmap_read_result(fan_in_bitmap, $i)
    if all_complete(completion_bitmap_after):
        database_delete(prev_checkpoint)
```

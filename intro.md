---
title: Introduction
---

  * FaaS matters
    * Cloud computing enables application developers to provision small slices of datacenter resources for short periods of time.
      * Virtual machines for hours, minutes and recently seconds
      * Storage in scalable datastores billed per operations and GB/month (in granularities as low as bytes/hour)
    * Two trends:
      * Increasingly fine granularity. FaaS platforms allow applications to
        quickly (within milliseconds) provision containerized workloads for
        milliseconds at a time at fine granularity of compute resource (1/6th of
        a core * 128MB memory). These are typically provisioned automatically in
        response to storage events or end-user invocations via HTTP.
      * Originally FaaS designed for 
      * vertically integrated high-level services, including orchestration.
        * Good because they enable many applications in cost effective manner by sharing resources in application-specific ways.
        * Bad because they are application specific, so inherently _exclude_ applications that don't fit their model.

  * It's hard to build FaaS applications because of complex workflows (fan-in, multiple executions)

  * Centralized orchestrators have been developed/deployed to address these problems
    * Centralize state and workflow execution

  * There are downsides:
    * Orchestrators internally need to handle fault-tolerance, exactly-once
      semantics, etc scalably. This is hard.
      * Scalability bottlenecks in practice
      * High price in practice
    * Centralized, multi-tenant orchestrators limit application flexibility
    * Usually platform specific (e.g., Step Functions for AWS, Google Workflow
      for Google Cloud, durable functions for Azure Functions), making serverless applications even less portable.

  * In this paper we ask "do we _need_ a centralized orchestrator? are complex
    workflow patterns, exactly-once execution and scalability better achieved
    in a decentralized manner?"
    * Answer: they are!
    * Unum is a decentralized orchestration library that runs in-situ with serverless functions:
      * Enables arbitrary workflow graphs, including pipeline, fan-out, and
        fan-in patterns, conditional branching as well as cycles.
      * Ensures that the results of workflow executions are consistent with
        exactly-once execution of each constituent function using a carefully
        design but general-purpose checkpointing scheme.
      * Doesn't "waste" resources: functions terminate as soon as they have no
        work to do and intermediate data (e.g. checkpoints) are removed
        predictably and as soon as possible.
   * Unum applications encode workflow orchestrations using an intermediate representation that assumes portable, basic FaaS and storage operations.
     * IR can be hand-written, or compiled from other workflow representations (e.g., we built and present a compiler for Step Functions)
     * IR can be easily ported to any FaaS platform that supports a few basic
       operations (invoke, atomic add, bit vector set-and-check). We present
       ports to AWS Lambda and Google Cloud
   * Unum runs arbitrary Step Functions (we demonstrate N) and can also
     efficiently express and execute applications that cannot be efficiently
     expressed in Step Functions. Surprisingly, Unum runs these applications as
     fast or faster than Step Functions, scales better, and at up to an order of
     magnitude or more cheaper than on Step Functions, with equivalent semantics
     and fault-tolerance.

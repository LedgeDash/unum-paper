# NSDI '23 review response

## Summary of each reviewer's points

*As concise as possible*



### Reviewer A

Reviewer A's understanding of our research problem and main argument:

> current serverless orchestrators are insufficient because of (1). being centralized and (2). high monetary cost

Reviewer A's high level evaluation:

> targets a real-world problem
>
> achieves an excellent result
>
> the solution is simple and lacks challenge
>
> the execution needs improvement
>
> ​	The paper currently lacks and mis-states a few key things that are foundations of the claimed scientific contribution. I believe an improved execution will greatly strengthen this paper.

Reviewer A's personal feelings:

> I would champion this paper if the execution was better
>
> Despite the above misclaim on centralized services, I still believe the paper has a strong contribution that it provides a huge benefit on cost (the latency benefit is still good, but on its own might not be enough for an NSDI paper). The evaluation should provide more details on this.

Reviewer A's main issues

> I found no evidence to back the important claim that **current orchestration of cloud service is centralized**. 

This is a serious criticism. Because if orchestration is not centralized, our research problem doesn't exist, or at least we've identified the wrong problem.

He elaborates a bit more on this point:

> Note that being external is different from being centralized, and perhaps what confuses you is that these services are external to the serverless worker nodes. If so, it means that a very important claim in the abstract and intro needs to be withdrawn, which is unfortunately a killer.

Review A's other issues on costs benefits:

> The evaluation should provide more details on this. In particular, two questions need to be addressed.
>
> First, what are the further cost details on the Step Functions? For example, what is the per state transition cost and how many state transitions are there? should people use Step Functions at all, if they care about costs?
>
> Second, you should compare the cost of other orchestration techniques, such as gg. This is important as it provides evidence, and a clear positioning of the scientific contribution of Unum: it is the first that can lower the cost of orchestration by up to an order of magnitude. If gg can also reduce cost, then you will have to trim the claim a bit, that Unum is the first to reduce cost of orchestration without deploying extra services. This unfortunately will undermine the contribution of Unum but has to be clear; being unclear hurts more.

Along this line of thinking, Reviewer A points out 3 additional questions on the claimed cost benefits for Unum. The questions are all comparing with alternative approaches. The theme that emerged for me is that (1). the design/architectural differences between Unum and these other approaches pointed out by Reviewer A were not clearly defined in the paper. (2). these other approaches pointed out by Reviewer A were not evaluated against Unum. Reviewer A was primarily concerned with evaluating the monetary costs comparison because he believes costs reduction to be the main contribution of Unum. (1) and (2) combined could mean that we simply failed to consider these alternative approaches, which seriously undermines the scientific contribution of Unum.

> Why didn’t the evaluation show the cost on Google Cloud?
>
> What is the cost of no orchestration (no information on this in Table 4)? Should people always use handcrafted workflow if they want the lowest cost?
>
> What is the cost of using “driver function”? The main drawback claimed by the paper (S2) is that it has the “double billing” issue. This should be backed by the evaluation that it is an actual issue. But it is doubtful as in Figure 6, the User Code Duration’s cost is only a small part.
>

Reviewer A's other issue: design correctness in GC. This is a very specific question

> The current design says “in non-fan-out cases, once a node check-points its result, it can delete the previous checkpoint” (S3.5.1). I think there are corner cases that break the design. Say you have a chain A-B-C, once B has checkpointed its result, it will delete A’s result. However, consider there is a duplicated task of A, named A1, A1 finishes after A’s checkpoint is deleted. Then A1 will create a new checkpoint? There are two problems in this case. 1) how is A1’s new checkpoint garbage collected? 2) What if A1 is non-deterministic and it has a branch in its end, instead of launching B1, A1 launches a totally different node D1? All these cases need to be discussed and covered.

Review A's other issue: clarify on "exactly-once":

> Another design choice that may need revision in discussion is the “exactly once” semantics. I think generally you need to clarify that the “exactly once” semantic cannot be guaranteed if there is an (external) side effect, because the design guarantees the semantic using checkpoints on results, not at launching/execution. I think you mentioned this very late, in related work?

### Reviewer B

Reviewer B's understanding of our main argument:

> This paper proposes using a workflow orchestration library that is embedded into cloud
> serverless functions as an alternative to centralized orchestrators such as AWS Step
> Functions.

Reviewer B's review style gives a list of issues that he identified. 

First,  reviewer B had two questions regarding the fundamental benefits of Unum's approach vs SF's approach. The frist question is about scalability, the second is about parallelism. But both questions seem to focus on the ***performance*** aspect of the design difference, namely, how do Unum's design ***fundamentally*** improve performance (whether it's scalability or parallelism) over SF.

> Explain why embedded orchestration can inherently scale better. Define what you mean by "scalability" in the context of serverless workflows. Clarify what limitations current orchestration services have regarding scalability. Address scalability in the evaluation section.

> Demonstrate through your evaluation the fundamental benefits of decentralized (function-based) vs. centralized (server-based) orchestration. Not differences that arise from implementation but inherent difference to either approach. For instance, you get benefits from increased parallelism in the execution of serverless functions.  But why can't Step Functions achieve the same amount of parallelism?

In relations to performance, we don't argue that it's fundamentally impossible for orchestrators to achieve the same level of performance and scalability. You need repeat the work of building, scaling and maintaining yet-another performance-critical service. Unum demonstrate that the same functionality is achievable by building on top of existing services. And those services are already highly scalable. Future improvements to underlying services automatically improve orchestration performance.

Application-level orchestration/building on existing services not only has performance benefits, but also afford more flexibilty to users. This is similar to kernel vs application space argument. Having a functionality in the userspace allows users to choose and change the interface and implementation. Moving functionality to userspace does run the risk of reducing performance, therefore, in Unum, we pay close attention to showing that performance is not degraded and in fact it's improved.



Second, Reviewer B's issue centers around fault-tolerance and exactly-once guarantee. The first question is why do you need exactly-once guarantee. The second is how unum handle's retarts. Both questions need to consider in relation to Reviewer B's point that "AWS Lambda does not even guarantee at-least-once execution, that is, it will perform a number of retries if a function fails but not indefinitely".

>  Justify the importance of exactly-once execution.

> Expand on your claims that you are able to run workflows with the same fault-tolerance. For example, how do you handle restarts. 

> Moreover, AWS Lambda does not even guarantee at-least-once execution, that is, it will perform a number of retries if a function fails but not indefinitely.

*This relates to both restarts and exactly-once guarantee.* 

Third, Reviewer B questions the necessity of affording more flexibility to application in the area of orchestration, asking for a concrete example. This is a very fair question because papers such as exokernel arose from real pain due to the lack of flexibility on the part of applications to implement what they need. Are there similar cases in serverless orchestration?

> Present a compelling, concrete example of an application that requires more flexibility than afforded by orchestration services.



### Reviewer C

Reviewer C's understanding of our research problem and our main argument. Or the main thing that's different about Unum

> Unum is a decentralized orchestration service for serverless functions. Rather than relying on a fault-tolerance coordinator to manage a task execution graph, it maintains integrity of the graph execution through the atomicity guarantees available in cloud storage services like DynamoDB and Firestone.
>
> It seems like a key insight is that many operations that normally would require a centralized coordination service can instead be replaced with atomic operations at the storage layer.

Reviewer C

> What does it assume about the storage layer. For example, would Amazon’s S3, which has fairly weak consistency semantics, be sufficient to run Unum? S4 discusses some of these details, but it would have been nice to summarize this sooner in the paper.

Seems that clarifying the requirements of storage systems *earlier* would be sufficient to satisfying Reviewer C.

Not sure whether adding S3 discussion would be allowed. 



Reviewer C had the same question about restarts:

> In S3.3, I understood how the checkpointing mechanism prevents corruption from duplicate executions, but how are failed functions themselves restarted?



Reviwer C had 2 additional requests for evaluation

> However, I was disappointed that GCP was only considered for cost, and that performance results were not included.

>  I also would have also liked to see how well Unum can handle failures in the evaluation. Introducing some simulated failures, and comparing recovery to Step Functions, would improve the paper.

Finally 3 detailed comments:

> In table 2, does map allow batching of multiple items? Is efficient to pass one at a time to a function? Could FanIn be renamed to reduce?

I don't understand this question. If Lambda supports a batch `invoke`, Unum can also batch. Otherwise, what does batch even mean in this context?

Why would you rename FanIn to reduce?

> In S3.2, is there anything special or different about these ops versus a traditional serverless orchestrator design? Do the ops help in anyway to support a decentralized design?

This is a fair criticism. We didn't explain why we picked the operations we did, nor did we explain that these are the common operations that orchestrators support. Arguing that these are the exhaustive list of operations needed, ever, for all workflows is not realistic. However, we should at least say that they are in fact *all* the patterns supported by STep Functions and maybe that our purpose is to demonstrate that it's possible to support these operations in a decentralized manner. There isn't anything about these patterns that specially support a decentralized design. These are the patterns commonly used by applications, supported by Step Functions, and we're demonstrating that they can be implemented in decentralized ways.

> In S5.2.3, could Unum support preloading in the future? How would this work?

ExCamera achieves preloading by coalescing functions. The application code for multiple stages are packaged into a single zip that runs in the same Lambda function instance, namely the same VM. Unum doesn't preclude applications from being written this way. But Unum itself doesn't have a way to add preloading if the application doesn't have it. Unum also doesn't have a way to preload data into a FaaS function if the FaaS engine does not provide an API to do so.

### Reviwer D

Reviewer D's comments are a bit more chaotic than the other reviewers. My interpretation is that most of D's issues are about decentralization's benefits over centralization. This is similar to B's issues. Namely, we claim that decentralization is so beneficial, but is it really? The following text are examples with concrete details:

> the paper should also do an honest recount of why there has not been a pressing need for a decentralized workflow orchestration solution.

If decentralization is so good, why haven't people even tried it?

> While there is a cost to running a central orchestrator, that cost is often absorbed/compensated as the application using the serverless functions is serving as the orchestrator.

Maybe centralization is not that problematic after all

> Moreover a centralized coordinator can allow dynamic workflow execution, whereas Unum is constrained to static compilation of workflows.

And centralization has some benefits too

> There is more proof required before making a sweeping claim such as "Leveraging decentralized orchestration, rather than centralized services can help performance, resource usage, flexibility, and portability across cloud providers."

Again, I think the problem is what is decentralization's fundamental benefits over centralization.

> Is this the first decentralized serverless workflow system? It seems so. Then the paper should make a bolder claim for it

This suggestion is about clarifying the contribution. And clarifying decentralization's fundamental benefits over centralization can help greatly in collaboration with stating that we're the first to decentralize workflow.



> While the evaluation provides some answers to the question of where the latency and cost improvements in Unum comes from, a finer granularity breakdown and a better presentation of the findings would help.

This is too vague for me. I'm not sure what finer granularity breakdown and better presentation of findings D has in mind exactly.

> The related work discussion on Beldi and Boki should be expanded to provide more context, and discuss how their approaches compare to and complement this approach.

Again, I think the fundamental issue here is how is Unum different compared with related approaches, and why is Unum better. Answering these questions will clarify the contribution.



### Reviewer E

Reviewer E's main issue is about our motivation and claimed benefits of Unum:

> I find your motivation for Unum is weak and vague. 

E argues that:

> > centralized orchestrators also preclude users from making their own trade-offs between available interactions or execution guarantees and performance, resource overhead, scalability and expressiveness.
>
> However, throughout the paper, I didn’t find strong qualitative or quantitative evidence
> that supports this statement.

Specifically, E disagrees that Unum can relieve cloud providers from the task of developing and maintaining orchestrators because

> who is going to develop the decentralized orchestrator? The users? Or, some third parties? Eventually someone needs to “develop and maintain” the orchestrator, and cloud providers have the best interests to do it. Note that the decentralized orchestrator is more complex than the centralized one. So you are
> essentially increasing the complexity, rather than reducing it.

Also, E disagrees that Unum gives applications more flexibility to do optimization:

> > It is better for developers as it gives applications more flexibility to use more
> > performant, applications-specific orchestration optimizations and makes porting
> > applications between different cloud platforms easier
>
> I’m also not convinced by the more performant, optimization-friendly argument. I don’t
> see from the paper how the decentralized orchestrator can achieve it. In terms of
> portability, it is orthogonal to whether the design is centralized or decentralized. If
> your argument is that Unum provides an independent IR and that’s why it’s more portable.
> Then, the same thing can apply to centralized designs too.

E then deconstructed what his/her understanding of Unum's claimed benefits: 

> Overall, you mentioned four things: (1) execution guarantee, (2) performance (3) resource
> overhead, (4) scalability, and (3) expressive.

On performance, E had two questions:

>  What prevents a centralized orchestrator from achieving high parallelism? You mentioned
> that AWS Step Function limits parallel invocation of concurrent branches; why?

>  Intuitively, Unum needs to pay the overhead of checkpointing, which is not needed by a
> centralized design. How does it affect the performance?

On expressiveness, E thinks orchestrators can support the same level of expressiveness, and demand more examples for the lack of expressiveness in orchestrators than ExCamera. 

> For (3) expressiveness, the ExCamera example in which you optimize the data dependency is
> interesting. OTOH, I don’t find it supports your argument too strongly, because it can be
> achieved by a centralized orchestrator also. The key point you are making is that the
> existing orchestrator is hard to customize, which is orthogonal to whether the design is
> centralized or decentralized. Is it fair to say that the expressiveness can be provided
> by a centralized design also (by providing more fine-grained control)?
> Besides the ExCamera example, what are the other limitations of expressiveness of
> existing orchestrators?

On scalability, E is confused by what we mean and didn't see evidence in the evaluation. 

> For (4) scalability, what are you referring to? It's not evaluated or discussed.



Next, he argues that orchestrators typically performs other functionalities: 

> I’d like to point out that orchestrators typically perform many other functionalities,
> such as admission control to prevent overload and permission checks. How do Unum achieve those? One question I have is how to prevent malicious or unauthorized users from
> invoking protected functions? How do you achieve security?

Finally, E had 3 questions;

> How is the frontend compiler implemented? Given that your IR is likely more expressive
> than existing offering; how do you translate existing manifest into your IR?

> What exactly is your IR? What you described is less a complete instruction set but more a
> few APIs. Why do you think your IR is expressive enough?

> What are the evaluation applications? Are those representative serverless workflows? Who
> implemented them? How big are they (e.g., how many functions and what is the length)?
> What are the workloads you use?





Will need to rewrite the 

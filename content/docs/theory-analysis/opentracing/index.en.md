---
title: OpenTracing
---

This post analyzes OpenTracing.

## 1. OpenTracing

{{< figure caption="[Figure 1] Trace" src="images/trace.png" width="800px" >}}

**OpenTracing** defines an API for Distributed Tracing. Here, Distributed Tracing refers to a Profiling and Monitoring technique for MSA (Micro Service Architecture). [Figure 1] shows the Trace, which OpenTracing defines along with the API, based on a Graph and a time axis.

In OpenTracing, a **Trace** refers to the overall flow of processing a single request. Here, the request can be understood as a Client's request. That is, the act of a Client sending a single request to a Service and waiting for a response means, from the OpenTracing perspective, the process of creating a single Trace. A Trace is composed of a DAG (Directed Acyclic Graph) of **Spans**, which are the logical execution units defined in OpenTracing. Generally, a Span represents a single Service. Therefore, the DAG in [Figure 1] can be regarded as the Service Call Graph of an MSA where multiple Services process a single Client request.

### 1.1. Span

Each Span is composed of the following contents.

#### 1.1.1. Operation Name

A Span stores the name of the Operation that the Span performs.

#### 1.1.2. Timestamp

A Span has a Start Timestamp, which is the time information when the Span starts, and a Finish Timestamp, which is the time information when the Span ends.

#### 1.1.3. Reference

Just as Services in an MSA have reference (call) relationships with each other, Spans also have reference relationships with each other. A Span stores the reference relationship information between Spans. OpenTracing defines two types of Span reference relationships: **ChildOf** and **FollowsFrom**. ChildOf refers to a relationship where the parent Span has a dependency on the child Span, so the parent Span waits until the child Span ends and performs the next operation once the child Span ends. In [Figure 1], since Span B and Span C, and Span B and Span C have a ChildOf reference relationship, Span B waits until Span C and D end.

FollowsFrom refers to a relationship where the parent Span has no dependency on the child Span, so the parent Span only calls the child Span and does not wait until the child Span ends. In [Figure 1], Span E and Span F, and Span F and Span G have a FollowsFrom reference relationship. Therefore, it can be seen that Span E ends before Span F ends, and Span F ends before Span G ends.

#### 1.1.4. Tag, Log

A Span stores Tag information, which is an Annotation used when Querying or Filtering Spans. A Tag is composed of a Key-Value Pair. A Span also stores Log information, which is used to store a specific state of an App or an Event of an App. A Log is also composed of a Key-Value Pair.

#### 1.1.5. SpanContext

When a Span calls another Span, it also delivers Data called the SpanContext. The SpanContext generally stores a Trace ID, a Span ID, and Baggage. The Trace ID refers to the ID information of the Trace to which the Span belongs, and the Span ID refers to the ID of the current Span. Therefore, within a single Trace, the Trace ID is maintained even when the Span changes, but the Span ID changes each time the Span changes. The Trace ID and Span ID make Distributed Tracing possible by distinguishing each Trace and Span.

Baggage is a space that stores Data that must be shared (delivered) between Spans within a single Trace. Baggage is composed of Key-Value Pairs.

## 2. Protocol

The Protocols that support OpenTracing are [Trace-Context HTTP Headers](https://github.com/w3c/trace-context/tree/main/spec) and [B3 HTTP Headers](https://github.com/openzipkin/b3-propagation). Both Protocols are widely used today.

## 3. References

* OpenTracing Overview : [https://opentracing.io/docs/overview/](https://opentracing.io/docs/overview/)
* OpenTracing Spans : [https://opentracing.io/docs/overview/spans/](https://opentracing.io/docs/overview/spans/)
* OpenTracing Specification : [https://github.com/opentracing/specification/blob/master/specification.md](https://github.com/opentracing/specification/blob/master/specification.md)
* OpenTracing Trace Identifiers RFC : [https://github.com/opentracing/specification/blob/master/rfc/trace-identifiers.md](https://github.com/opentracing/specification/blob/master/rfc/trace-identifiers.md)
* openzipkin/b3-propagation : [https://github.com/openzipkin/b3-propagation](https://github.com/openzipkin/b3-propagation)
* W3C Trace Context Specification : [https://github.com/w3c/trace-context/tree/main/spec](https://github.com/w3c/trace-context/tree/main/spec)

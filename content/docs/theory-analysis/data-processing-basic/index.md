---
title: Data Processing 기초
draft: true
---

## 1. Event Time, Processing Time

{{< figure caption="[Figure 1] Event Time, Processing Time" src="images/event-process-time.png" width="400px" >}}

**Event Time**은 Event 또는 Data가 발생한 시간을 의미하며, **Processing Time**은 발생한 Event 또는 Data가 실제 처리된 시간을 의미한다. Event Time과 Processing Time이 동일하면 좋겠지만, 즉 Event 또는 Data가 생성 되자마자 처리되면 좋겠지만 현실에서는 반드시 Event Time과 Processing Time 사이의 차이가 발생한다. 따라서 Data Processing System은 이러한 시간의 차이를 고려해야한다. [Figure 1]은 Event Time과 Processing Time의 차이를 나타내고 있다.

## 2. Latency, Throughput

**Latency**는 Source로부터 Destination까지 모든 Data가 처리되고 전달된 시간을 의미한다. Client 관점에서는 Data를 요청한 시간부터 Data를 모두 받기까지 걸린 Delay를 의미하기도 한다. **Throuhput**은 특정 Timeframe 동안 전송되는 Data 양을 의미한다. Latency와 Throughput은 Data Processing의 핵심 성능 지표이며, 일반적으로 낮은 Latency와 높은 Throughput을 갖도록 Data Procesing을 과정을 최적화 한다. Data Processing 성능의 경우 Data의 크기가 작을 경우에는 Latency에 더 많은 영향을 받으며, Data의 크기가 커질수록 Throughput에 더 많은 영향을 받는다.

성능 최적화 기법에 따라서 Latency와 Throughput이 동시에 개선될수도 있으며, Latency와 Throughput이 Trade-off 관계를 갖을수도 있다. 예를들어 Data를 압축하면 Network를 통해서 전송해야는 Data 양이 줄어들기 때문에 Latency와 Throughput 모두 개선될 수 있다. 반면에 Batch 형태로 Data를 처리하는 경우 Batch 간격을 늘릴 경우에는 한번에 더 많은 Data를 처리할 수 있기 때문에 Throughput은 향상될 수 있지만, Batch 간격이 늘어남에 따라서 Latency는 증가한다.

## 3. Data Exchange Strategy

{{< figure caption="[Figure 2] Data Exchange Strategy" src="images/data-exchange-strategies.png" width="600px" >}}

Data Processing 과정은 일반적으로 **다수의 Task**로 쪼개져서 순차적으로 분산되어 처리되며, 이에 따라서 다수의 Task 사이에서는 Data 교환이 발생한다. Task 사이의 Data 교환 기법에는 Forward, Broadcast, Key-based, Random 4가지 전략이 존재하며, [Figure 2]는 각 전략을 시각화한 그림을 나타내고 있다.

* Foward : 이전 Task와 다음 Task가 1:1로 Mapping되어 Data를 전달하는 기법이다. 이전 Task와 다음 Task가 동일한 Node에서 동작한다면 Data 전송을 위한 Network 통신이 발생하지 않는 장점을 갖는다.
* Broadcast : 이전 Task의 Data를 일부 또는 모든 다음 Task를 대상으로 전달하는 기법이다. Data양이 급격하게 증가하고 이에 따라서 많은 Network 통신이 발생하기 때문에, 일반적으로는 이용되지 않는 기법이다.
* Key-based : 동일한 Key를 갖는 Data가 동일한 Task에서 동작하는 기법이다.
* Random : 이전 Task의 Data르 임의의 다음 Task에게 전달하는 기법이다.

## 4. Bounded Data, Unbounded Data

**Bounded Data**는 의미 그대로 처리가 필요한 Data가 더 이상 늘어나지 않는 유한한 Data를 의미하며, **Unbounded Data**는 처리가 필요한 Data가 계속 추가되는 무한의 Data를 의미한다. Bounded Data는 Batch Processing 방식으로 Data를 처리하며, Unbounded Data는 Batch Processing 또는 Streaming Processing 방식으로 Data를 처리한다.

## 5. Batch Processing, Streaming Processing

Data 처리 기법은 한정된 Data 또는 특정시간 동안 축적된 Data를 한꺼번에 처리하는 **Batch Processing** 방식과 Data가 발생한 시점에 가능하면 빠르게 Data를 처리하는 **Streaming Processing** 두가지 방식이 존재한다.

**Batch Processing**은 의미 그대로 한정된 Data를 또는 특정시간 동안 축적된 Data를 한꺼번에 처리하는 방식을 의미한다. 이와 반면에 **Streaming Processing**은 Data가 생성되면 생성된 Data를 축적시키지 않고 실시간 또는 준실시간 이내로 처리하는 방식을 의미한다. 이러한 특징때문에 Batch Processing은 일반적으로 Throughput이 높은편이며, Streaming Processing은 Latency가 낮은편이다.

### 5.1. Batch Processing

Batch Processing은 축적된 Data를 한꺼번에 처리하는 방식이기 때문에, 일반적으로 Throughput이 높지만 실시간성은 낮은편이다. 이러한 단점으로 인해서 Batch Processing 기반으로 Streaming Data를 처리하는 경우 Batch 주기를 매우 짧게 설정여 처리하는 **Micro Batch Processing** 방식을 이용한다. Batch Processing은 축적된 Data를 처리하는 방식이기 때문에, 일반적으로 Data 처리중에 장애가 발생할 경우에는 축적된 Data를 기반으로 재처리하여 장애를 대비한다.

### 5.2. Streaming Processing

**Streaming Processing**은 Data가 생성되면 생성된 Data를 축적시키지 않고 가능하면 빠르게 Data를 처리하는 방식이기 때문에, 일반적으로 높은 실시간성을 보여주지만 Throughput은 낮은편이다.

## 6. 참조

* [https://www.oreilly.com/radar/the-world-beyond-batch-streaming-101/](https://www.oreilly.com/radar/the-world-beyond-batch-streaming-101/)
* [https://medium.com/@akash.d.goel/stream-processing-fundamentals-d4090f33451d](https://medium.com/@akash.d.goel/stream-processing-fundamentals-d4090f33451d)
* Latency, Throughput : [https://medium.com/@apurvaagrawal_95485/latency-vs-throughput-c6c1c902dbfa](https://medium.com/@apurvaagrawal_95485/latency-vs-throughput-c6c1c902dbfa)
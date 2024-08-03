---
title: Data Processing 기초
draft: true
---

## 1. Event Time, Processing Time

## 2. Latency, Throughput

**Latency**는 Source로부터 Destination까지 모든 Data가 처리되고 전달된 시간을 의미한다. Client 관점에서는 Data를 요청한 시간부터 Data를 모두 받기까지 걸린 Delay를 의미하기도 한다. **Throuhput**은 특정 Timeframe 동안 전송되는 Data 양을 의미한다. Latency와 Throughput은 Data Processing의 핵심 성능 지표이며, 일반적으로 낮은 Latency와 높은 Throughput을 갖도록 Data Procesing을 과정을 최적화 한다. Data Processing 성능의 경우 Data의 크기가 작을 경우에는 Latency에 더 많은 영향을 받으며, Data의 크기가 커질수록 Throughput에 더 많은 영향을 받는다.

성능 최적화 기법에 따라서 Latency와 Throughput이 동시에 개선될수도 있으며, Latency와 Throughput이 Trade-off 관계를 갖을수도 있다. 예를들어 Data를 압축하면 Network를 통해서 전송해야는 Data 양이 줄어들기 때문에 Latency와 Throughput 모두 개선될 수 있다. 반면에 Batch 형태로 Data를 처리하는 경우 Batch 간격을 늘릴 경우에는 한번에 더 많은 Data를 처리할 수 있기 때문에 Throughput은 향상될 수 있지만, Batch 간격이 늘어남에 따라서 Latency는 증가한다.

## 3. Batch Processing, Streaming Processing

## 4. Data Exchange Strategy

## 5. 참조

* [https://www.oreilly.com/radar/the-world-beyond-batch-streaming-101/](https://www.oreilly.com/radar/the-world-beyond-batch-streaming-101/)
* [https://medium.com/@akash.d.goel/stream-processing-fundamentals-d4090f33451d](https://medium.com/@akash.d.goel/stream-processing-fundamentals-d4090f33451d)
* Latency, Throughput : [https://medium.com/@apurvaagrawal_95485/latency-vs-throughput-c6c1c902dbfa](https://medium.com/@apurvaagrawal_95485/latency-vs-throughput-c6c1c902dbfa)
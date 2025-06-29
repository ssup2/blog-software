---
title: Datadog SDK 환경 변수
draft: true
---

## 1. Datadog SDK 환경 변수

Datadog SDK에서는 다음의 환경 변수를 기본적으로 사용한다.

| 환경 변수 | 용도 | Default |
| --- | --- | --- |
| `DD_ENV` | Alpha, Prod와 같은 동작 환경을 지정 | `null` |
| `DD_SERVICE` | Application Service 이름 지정 | Auto Detection |
| `DD_VERSION` | Application의 Version 지정 | `null` |
| `DD_AGENT_HOST` | DataDog Agent의 IP 지정 | `localhost` |
| `DD_TRACE_AGENT_PORT` | DataDog Agent의 Trace Port 지정 | `8126` TCP Port |
| `DD_TRACE_AGENT_URL` | DataDog Agent의 Trace URL 지정 | `unix:///var/run/datadog/apm.socket`가 이용 가능한 경우 `unix:///var/run/datadog/apm.socket` 사용, 그렇지 않으면 `http://localhost:8126` 사용 |
| `DD_DOGSTATSD_PORT` | DataDog Agent의 DogStatsD Port 지정 | `8125` UDP Port |
| `DD_DOGSTATSD_URL` | DataDog Agent의 DogStatsD URL 지정 | `unix:///var/run/datadog/dsd.socket`가 이용 가능한 경우 `unix:///var/run/datadog/dsd.socket` 사용, 그렇지 않으면 `udp://localhost:8125` 사용 |

* `DD_TRACE_AGENT_URL` 환경 변수의 우선 순위가 `DD_AGENT_HOST`, `DD_TRACE_AGENT_PORT` 환경 변수의 우선 순위보다 높다.
* `DD_DOGSTATSD_URL` 환경 변수의 우선 순위가 `DD_DOGSTATSD_PORT` 환경 변수의 우선 순위보다 높다.

### 1.1. DD Trace SDK 환경 변수 지원 현황

Trace 수집을 지원하는 DD Trace SDK에서는 다음의 환경 변수를 지원한다.

| 환경 변수 | Java | Golang | Python | Ruby | NodeJS |
| --- | --- | --- | --- | --- | --- |
| `DD_ENV` | [dd-trace-java v0.48.0 이상](https://github.com/DataDog/dd-trace-java/releases/tag/v0.48.0) | [dd-trace-go v1.24.0 이상](https://github.com/DataDog/dd-trace-go/releases/tag/v1.24.0) | [dd-trace-py v0.36.0 이상](https://github.com/DataDog/dd-trace-py/releases/tag/v0.36.0) | [dd-trace-rb v0.34.0 이상](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.34.0) | [dd-trace-js v0.20.0 이상](https://github.com/DataDog/dd-trace-js/releases/tag/v0.20.0) |
| `DD_SERVICE` | [dd-trace-java v0.48.0 이상](https://github.com/DataDog/dd-trace-java/releases/tag/v0.48.0) | [dd-trace-go v1.24.0 이상](https://github.com/DataDog/dd-trace-go/releases/tag/v1.24.0) | [dd-trace-py v0.36.0 이상](https://github.com/DataDog/dd-trace-py/releases/tag/v0.36.0) | [dd-trace-rb v0.34.0 이상](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.34.0) | [dd-trace-js v0.20.0 이상](https://github.com/DataDog/dd-trace-js/releases/tag/v0.20.0) |
| `DD_VERSION` | [dd-trace-java v0.48.0 이상](https://github.com/DataDog/dd-trace-java/releases/tag/v0.48.0) | [dd-trace-go v1.24.0 이상](https://github.com/DataDog/dd-trace-go/releases/tag/v1.24.0) | [dd-trace-py v0.36.0 이상](https://github.com/DataDog/dd-trace-py/releases/tag/v0.36.0) | [dd-trace-rb v0.34.0 이상](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.34.0) | [dd-trace-js v0.20.0 이상](https://github.com/DataDog/dd-trace-js/releases/tag/v0.20.0) |
| `DD_AGENT_HOST` | dd-trace-java 지원 | [dd-trace-go v1.6.0 이상](https://github.com/DataDog/dd-trace-go/releases/tag/v1.6.0) | [dd-trace-py v0.17.0 이상](https://github.com/DataDog/dd-trace-py/releases/tag/v0.17.0) | [dd-trace-rb v0.18.0 이상](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.18.0) | [dd-trace-js v0.7.0 이상](https://github.com/DataDog/dd-trace-js/releases/tag/v0.7.0) |
| `DD_TRACE_AGENT_PORT` | [dd-trace-java 0.18.0 이상](https://github.com/DataDog/dd-trace-java/releases/tag/v0.18.0) | [dd-trace-go v1.6.0 이상](https://github.com/DataDog/dd-trace-go/releases/tag/v1.6.0) | [dd-trace-py v0.17.0 이상](https://github.com/DataDog/dd-trace-py/releases/tag/v0.17.0) | [dd-trace-rb v0.18.0 이상](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.18.0) | [dd-trace-js 지원](https://github.com/DataDog/dd-trace-js/pull/1403) |
| `DD_TRACE_AGENT_URL` | [dd-trace-java v0.65.0 이상](https://github.com/DataDog/dd-trace-java/releases/tag/v0.65.0) | [dd-trace-go v1.44.0 이상](https://github.com/DataDog/dd-trace-go/releases/tag/v1.44.0) | [dd-trace-py v0.48.0 이상](https://github.com/DataDog/dd-trace-py/releases/tag/v0.48.0) | [dd-trace-rb 1.11.0 이상](https://github.com/DataDog/dd-trace-rb/releases/tag/v1.11.0) | [dd-trace-js v5.32.0 이상](https://github.com/DataDog/dd-trace-js/releases/tag/v5.32.0) |

### 1.2. DogStatsD SDK 환경 변수 지원 현황

Metric 수집을 지원하는 DogStatsD SDK에서는 다음의 환경 변수를 지원한다.

| 환경 변수 | Java | Golang | Python | Ruby | NodeJS |
| --- | --- | --- | --- | --- | --- |
| `DD_ENV` | [java-dogstatsd-client v2.10.0 이상](https://github.com/DataDog/java-dogstatsd-client/pull/107) |[datadog-go v3.5.0 이상](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#350--2020-03-17) | 지원 | 지원 | 지원 |
| `DD_SERVICE` | [java-dogstatsd-client v2.10.0 이상](https://github.com/DataDog/java-dogstatsd-client/pull/107) | [datadog-go v3.5.0 이상](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#350--2020-03-17)| 지원 | 지원 | 지원 |
| `DD_VERSION` | [java-dogstatsd-client v2.10.0 이상](https://github.com/DataDog/java-dogstatsd-client/pull/107) | [datadog-go v3.5.0 이상](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#350--2020-03-17) | 지원 | 지원 | 지원 |
| `DD_AGENT_HOST` | [java-dogstatsd-client v2.8.0 이상](https://github.com/DataDog/java-dogstatsd-client/pull/73) | [datadog-go v2.2.0 이상](https://github.com/DataDog/datadog-go/commit/752af9db25a03efbd07f836b4a6ca7ef6f7209f2) | [datadogpy v0.28.0 이상](https://github.com/DataDog/datadogpy/releases/tag/v0.28.0) | [dogstatsd-ruby-5.6.0 이상](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v5.6.0) | [hot-shots  v6.2.0 이상](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#620-2019-4-10) | [hot-shots v6.2.0 이상](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#620-2019-4-10) |
| `DD_DOGSTATSD_PORT` | [java-dogstatsd-client v2.8.0 이상](https://github.com/DataDog/java-dogstatsd-client/pull/73) | [datadog-go v2.2.0 이상](https://github.com/DataDog/datadog-go/pull/78) | [datadogpy v0.28.0 이상](https://github.com/DataDog/datadogpy/releases/tag/v0.28.0) | [dogstatsd-ruby-5.6.0 이상](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v5.6.0) | [hot-shots v6.2.0 이상](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#620-2019-4-10) |
| `DD_DOGSTATSD_URL` | [java-dogstatsd-client v4.2.1 이상](https://github.com/DataDog/java-dogstatsd-client/pull/217) | [datadog-go v5.3.0 이상](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#560--2024-12-10) | X | [dogstatsd-ruby-5.6.0 이상](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v5.6.0) | X |
---
title: Datadog SDK Environment Variables
---

## 1. Datadog SDK Environment Variables

The Datadog SDK uses the following environment variables by default.

| Environment Variable | Purpose | Default |
| --- | --- | --- |
| `DD_ENV` | Specifies the operating environment such as Alpha, Prod | `null` |
| `DD_SERVICE` | Specifies the Application Service name | Auto Detection |
| `DD_VERSION` | Specifies the Application Version | `null` |
| `DD_AGENT_HOST` | Specifies the IP of DataDog Agent | `localhost` |
| `DD_TRACE_AGENT_PORT` | Specifies the Trace Port of DataDog Agent | `8126` TCP Port |
| `DD_TRACE_AGENT_URL` | Specifies the Trace URL of DataDog Agent | Uses `unix:///var/run/datadog/apm.socket` if available, otherwise uses `http://localhost:8126` |
| `DD_DOGSTATSD_PORT` | Specifies the DogStatsD Port of DataDog Agent | `8125` UDP Port |
| `DD_DOGSTATSD_URL` | Specifies the DogStatsD URL of DataDog Agent | Uses `unix:///var/run/datadog/dsd.socket` if available, otherwise uses `udp://localhost:8125` |

* The priority of the `DD_TRACE_AGENT_URL` environment variable is higher than the priority of the `DD_AGENT_HOST` and `DD_TRACE_AGENT_PORT` environment variables.
* The priority of the `DD_DOGSTATSD_URL` environment variable is higher than the priority of the `DD_DOGSTATSD_PORT` environment variable.

### 1.1. DD Trace SDK Environment Variable Support Status

DD Trace SDKs that support Trace collection support the following environment variables.

| Environment Variable | Java | Golang | Python | Ruby | NodeJS |
| --- | --- | --- | --- | --- | --- |
| `DD_ENV` | [dd-trace-java v0.48.0+](https://github.com/DataDog/dd-trace-java/releases/tag/v0.48.0) | [dd-trace-go v1.24.0+](https://github.com/DataDog/dd-trace-go/releases/tag/v1.24.0) | [dd-trace-py v0.36.0+](https://github.com/DataDog/dd-trace-py/releases/tag/v0.36.0) | [dd-trace-rb v0.34.0+](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.34.0) | [dd-trace-js v0.20.0+](https://github.com/DataDog/dd-trace-js/releases/tag/v0.20.0) |
| `DD_SERVICE` | [dd-trace-java v0.48.0+](https://github.com/DataDog/dd-trace-java/releases/tag/v0.48.0) | [dd-trace-go v1.24.0+](https://github.com/DataDog/dd-trace-go/releases/tag/v1.24.0) | [dd-trace-py v0.36.0+](https://github.com/DataDog/dd-trace-py/releases/tag/v0.36.0) | [dd-trace-rb v0.34.0+](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.34.0) | [dd-trace-js v0.20.0+](https://github.com/DataDog/dd-trace-js/releases/tag/v0.20.0) |
| `DD_VERSION` | [dd-trace-java v0.48.0+](https://github.com/DataDog/dd-trace-java/releases/tag/v0.48.0) | [dd-trace-go v1.24.0+](https://github.com/DataDog/dd-trace-go/releases/tag/v1.24.0) | [dd-trace-py v0.36.0+](https://github.com/DataDog/dd-trace-py/releases/tag/v0.36.0) | [dd-trace-rb v0.34.0+](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.34.0) | [dd-trace-js v0.20.0+](https://github.com/DataDog/dd-trace-js/releases/tag/v0.20.0) |
| `DD_AGENT_HOST` | dd-trace-java supported | [dd-trace-go v1.6.0+](https://github.com/DataDog/dd-trace-go/releases/tag/v1.6.0) | [dd-trace-py v0.17.0+](https://github.com/DataDog/dd-trace-py/releases/tag/v0.17.0) | [dd-trace-rb v0.18.0+](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.18.0) | [dd-trace-js v0.7.0+](https://github.com/DataDog/dd-trace-js/releases/tag/v0.7.0) |
| `DD_TRACE_AGENT_PORT` | [dd-trace-java 0.18.0+](https://github.com/DataDog/dd-trace-java/releases/tag/v0.18.0) | [dd-trace-go v1.6.0+](https://github.com/DataDog/dd-trace-go/releases/tag/v1.6.0) | [dd-trace-py v0.17.0+](https://github.com/DataDog/dd-trace-py/releases/tag/v0.17.0) | [dd-trace-rb v0.18.0+](https://github.com/DataDog/dd-trace-rb/releases/tag/v0.18.0) | [dd-trace-js supported](https://github.com/DataDog/dd-trace-js/pull/1403) |
| `DD_TRACE_AGENT_URL` | [dd-trace-java v0.65.0+](https://github.com/DataDog/dd-trace-java/releases/tag/v0.65.0) | [dd-trace-go v1.44.0+](https://github.com/DataDog/dd-trace-go/releases/tag/v1.44.0) | [dd-trace-py v0.48.0+](https://github.com/DataDog/dd-trace-py/releases/tag/v0.48.0) | [dd-trace-rb 1.11.0+](https://github.com/DataDog/dd-trace-rb/releases/tag/v1.11.0) | [dd-trace-js v5.32.0+](https://github.com/DataDog/dd-trace-js/releases/tag/v5.32.0) |

### 1.2. DogStatsD SDK Environment Variable Support Status

DogStatsD SDKs that support Metric collection support the following environment variables.

| Environment Variable | Java | Golang | Python | Ruby | NodeJS |
| --- | --- | --- | --- | --- | --- |
| `DD_ENV` | [java-dogstatsd-client v2.10.0+](https://github.com/DataDog/java-dogstatsd-client/pull/107) |[datadog-go v3.5.0+](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#350--2020-03-17) | [datadogpy v0.36.0+](https://github.com/DataDog/datadogpy/releases/tag/v0.36.0) | [dogstatsd-ruby-4.8.0+](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v4.8.0) | [hot-shots v9.1.0+](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#910-2022-6-20) |
| `DD_SERVICE` | [java-dogstatsd-client v2.10.0+](https://github.com/DataDog/java-dogstatsd-client/pull/107) | [datadog-go v3.5.0+](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#350--2020-03-17)| [datadogpy v0.36.0+](https://github.com/DataDog/datadogpy/releases/tag/v0.36.0) | [dogstatsd-ruby-4.8.0+](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v4.8.0) | [hot-shots v9.1.0+](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#910-2022-6-20) |
| `DD_VERSION` | [java-dogstatsd-client v2.10.0+](https://github.com/DataDog/java-dogstatsd-client/pull/107) | [datadog-go v3.5.0+](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#350--2020-03-17) | [datadogpy v0.36.0+](https://github.com/DataDog/datadogpy/releases/tag/v0.36.0) | [dogstatsd-ruby-4.8.0+](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v4.8.0) | [hot-shots v9.1.0+](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#910-2022-6-20) |
| `DD_AGENT_HOST` | [java-dogstatsd-client v2.8.0+](https://github.com/DataDog/java-dogstatsd-client/pull/73) | [datadog-go v2.2.0+](https://github.com/DataDog/datadog-go/commit/752af9db25a03efbd07f836b4a6ca7ef6f7209f2) | [datadogpy v0.28.0+](https://github.com/DataDog/datadogpy/releases/tag/v0.28.0) | [dogstatsd-ruby-5.6.0+](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v5.6.0) | [hot-shots v6.2.0+](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#620-2019-4-10) | [hot-shots v6.2.0+](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#620-2019-4-10) |
| `DD_DOGSTATSD_PORT` | [java-dogstatsd-client v2.8.0+](https://github.com/DataDog/java-dogstatsd-client/pull/73) | [datadog-go v2.2.0+](https://github.com/DataDog/datadog-go/pull/78) | [datadogpy v0.28.0+](https://github.com/DataDog/datadogpy/releases/tag/v0.28.0) | [dogstatsd-ruby-5.6.0+](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v5.6.0) | [hot-shots v6.2.0+](https://github.com/brightcove/hot-shots/blob/master/CHANGES.md#620-2019-4-10) |
| `DD_DOGSTATSD_URL` | [java-dogstatsd-client v4.2.1+](https://github.com/DataDog/java-dogstatsd-client/pull/217) | [datadog-go v5.3.0+](https://github.com/DataDog/datadog-go/blob/master/CHANGELOG.md#560--2024-12-10) | Not supported | [dogstatsd-ruby-5.6.0+](https://github.com/DataDog/dogstatsd-ruby/releases/tag/v5.6.0) | Not supported |


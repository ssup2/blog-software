---
title: Kibana Query Language (KQL)
---

This document summarizes Kibana Query Language (KQL).

## 1. Kibana Query Language (KQL)

### 1.1 Terms Query

A query that outputs only documents where the field and value exactly match.

* [Field]:[Value] : Get only documents where value exists in field
  * respose:200 : Get only documents where value 200 exists in response field
  * message:ssup2 : Get only documents where string value "ssup2" exists in message field
  * message:"ssup2 blog" : Get only documents where string value "ssup2 blog" exists in message field

### 1.2. Boolean Query

A query using logical operators not, and, or. You can limit comparison targets and change priority using parentheses.

* not [Field]:[Value] : Get only documents where value does not exist in field
  * not respose:200 : Get only documents where value 200 does not exist in response field
* [Field1]:[Value1] and [Field2]:[Value2] : Get only documents where value1 exists in field1 and value2 exists in field2
  * respose:200 and message:"ssup2" : Get only documents where value 200 exists in response field and string value ssup2 exists in message field
* [Field]:([Value1] or [Value2]) : Get only documents where value1 or value2 exists in field
  * response:(200 or 404) : Get only documents where value 200 exists or value 404 exists in response field

### 1.3. Range Query

A query using comparison operators \>, >=, <, <=.

* * [Field]:[Value]>[Number] : Get only documents where value less than number exists in field

### 1.4. Wildcard Query

A query using wildcard (*).

* [Field]:* : Get only documents where field exists
  * respose:* : Get only documents where response field exists
* [Field]:[Value]* : Get only documents where value starting with "Value" string exists in field
  * message:ssup* : Get only documents where value starting with "ssup" string exists in message field
* [Field]*:[Value] : Get only documents where value exists in field starting with "Field" string
  * mess*:ssup2 : Get only documents where string value "ssup2" exists in field starting with "mess" string

### 1.5. Nested Field Query

A query for nested fields where a field exists inside a field.

* [Field1]:{[Field2]:[Value]} : Get only documents where value exists in field2 inside field1
  * request:{response:200} : Get only documents where value 200 exists in response field inside request field

## 2. References

* [https://www.elastic.co/guide/en/kibana/master/kuery-query.html](https://www.elastic.co/guide/en/kibana/master/kuery-query.html)
* [https://www.elastic.co/guide/en/beats/packetbeat/current/kibana-queries-filters.html](https://www.elastic.co/guide/en/beats/packetbeat/current/kibana-queries-filters.html)


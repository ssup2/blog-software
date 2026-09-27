---
title: GraphQL
---

This post analyzes GraphQL.

## 1. GraphQL

**GraphQL** is a Query language for API Servers. Because it is a **Query language**, it has the advantage of being able to select and obtain only the desired Data, and it also has the advantage of being able to obtain various Data with a single request. It has characteristics very similar to SQL in a DB. It is generally selected and used to overcome the disadvantages of REST APIs.

#### 1.1. Operation Type

GraphQL provides three Operation Types: Query, Mutation, and Subscription.

* **Query** : Retrieves Data.
* **Mutation** : Creates, Updates, and Deletes Data, and retrieves the changed Data.
* **Subscription** : Subscribes to Data changes and receives the changed Data when the Data changes.

#### 1.1.1. Query

```shell {caption="[Query 1] countries name Query", linenos=table}
# Query
query {
  countries {
    name
  }
}

# Result
{
  "data": {
    "countries": [
      {
        "name": "Andorra"
      },
      {
        "name": "United Arab Emirates"
      },
      {
        "name": "Afghanistan"
      },
...
  }
}
```

Query means the **Data retrieval** Operation. [Query 1] shows a simple Query that retrieves `countries`. The `query` string is specified at the very beginning to indicate the Query Operation. A Query has a form very similar to JSON, and Data can be retrieved by **specifying the Fields** to obtain. The result of the Query is output in **JSON format**, and the actual Data is loaded into the `data` Key. Since only the `name` Field of the `countries` Field is specified in [Query 1], it can be seen that only the `name` Field exists in the retrieved Data as well.

```shell {caption="[Query 2] countries name, capital Query", linenos=table}
# Query
query {
  countries {
    name
    capital
  }
}

# Result
{
  "data": {
    "countries": [
      {
        "name": "Andorra",
        "capital": "Andorra la Vella"
      },
      {
        "name": "United Arab Emirates",
        "capital": "Abu Dhabi"
      },
      {
        "name": "Afghanistan",
        "capital": "Kabul"
      },
...
  }
}
```

[Query 2], unlike [Query 1], shows a GraphQL Query that fetches not only the `name` Field of the `countries` Field but also the `capital` Field. Therefore, looking at the Query result, it can be seen that the Data of the `capital` Field is fetched as well as the `name` Field. Just as only the desired Column Data can be fetched in an SQL Select Query, GraphQL also has the advantage of being able to obtain Data by **specifying only the desired Fields**.

```shell {caption="[Query 3] countries name, languages Query", linenos=table}
# Query
query {
  countries {
    name
    languages {
      name
    }
  }
}

# Result
{
  "data": {
    "countries": [
      {
        "name": "Andorra",
        "languages": [
          {
            "name": "Catalan"
          }
        ]
      },
      {
        "name": "United Arab Emirates",
        "languages": [
          {
            "name": "Arabic"
          }
        ]
      },
      {
        "name": "Afghanistan",
        "languages": [
          {
            "name": "Pashto"
          },
          {
            "name": "Uzbek"
          },
          {
            "name": "Turkmen"
          }
        ]
      },
      {
        "name": "Antigua and Barbuda",
        "languages": [
          {
            "name": "English"
          }
        ]
      },
...
  }
}
```

[Query 3] shows a GraphQL Query that also specifies the `languages` Field of the `countries` Field to fetch the `languages` information of `countries` at once. It can be seen that `countries` and `languages` have a 1:N relationship. Just as Data existing in multiple DB Tables can be retrieved at once through an SQL Join Query, GraphQL also has the advantage of being able to **retrieve Data existing in multiple DB Tables at once**.

#### 1.1.2. Mutation

Mutation means the **Data change and changed Data retrieval** Operation, such as Create, Update, and Delete.

#### 1.1.3. Subscription

Subscription means the **Data change Event reception** Operation, and it is GraphQL's implementation of the Pub/Sub Model. When a GraphQL Client requests a Subscription Operation to the GraphQL API Server, the GraphQL API Server sends the changed Data to the GraphQL Client whenever the related Data changes. Through the Subscription Operation, the Client does not have to perform inefficient Polling-based Data change detection. The Subscription Operation uses the **WebSocket** Protocol.

#### 1.2. Introspection

```shell {caption="[Query 4] Field List Query", linenos=table}
# Query
query {
  --schema {
    queryType {
      fields {
        name
        description
      }
    }
    mutationType {
      fields {
        name
        description
      }
    }
    subscriptionType {
      fields {
        name
        description
      }
    }
  }
}

# Result
{
  "data": {
    "--schema": {
      "queryType": {
        "fields": [
          {
            "name": "-entities",
            "description": null
          },
          {
            "name": "-service",
            "description": null
          },
          {
            "name": "countries",
            "description": null
          },
          {
            "name": "country",
            "description": null
          },
          {
            "name": "continents",
            "description": null
          },
          {
            "name": "continent",
            "description": null
          },
          {
            "name": "languages",
            "description": null
          },
          {
            "name": "language",
            "description": null
          }
        ]
      },
      "mutationType": null,
      "subscriptionType": null
    }
  }
}
```

Introspection is a feature that checks the Schema supported by the GraphQL API Server. The Schema can be checked through a Query targeting the `--schema` Field. The reason a GraphQL Client such as [graphiql](https://lucasconstantino.github.io/graphiql-online) can check the Schema provided by the GraphQL API Server is that it obtains the Schema information by utilizing the Introspection feature. [Query 4] shows the queryable Fields for each Operation Type. It can be seen that the Mutation and Subscription Operations, except for the Query Operation, have no queryable Fields.

```shell {caption="[Query 5] Type Query", linenos=table}
# Query
query {
  --schema {
    types {
      name
      description
    }
  }
}

# Result
{
  "data": {
    "--schema": {
      "types": [
        {
          "name": "Boolean",
          "description": "The `Boolean` scalar type represents `true` or `false`."
        },
        {
          "name": "String",
          "description": "The `String` scalar type represents textual data, represented as UTF-8 character sequences. The String type is most often used by GraphQL to represent free-form human-readable text."
        },
        {
          "name": "Country",
          "description": null
        },
        {
          "name": "ID",
          "description": "The `ID` scalar type represents a unique identifier, often used to refetch an object or as key for a cache. The ID type appears in a JSON response as a String; however, it is not intended to be human-readable. When expected as an input type, any string (such as `\"4\"`) or integer (such as `4`) input value will be accepted as an ID."
        },
        {
          "name": "Continent",
          "description": null
        },
...
      }
    }
  }
}
```

[Query 5] shows a Query that retrieves the Types used in the Schema.

## 2. GraphQL Implementation

To implement GraphQL, it is necessary to understand how GraphQL works with HTTP and the concept of the Resolver.

#### 2.1. with HTTP

```shell {caption="[HTTP Request 1] GET Request with GraphQL"}
GET http://api.ssup2.com/graphql?query={hero{name}}
```

GraphQL, like REST APIs, generally uses HTTP. [HTTP Request 1] shows an example of sending a GraphQL Query using the HTTP Protocol. In the case of a typical HTTP Protocol-based REST API, each Resource has a separate URL (Endpoint), but when using GraphQL, a **single URL** is used. In the case of [Request 1], `/graphql` is used as the GraphQL URL. A GraphQL Query is delivered to the API Server using a **Query String** together with the HTTP GET Method.

```shell {caption="[HTTP Request 2] POST Request with GraphQL"}
POST http://api.ssup2.com/graphql
{
  "query": "...",
  "operationName": "mutation",
  "variables": { "myVariable": "someValue", ... }
}
```

In the case of a Mutation or Subscription Operation, the Query and Operation name are specified in the Body together with the HTTP POST Method. [HTTP Request 2] shows an example of a Mutation Operation.

#### 2.2. Resolver

The Resolver plays the role of **obtaining Data from external Data stores** such as a DB and composing the response to a GraphQL Query. Parsing of a GraphQL Query is mostly handled by the GraphQL Library, but the Resolver that fetches the Data must be implemented directly by the API Server developer. When using the HTTP Protocol, the structure is such that the HTTP Handler that first receives the HTTP Request calls the Resolver.

## 3. vs REST API

GraphQL is a technology specialized for Data retrieval compared to REST APIs. This is because, in the case of a REST API, all Data related to a Resource is retrieved and then the necessary Data is extracted and used, whereas in the case of GraphQL, only the necessary Fields can be specified, retrieved, and used. Also, in the case of a REST API, it often happens that Data is retrieved by making multiple requests to multiple URLs and then processed for use, whereas GraphQL can retrieve all the necessary Data in a single request.

Because it is specialized for Data retrieval, the GraphQL API Server mostly plays only the role of a Data store such as a Data Store or Repository, and the Business Logic is performed not by the GraphQL API Server but by the GraphQL Client. Therefore, for Services where the Client's Business Logic is important, it is advantageous to use GraphQL, and when the Business Logic is performed on the Server, it is advantageous to use a REST API.

L7 Proxy Servers such as NGINX provide URL-based Caching techniques, but since GraphQL uses a single URL such as `/graphql`, there is also the disadvantage that the Caching technique of the L7 Proxy Server cannot be used, unlike REST APIs that have a URL for each Resource.

## 4. References

* GraphQL 개념잡기 : [https://tech.kakao.com/2019/08/01/graphql-basic/](https://tech.kakao.com/2019/08/01/graphql-basic/)
* GraphQL 과 Rest API : [https://k0102575.github.io/articles/2020-08/graphql](https://k0102575.github.io/articles/2020-08/graphql)
* GraphQL Mutation 설계하기 : [https://fe-developers.kakaoent.com/2022/220113-designing-graphql-mutation/](https://fe-developers.kakaoent.com/2022/220113-designing-graphql-mutation/)
* GraphQL의 메서드 query, mutation, subscription : [https://kotlinworld.com/331](https://kotlinworld.com/331)
* Query, Mutation : [https://graphql-kr.github.io/learn/queries/](https://graphql-kr.github.io/learn/queries/)
* Subscription : [https://www.daleseo.com/graphql-apollo-server-subscriptions/](https://www.daleseo.com/graphql-apollo-server-subscriptions/)
* with HTTP : [https://graphql-kr.github.io/learn/serving-over-http/](https://graphql-kr.github.io/learn/serving-over-http/)
* Introspection : [https://graphql-kr.github.io/learn/introspection/](https://graphql-kr.github.io/learn/introspection/)
* Introspection : [https://hasura.io/learn/graphql/intro-graphql/introspection/](https://hasura.io/learn/graphql/intro-graphql/introspection/)
* Online Demo : [https://lucasconstantino.github.io/graphiql-online/](https://lucasconstantino.github.io/graphiql-online/)
* Online Demo : [https://docs.github.com/en/graphql/overview/explorer](https://docs.github.com/en/graphql/overview/explorer)

---
title: REST API
---

This article analyzes the REST (Representational State Transfer) API.

## 1. REST API

**REST** stands for Representational State Transfer and is an **Architectural Style** optimized for **distributed System** environments. REST does not define a standard between the Server and the Client, but it defines several characteristics such as **Stateless and Uniform Interface**. Since **HTTP** is the Protocol that best matches these REST characteristics, most REST APIs use HTTP.

### 1.1. Characteristics

The REST characteristics mentioned above are reflected in the REST API as they are.

#### 1.1.1. Stateless

A REST API always performs consistent operations regardless of the State (Context) of the Server and the Client. Therefore, the Server and the Client do not need to keep a Session continuously; they only need to maintain a Session briefly when the REST API is used. Also, when there are multiple Servers for Server LB (Load Balancing), there is no problem even if the Client establishes a Session with a different Server each time it uses the REST API. Thanks to the Stateless characteristic, the relationship between the Server and the Client becomes flexible.

However, because of the Stateless characteristic, the Client must repeatedly send the information it previously sent to the Server every time it calls the REST API. Such repeated information is exchanged in the form of a **Token**, encoded or encrypted. Tokens are currently widely used for Client authentication/authorization. The Client stores the Token received from the authentication/authorization Server. After that, the Client sends the Token to the Server every time it calls the REST API, performing the authentication/authorization procedure each time. Using this approach, in which **the Client maintains and manages the Context**, is also a characteristic of the REST API.

#### 1.1.2. Uniform Interface

A REST API provides a simple and restricted Interface that represents a **Resource** through a **URI** and decides which **operation** to perform on that Resource through an **HTTP Method**. Therefore, a REST API has the advantage that its purpose can be easily understood from the form of the REST API alone.

### 1.2. API

The core elements of a REST API are the URI, which represents a Resource, and the HTTP Method, which indicates what operation to perform on the Resource.

#### 1.2.1. Resource Model

{{< figure caption="[Figure 1] REST API Resource Model" src="images/resource-model.png" width="600px" >}}

[Figure 1] shows the Resource Model of the REST API. A Resource represents a single entity, and a **Collection** means a set of Resources. Another Collection (Sub-collection) can exist under a Resource. Each Resource can be expressed in various forms such as JSON, YAML, and XML. In general, the **JSON** form is used most frequently.

#### 1.2.2. HTTP Method

The following HTTP Methods are used in the REST API. Even for the same Method, the operation differs slightly depending on whether the target is a Resource or a Collection.

* **GET Resource** : Fetches the Resource Data.
* **GET Collection** : Fetches the Data of all Resources under the Collection. The Resources to fetch can be filtered through a Query String.
* **HEAD Resource** : Fetches only the Meta Data (HTTP Header) of the Resource.
* **HEAD Collection** : Fetches only the Meta Data (HTTP Header) of all Resources under the Collection.
* **POST Collection** : Creates a new Resource. It does not have the Idempotence characteristic.
* **PUT Resource** : Updates the entire Resource. It has the Idempotence characteristic.
* **PATCH Resource** : Updates part of the Resource. It has the Idempotence characteristic.
* **DELETE Resource** : Deletes the Resource.
* **OPTION Resource, Collection** : Fetches information about all available HTTP Methods and Options.

#### 1.2.3. URI

```text {caption="[URI 1] REST API URI Example"}
http://restapi.example.com/house/apartments/101
```

The URI of a REST API has a Directory-like structure that matches the Resource Model. A single URI represents either a single Resource or a single Collection, which is a group of Resources. A Resource is expressed in the **singular** form and a Collection is expressed in the **plural** form. The URI in [URI 1] shows a `house` Resource, a Collection named `apartments` under it, and a Resource named `101` under that again.

```text {caption="[URI 2] REST API URI + Query String Example"}
http://restapi.example.com/house/apartments?color=white&floor=20
```

When performing the GET Method on a Collection and the fetched Resources need to be filtered, a Query String is used. [URI 2] shows the URI used to get only the Resources of Apartments that are white and have 20 floors.

#### 1.2.4. PUT vs PATCH

PUT is a Method that updates the entire Resource, while PATCH is a Method that updates only part of the Resource. Because PUT updates the entire Resource, all Data of the Resource must be sent together. In other words, Data that will not actually be updated must also be sent. On the other hand, with the PATCH Method, only the Data to be actually updated needs to be sent.

Assume that an Apartment Resource stores the Data `color=white` and `floor=20`. When the Apartment's color changes to blue and only `color` needs to be changed to `blue`, the PUT Method requires sending the entire Data of the Apartment, such as `color=blue` and `floor=20`. However, with the PATCH Method, only the `color=blue` Data needs to be sent.

## 2. References

* Understanding and Using REST API Properly : [http://meetup.toast.com/posts/92](http://meetup.toast.com/posts/92)
* RESTful API Design - Methods : [http://restful-api-design.readthedocs.io/en/latest/methods.html](http://restful-api-design.readthedocs.io/en/latest/methods.html)
* REST API URI Naming Conventions and Best Practices : [https://restfulapi.net/resource-naming/](https://restfulapi.net/resource-naming/)
* Are Subqueries RESTful? : [https://lornajane.net/posts/2013/are-subqueries-restful](https://lornajane.net/posts/2013/are-subqueries-restful)
* RESTful API Design: PUT vs PATCH : [https://medium.com/backticks-tildes/restful-api-design-put-vs-patch-4a061aa3ed0b](https://medium.com/backticks-tildes/restful-api-design-put-vs-patch-4a061aa3ed0b)

---
title: Directory Service, LDAP
---

Analyzes Directory Service and LDAP (Lightweight Directory Access Protocol) used in Directory Service.

## 1. Directory Service

The first Directory Service was a Data storage that stored information such as location, specifications, and administrators of Network Resources to manage physical Network Resources owned by enterprises. However, as enterprise requirements expanded, its functionality expanded to a Data storage that manages not only Network Resources but also various physical Resources that enterprises need to manage, such as equipment, organizations, and employees. Since employee authentication information can also be stored and managed in Directory Service, authentication services within the company can be built through Directory Service.

Since Directory Service is often used to manage physical Resources where changes rarely occur, it is generally designed to focus on Data Read rather than Data Write. Also, to store various characteristics of physical Resources, it is generally designed to be able to store various Attributes. A representative implementation of Directory Service is LDAP (Lightweight Directory Access Protocol).

## 2. LDAP (Lightweight Directory Access Protocol)

{{< figure caption="[Figure 1] LDAP Schema" src="images/ldap-schema.png" width="450px" >}}

LDAP is literally a lightweight Protocol for Directory Service. LDAP Server manages Data in Tree form. [Figure 1] shows the Schema of LDAP in Tree form. You can see that each Node of the Tree stores one attribute. Available attributes can be checked at [this link](https://docs.bmc.com/docs/fpsc121/ldap-attributes-and-associated-fields-495323340.html). Commonly used attributes are as follows.

* **uid** : User ID
* **cn** : Common Name
* **l** : Location
* **ou** : Organisational Unit
* **o** : Organisation
* **dc** : Domain Component
* **st** : State
* **c** : Country

LDAP does not support Transaction or Rollback. LDAP is specialized for Data Read rather than Data Write. Data held by LDAP Server is generally stored in Binary format, but can be converted to a human-readable format through LDIF (LDAP Data Interchange Format).

## 3. References

* [https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ldap/what-is-a-directory-service](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ldap/what-is-a-directory-service)
* [http://quark.humbug.org.au/publications/ldap/ldap-tut.html](http://quark.humbug.org.au/publications/ldap/ldap-tut.html)
* [https://blog.hkwon.me/use-openldap-part1/](https://blog.hkwon.me/use-openldap-part1/)
* [https://wiki.gentoo.org/wiki/Centralized-authentication-using-OpenLDAP](https://wiki.gentoo.org/wiki/Centralized-authentication-using-OpenLDAP)
* [https://www.linuxjournal.com/article/5505](https://www.linuxjournal.com/article/5505)
* [https://medium.com/happyprogrammer-in-jeju/ldap-%ED%94%84%ED%86%A0%ED%86%A0%EC%BD%9C-%EB%A7%9B%EB%B3%B4%EA%B8%B0-15b53c6a6f26](https://medium.com/happyprogrammer-in-jeju/ldap-%ED%94%84%ED%86%A0%ED%86%A0%EC%BD%9C-%EB%A7%9B%EB%B3%B4%EA%B8%B0-15b53c6a6f26)
* [http://umich.edu/~dirsvcs/ldap/doc/guides/slapd/1.html](http://umich.edu/~dirsvcs/ldap/doc/guides/slapd/1.html)
* [https://docs.bmc.com/docs/fpsc121/ldap-attributes-and-associated-fields-495323340.html](https://docs.bmc.com/docs/fpsc121/ldap-attributes-and-associated-fields-495323340.html)


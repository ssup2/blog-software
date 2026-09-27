---
title: OpenStack Keystone
---

This post analyzes Keystone of OpenStack.

## 1. OpenStack Keystone

{{< figure caption="[Figure 1] Keystone Components" src="images/keystone-component.png" width="900px" >}}

**Keystone** provides RBAC-based Authentication and Authorization in OpenStack, and also provides OpenStack's Service Discovery feature. [Figure 1] shows Keystone's Backends and the Keystone components stored in each Backend. Each component is as follows.

* **Identity Backend** : Stores User and Group information. It is configured using a SQL DB or LDAP. A User means a single person, a single System, or a single Service that uses an OpenStack Service. A Group means a set of multiple Users. Multiple Users can be easily controlled by using a Group.
* **Assignment Backend** : Stores Project, Domain, Role, and Role Assignment information. It is configured using a SQL DB. A Project means a unit for the Isolation and Grouping of Resources such as Servers and Images. In the past, it was referred to as a Tenant in OpenStack. A Domain means a unit for the Isolation and Grouping of Users and Projects. Even if a User name and a Project name are identical, they can be used in a single OpenStack deployment as long as they belong to different Domains. A Role means a set of permissions, and a Role Assignment means the assignment information of a Role. A User or Group can have a different Role for each Project.
* **Policy Backend** : Stores Policy information. It is configured using the Oslo RBAC Engine. A Policy means a set of explicit permissions called Rules. A Role is defined as a set of Rules.
* **Credentials Backend** : Stores Credentials information. It is configured using a SQL DB. Credentials are used for the authentication and authorization of an OpenStack Client (Application) that uses OpenStack Services. Credentials can be created/deleted at any time using Keystone.
* **Token Backend** : Stores Token information. It is configured using a SQL DB or Memcached. A Token is an arbitrary value held by an OpenStack Client that has completed authentication. The OpenStack Client passes the Token value along with its requests to an OpenStack Service to prove that it is an authenticated OpenStack Client. Depending on the Token Type, the Token can also contain authorization information.
* **Endpoint Backend** : Stores Service Endpoint information. It is configured using a SQL DB. A Service Endpoint means the URL through which an OpenStack Client accesses an OpenStack Service.

### 1.1. Authentication, Authorization Components Relations

{{< figure caption="[Figure 2] Keystone Authentication, Authorization Components Relations" src="images/keystone-component-relation.png" width="600px" >}}

[Figure 2] shows the relations of the main authentication/authorization components of Keystone. A Policy is located in the global space outside of Domains. A Role is defined as a set of Rules inside a Policy. A Role either belongs to a particular Domain or is located in the global space outside of Domains. Users, Groups, and Projects belong to a particular Domain. A Group consists of a set of Users. A User or Group can be mapped to have a different Role for each Project.

### 1.2. Service Authentication, Authorization with Keystone

{{< figure caption="[Figure 3] Service Authentication, Authorization with Keystone and Server Side Authorization" src="images/keystone-auth-flow-server-side-authorization.png" width="900px" >}}

{{< figure caption="[Figure 4] Service Authentication, Authorization with Keystone and Client Side Authorization" src="images/keystone-auth-flow-client-side-authorization.png" width="900px" >}}

[Figure 3] and [Figure 4] show the process of performing authentication/authorization using Keystone in OpenStack Services. In both [Figure 3] and [Figure 4], the process in which the OpenStack Client passes a User ID/Password or a Credential to Keystone and obtains a Token is identical. The subsequent process differs depending on the Token Type. Tokens of the UUID or Fernet Type do not contain information for validating the Token or information for authentication and authorization. Therefore, as in [Figure 3], an OpenStack Service that receives a Token from an OpenStack Client or another OpenStack Service must check the validity of the Token and the authorization information through Keystone. This approach is called Server Side Authorization.

Tokens of the PKI or JWT Type contain information for validating the Token and information for authorization. Therefore, as in [Figure 4], an OpenStack Service that receives a Token from an OpenStack Client or another OpenStack Service can check the validity of the Token and the authorization information without the help of Keystone. This approach is called Client Side Authorization.

## 2. References

* GitHub - openstack/keystone: OpenStack Identity (Keystone) : [https://github.com/openstack/keystone](https://github.com/openstack/keystone)
* Identity, Authentication, and Access Management in OpenStack - O'Reilly : [https://www.oreilly.com/library/view/identity-authentication-and/9781491941249/ch01.html](https://www.oreilly.com/library/view/identity-authentication-and/9781491941249/ch01.html)
* Tutorial: What is Keystone and how to install Keystone in OpenStack : [https://blog.flux7.com/blogs/openstack/tutorial-what-is-keystone-and-how-to-install-keystone-in-openstack](https://blog.flux7.com/blogs/openstack/tutorial-what-is-keystone-and-how-to-install-keystone-in-openstack)
* Keystone - OpenStack Identity Service - SlideShare : [https://www.slideshare.net/eprasad/keystone-openstack-identity-service](https://www.slideshare.net/eprasad/keystone-openstack-identity-service)


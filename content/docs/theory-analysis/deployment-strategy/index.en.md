---
title: Deployment Strategy
---

Analyzes various Deployment Strategies.

## 1. Big-Bang Deployment

Big Bang Deployment literally means a technique of deploying the entire App or most of the App at once. Since many changes occur at once, the App cannot be used during the deployment process. Also, since the App cannot be used during the Rollback process when problems occur in the deployed App, App problems greatly affect App Availability. Therefore, Big Bang Deployment is not suitable for Server-side Apps where App Availability is important.

For development environments where App Availability is not a problem, or Apps installed on Local PC that operate independently, Big Bang Deployment can be applied to easily deploy and use Apps.

## 2. Blue-green Deployment

{{< figure caption="[Figure 1] Blue-green Deployment" src="images/blue-green.png" width="800px" >}}

[Figure 1] shows Blue-green Deployment. Blue-green Deployment requires two identical environments where Apps can run. This is to run Old App in one environment and New App in the other environment. Before New App is deployed, LB routes all Packets only to Old App so that all Users use only Old App. When New App deployment and startup preparation is complete, LB is manipulated so that all Users use New App.

If the two environments are configured to share DB, there is no need to consider DB Replication, but if each environment is configured to use a separate DB, Replication must be set up so that Data from Old App DB is copied to New App DB. If Users are set to use New App through LB manipulation, reverse Replication must be set up so that Data from New App DB is copied to Old App DB in preparation for Rollback to Old App.

Blue-green Deployment has the advantage of being able to quickly switch from Old App to New App through LB Routing settings and DB Replication settings, and for the same reason, it has the advantage of enabling fast Rollback. It also has the advantage of being easy to validate New App before providing it to Users since New App runs in the same environment as Old App. However, it has the disadvantage of incurring high costs due to building and operating two identical environments.

### 2.1. vs A/B Testing

A/B Test is a technique for analyzing Apps by running Apps with different configurations or versions in multiple identical environments and comparing results. While it is similar to Blue-green Deployment technique in that it uses multiple identical environments, A/B Testing technique is literally a technique for Testing Apps.

## 3. Canary Deployment

{{< figure caption="[Figure 2] Canary Deployment" src="images/canary.png" width="400px" >}}

[Figure 2] shows Canary Deployment. Canary Deployment is a technique of deploying only some Old Apps to New App to validate New App. Since most Users continue to use Old App and only some Users use New App, even if problems occur in New App, it does not greatly affect Users.

## 4. Rolling Deployment

{{< figure caption="[Figure 3] Rolling Deployment" src="images/rolling.png" width="800px" >}}

[Figure 3] shows Rolling Deployment. Rolling Deployment is a technique of updating Old Apps to New App one by one. Since it is a one-by-one update technique, it has the advantage that App downtime due to updates does not greatly affect Users. However, it has the disadvantage that the more Apps there are, the longer it takes to switch to New App and Rollback to Old App. Generally, a method of deploying New App validated through Canary Deployment using Rolling Deployment to apply New App is often used.

## 5. References

* [https://octopus.com/docs/deployment-patterns/rolling-deployments](https://octopus.com/docs/deployment-patterns/rolling-deployments)
* [https://dev.to/mostlyjason/intro-to-deployment-strategies-blue-green-canary-and-more-3a3](https://dev.to/mostlyjason/intro-to-deployment-strategies-blue-green-canary-and-more-3a3)
* [https://opensource.com/article/17/5/colorful-deployments](https://opensource.com/article/17/5/colorful-deployments)
* [https://blog.christianposta.com/deploy/blue-green-deployments-a-b-testing-and-canary-releases/](https://blog.christianposta.com/deploy/blue-green-deployments-a-b-testing-and-canary-releases/)
* [http://cgrant.io/article/deployment-strategies/](http://cgrant.io/article/deployment-strategies/)


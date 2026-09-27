---
title: GitOps
---

This post analyzes GitOps.

## 1. GitOps

{{< figure caption="[Figure 1] GitOps Pipeline" src="images/gitops-pipeline.png" width="900px" >}}

**GitOps** refers to a technique that utilizes Git not only for App development but also for App Delivery, that is, App deployment. [Figure 1] shows the Pipeline of GitOps. There are two Git Repos: an Application Git Repo that manages the App Code, and a Deployment Git Repo that manages deployment. 

When an App developer commits Code to the Application Git Repo, the Application Git Repo sends a Hook to the Container Image Builder so that a new Container App Image reflecting the committed Code is created. The Container Image Builder creates the Container App Image, pushes the Container App Image to the Container Image Repo, and then delivers the information of the newly created Container App Image to the Config Updater.

The Config Updater reflects the contents of the newly created Container App Image in the Deployment Git Repo and commits them. The Deployment Git Repo delivers a Hook to the Deploy Operator, which is responsible for the actual deployment, so that the newly created Container App Image is actually deployed by the Deploy Operator. It is also possible for the person in charge of App deployment to change the deployment configuration by committing directly to the Deployment Git Repo.

The deployment configuration in the Deployment Git Repo must be defined declaratively, and must be configured so that the Deploy Operator can detect App failures. Only then can the Deploy Operator detect App failures and keep attempting deployment so that the deployment configuration and the actual deployed state match. With GitOps, since the deployment configuration is also managed with Git, it has the advantage that the deployment History is naturally managed as well.

## 2. References

* GitOps - Weaveworks : [https://www.weave.works/technologies/gitops/](https://www.weave.works/technologies/gitops/)
* Automate Kubernetes with GitOps - Weaveworks : [https://www.weave.works/blog/automate-kubernetes-with-gitops](https://www.weave.works/blog/automate-kubernetes-with-gitops)
* GitOps-style continuous delivery with Cloud Build : [https://cloud.google.com/kubernetes-engine/docs/tutorials/gitops-cloud-build](https://cloud.google.com/kubernetes-engine/docs/tutorials/gitops-cloud-build)

---
title: Git Flow
---

This post analyzes Git Flow.

## 1. Git Flow

{{< figure caption="[Figure 1] Git Flow" src="images/git-flow.png" width="700px" >}}

**Git Flow** refers to a Branch strategy that decides how to divide and manage Branches when managing a Project with Git. [Figure 1] shows the Branches used in Git Flow. In Git Flow, Branches are classified into the **Main Branches** of Master and Develop, and the remaining **Supporting Branches** of Feature, Release, and Hotfix. A Main Branch refers to a Branch that exists forever from the start of the Project, and a Supporting Branch refers to a Branch that is created/destroyed as needed. In [Figure 1], the horizontal dotted lines indicate the points at which Supporting Branches are created and removed.

#### 1.1. Main Branch

The roles of the Master Branch and Develop Branch among the Main Branches are as follows.

##### 1.1.1. Master Branch

The Master Branch refers to the Branch that holds the shape of the Project that has been Released (put into Production). Each Commit of the Master Branch is managed with a Tag that carries the name of a Version. In [Figure 1], you can see that a Tag is attached to each Commit of the Master Branch. In general, the Master Branch is Merged with a Release Branch whose Release preparation is complete, or with a Hotfix Branch for quick Bug fixes.

##### 1.1.2. Develop Branch

The Develop Branch, as its name implies, refers to the Branch that holds the shape of the Project under development. Commits related to simple feature improvements/additions, or Bug fix Commits that are not urgent, are all applied to the Develop Branch.

#### 1.2. Supporting Branch

The roles of the Feature, Release, and Hotfix Branches among the Supporting Branches are as follows.

##### 1.2.1. Feature

A Feature Branch, as its name implies, is a Branch derived from the Develop Branch for developing a major feature. When the shape (Code) of the Project currently held by the Develop Branch requires changes to a large portion, or when development takes a long time, creating a Feature Branch and Committing to the Feature Branch is recommended rather than Committing directly to the Develop Branch.

Creating a separate Feature Branch for each major feature to be developed is recommended. [Figure 1] shows the process of developing 2 major features. Accordingly, you can see that 2 Feature Branches named `feature-a` and `feature-b` exist. When development is complete, a Feature Branch is Merged with the Develop Branch and removed, or it can be reused after the Merge with the Develop Branch and used for the next Release.

##### 1.2.2. Release

A Release Branch, as its name implies, is a Branch that holds the shape of the Project to be Released. It is created by deriving from the Develop Branch, and the name of a Release Branch includes the name of the Version to be Released, taking the form `release-[version]`. In [Figure 1], the reason the Release Branch's name is `release-1.0` is that the `release-1.0` Branch was created with the goal of being Released as Version v1.0 after being Merged into the Master Branch.

After a Release Branch is created, Bug fix Commits that are not urgent are recommended to be applied to the Release Branch first rather than to the Develop Branch, and then applied to the Develop Branch afterwards, to first raise the completeness of the Project shape managed in the Release Branch. When Release preparation is complete, the Release Branch is Merged with the Master Branch and removed.

##### 1.2.3. Hotfix

A Hotfix Branch, as its name implies, is a Branch for quick Bug fixes. It is created by deriving from the Master Branch, and the name of a Hotfix Branch includes the name of the Version to be Released, taking the form `hotfix-[version]`. In [Figure 1], the reason the Hotfix Branch's name is `hotfix-0.1.1` is that the `hotfix-0.1.1` Branch was created with the goal of being Released as Version v0.1.1 after being Merged into the Master Branch. The Hotfix Branch is removed after being Merged with the Master Branch.

## 2. References

* A successful Git branching model : [https://nvie.com/posts/a-successful-git-branching-model/](https://nvie.com/posts/a-successful-git-branching-model/)

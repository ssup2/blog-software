---
title: Machine Learning Algorithm Classification
---

Classification and overview of machine learning algorithms.

## 1. Machine Learning Algorithm Classification

Machine learning algorithms are often grouped into four types: supervised learning, unsupervised learning, semi-supervised learning, and reinforcement learning.

### 1.1. Supervised learning

Supervised learning uses **input data together with corresponding labels**. A human provides labels to guide training, hence the name. After training, supervised models are typically used to **predict outcomes** from new inputs, enabling classification and regression.

#### 1.1.1. Classification

Classification algorithms **predict which class (type)** an instance belongs to. For example, to decide whether an image is a cat or a dog, you use a classification algorithm. Training requires **pre-labeled** cat and dog images.

#### 1.1.2. Regression

Regression algorithms **predict a single value from a continuous range**. For example, house prices can vary continuously with many factors, so regression is appropriate. Training uses records that include those factors and the corresponding prices.

### 1.2. Unsupervised learning

Unsupervised learning uses **input data only**, without target labels provided by a human during training. These methods often discover **structure or relationships** in data, leading to clustering or dimensionality reduction.

#### 1.2.1. Clustering

Clustering algorithms **group similar data points**. For example, grouping faces by similarity of features uses clustering.

#### 1.2.2. Dimensionality reduction

Dimensionality reduction **reduces the number of dimensions** in high-dimensional data, often by exploiting relationships among features. Fewer dimensions can shorten training time and sometimes improve performance. Methods fall broadly into **feature selection** and **feature extraction** (here “feature” corresponds to a dimension).

* **Feature selection** : Removing unneeded features.
* **Feature extraction** : Defining new features that summarize multiple original features.

### 1.3. Semi-supervised learning

Semi-supervised learning uses **labels for only some inputs**, not for every example—hence “semi-supervised.” It is often used to support **data labeling**.

#### 1.3.1. Data labeling

Data labeling means assigning labels to data that does not yet have them. When data volume is huge or labels are hard for humans to assign quickly, semi-supervised labeling is common.

If you label only part of the data and then run **unsupervised clustering** together with unlabeled data, labeled and unlabeled points can fall into coherent clusters. Unlabeled points in the same cluster as labeled ones can then inherit those labels.

### 1.4. Reinforcement learning

Reinforcement learning uses **inputs and a criterion for judging outcomes**. The agent learns by trying actions, observing results, and repeating in directions that improve the criterion—hence “reinforcement.”

## 2. References

* [https://www.sas.com/en-gb/insights/articles/analytics/machine-learning-algorithms.html](https://www.sas.com/en-gb/insights/articles/analytics/machine-learning-algorithms.html)
* [https://opentutorials.org/module/4916/28934](https://opentutorials.org/module/4916/28934)
* Supervised learning : [https://aimb.tistory.com/149](https://aimb.tistory.com/149)
* Dimensionality reduction : [https://docs.sangyunlee.com/ml/analysis/undefined-1](https://docs.sangyunlee.com/ml/analysis/undefined-1)

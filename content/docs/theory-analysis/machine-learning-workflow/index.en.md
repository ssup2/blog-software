---
title: Machine Learning Workflow
---

This document summarizes the machine learning workflow.

## 1. Machine Learning Workflow

{{< figure caption="[Figure 1] Machine Learning Workflow" src="images/machine-learning-workflow.png" width="700px" >}}

### 1.1. Data Preparation

Data preparation is the process of preparing data for model training and validation.

* **Data transformation** : Transforming data into a form that is easier to work with and reloading the transformed data.
* **Data cleaning** : Removing or correcting inaccurate data.
* **Data normalization** : When some features have very large variance, scaling them to a range such as 0–1 so that one feature does not dominate learning and others are reflected properly.
* **Data featurization** : Extracting features from data for use in the model. Often existing fields are used as features; it also includes creating new features that are not present in the raw data but are derived from it.
* **Data validation** : Final checks before using featurized data—typically type, range, and shape.
* **Data split** : Splitting validated featurized data into training, validation, and test sets. A common split is roughly 60% training, 20% validation, and 20% test.

### 1.2. Model Training

Model training is the process of building, training, and validating a model using the prepared data.

* **Algorithm selection** : Choosing which machine learning algorithm to use.
* **Model hyperparameter tuning** : Configuring the model based on the chosen algorithm and deciding hyperparameter values.
* **Model training** : Training the configured model to learn its parameters, using the training split from the data split step.
* **Model validation** : Evaluating the trained model on the validation split to review metrics such as accuracy and performance and check whether requirements are met.
* **Model testing** : Evaluating how the validated model behaves on data not used for training or validation, using the test split.

### 1.3. Model Deployment

Deploying and monitoring the model after testing is complete.

* **Model deployment** : Deploying the tested model into production.
* **Model monitoring** : Tracking deployed model metrics such as accuracy and performance.
* **Model retraining** : Retraining the model when monitoring indicates it is needed.

## 2. References

* [https://github.com/solliancenet/Azure-Machine-Learning-Dev-Guide/blob/master/creating-machine-learning-pipelines/machine-learning-pipelines.md](https://github.com/solliancenet/Azure-Machine-Learning-Dev-Guide/blob/master/creating-machine-learning-pipelines/machine-learning-pipelines.md)
* [https://web2.qatar.cmu.edu/~gdicaro/15488/lectures/488-S20-1-Introduction.pdf](https://web2.qatar.cmu.edu/~gdicaro/15488/lectures/488-S20-1-Introduction.pdf)
* [https://lsjsj92.tistory.com/579](https://lsjsj92.tistory.com/579)
* [https://www.kdnuggets.com/2020/07/tour-end-to-end-machine-learning-platforms.html](https://www.kdnuggets.com/2020/07/tour-end-to-end-machine-learning-platforms.html)
* [https://cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning](https://cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning)
* [https://towardsdatascience.com/machine-learning-pipelines-with-kubeflow-4c59ad05522](https://towardsdatascience.com/machine-learning-pipelines-with-kubeflow-4c59ad05522)
* [http://blog.skby.net/%EB%A8%B8%EC%8B%A0%EB%9F%AC%EB%8B%9D-%ED%8C%8C%EC%9D%B4%ED%94%84%EB%9D%BC%EC%9D%B8-machine-learning-pipeline/](http://blog.skby.net/%EB%A8%B8%EC%8B%A0%EB%9F%AC%EB%8B%9D-%ED%8C%8C%EC%9D%B4%ED%94%84%EB%9D%BC%EC%9D%B8-machine-learning-pipeline/)
* [https://towardsdatascience.com/industrializing-ai-machine-learning-applications-with-kubeflow-5687bf56153f](https://towardsdatascience.com/industrializing-ai-machine-learning-applications-with-kubeflow-5687bf56153f)
* Data feature engineering : [http://www.incodom.kr/%EA%B8%B0%EA%B3%84%ED%95%99%EC%8A%B5/feature-engineering](http://www.incodom.kr/%EA%B8%B0%EA%B3%84%ED%95%99%EC%8A%B5/feature-engineering)
* Data cleaning : [https://en.wikipedia.org/wiki/Data-cleansing](https://en.wikipedia.org/wiki/Data-cleansing)
* Machine learning algorithm, model : [https://www.linkedin.com/pulse/difference-between-algorithm-model-machine-learning-yahya-abi-haidar/](https://www.linkedin.com/pulse/difference-between-algorithm-model-machine-learning-yahya-abi-haidar/)
* Model validation, model testing : [https://stats.stackexchange.com/questions/19048/what-is-the-difference-between-test-set-and-validation-set](https://stats.stackexchange.com/questions/19048/what-is-the-difference-between-test-set-and-validation-set)
* Model hyperparameter : [https://medium.com/@f2005636/evaluating-machine-learning-models-hyper-parameter-tuning-2d7076349a6c](https://medium.com/@f2005636/evaluating-machine-learning-models-hyper-parameter-tuning-2d7076349a6c)
* Model parameter, model hyperparameter : [https://machinelearningmastery.com/difference-between-a-parameter-and-a-hyperparameter/](https://machinelearningmastery.com/difference-between-a-parameter-and-a-hyperparameter/)

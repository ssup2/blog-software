---
title: CKS Certificate Exam Summary/Review
---

## 1. Exam Information

* Time
  * 2 hours, 16 problems
* Reference Sites Available
  * Kubernetes
    * https://kubernetes.io/docs/home/
    * https://github.com/kubernetes/
    * https://kubernetes.io/blog/
  * Trivy
    * https://aquasecurity.github.io/trivy/
  * Falco
    * https://falco.org/docs/
  * AppArmor
    * https://gitlab.com/apparmor/apparmor/-/wikis/Documentation
  * Unlike CKA and CKAD, separate tools other than Kubernetes are also used, so it is good to register the above Sites in Bookmarks in advance
  * Other Sites cannot be referenced
* Exam Environment
  * Kubernetes v1.21

## 2. Exam Preparation

* Exam Materials
  * Chrome Browser
  * Chrome Plugin
    * https://chrome.google.com/webstore/detail/innovative-exams-screensh
  * Webcam
  * Microphone
  * Passport
* Exam Environment Check
  * https://www.examslocal.com/ScheduleExam/Home/CompatibilityCheck

## 3. Pre-Exam Verification

* Verify kubectl bash autocompletion
  * https://kubernetes.io/docs/reference/kubectl/cheatsheet/
* Verify tmux operation
  * https://linuxize.com/post/getting-started-with-tmux/

## 4. Commands to Know During the Exam

* Windows Copy
  * ctrl + insert
* Windows Paste
  * shift + insert
* kubectl
  * Check Resource API Version : kubectl api-resources
  * Check Resource Spec/Status : kubectl explain --recursive {resource}
* AppArmor
  * Apply Profile : apparmor_parser {profile_path}
  * Check Profile : aa-status \| grep {profile_name}
* kubesec
  * Scan Resource : kubesec scan {resource}
* Trivy
  * Scan Image : trivy image --severity {UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL} {image_name}
  * Scan Tar Image : trivy image --severity {UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL} --input {image_tar}
* Falco
  * Start Falco : systemctl start falco
  * Change Falco Config : vim /etc/falco/falco.yaml
  * Apply Falco Config Changes : systemctl restart falco
  * Add/Change Falco Rule : vim /etc/falco/falco_rules.local.yaml

## 5. Exam Review

* Kode Cloud practice 2-3 times with concept understanding is essential
  * https://kodekloud.com/courses/certified-kubernetes-security-specialist-cks/
* Killer CKS problems provided when applying for CKS exam must be repeated
  * https://killer.sh/
* Compared to CKA and CKAD, the difficulty is higher, and sufficient practice is recommended

## 6. References

* [https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks)
* [https://velog.io/@jay-side-project/Kubernetes-CKS-%EC%A4%80%EB%B9%84%EA%B3%BC%EC%A0%95-0-CKS-%EC%A4%80%EB%B9%84%EA%B3%BC%EC%A0%95%EC%9D%84-%EC%A4%80%EB%B9%84%ED%95%98%EA%B8%B0](https://velog.io/@jay-side-project/Kubernetes-CKS-%EC%A4%80%EB%B9%84%EA%B3%BC%EC%A0%95-0-CKS-%EC%A4%80%EB%B9%84%EA%B3%BC%EC%A0%95%EC%9D%84-%EC%A4%80%EB%B9%84%ED%95%98%EA%B8%B0)
* [https://lifeoncloud.kr/k8s/killersh/](https://lifeoncloud.kr/k8s/killersh/)


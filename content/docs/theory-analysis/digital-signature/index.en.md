---
title: Digital Signature
---

Analyzes Digital Signature techniques.

## 1. Digital Signature

{{< figure caption="[Figure 1] Digital Signature" src="images/digital-signature.png" width="700px" >}}

Digital Signature technique literally means a technique where a signer guarantees Digital Data by signing it. Digital Signature technique can be divided into two stages: Signing and Verification. Signing literally means the signing stage, where Digital Data is hashed and converted to Binary, then encrypted through the signer's Private Key to obtain Digital Signature. Then, Digital Signature is delivered to the Digital Data recipient along with the original Digital Data.

Verification literally means the stage of verifying whether Digital Data is authenticated Data from the signer. The Digital Data recipient hashes the received Data and converts it to Binary. Also, Digital Signature is decrypted to Digital Data's Binary using the signer's Public Key. If the two Binaries are compared and are identical, the Digital Data recipient can know that the Data is Digital Data guaranteed by the correct signer. This is because if Digital Data is changed or decrypted using someone else's Public Key who is not the signer, the two Binaries will have different values.

## 2. References

* [https://blog.mailfence.com/how-do-digital-signatures-work/](https://blog.mailfence.com/how-do-digital-signatures-work/)


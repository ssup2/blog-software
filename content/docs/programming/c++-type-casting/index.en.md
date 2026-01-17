---
title: C++ Type Casting
---

This document analyzes C++ type casting.

## 1. C++ Type Casting

```cpp {caption="[Code 1] C++ Type Casting", linenos=table}
#include <iostream>
using namespace std;

class CDummy {
  float i,j;
};

class CAddition {
  int x,y;
public:
  CAddition (int a, int b) { x=a; y=b; }
	int result() { return x+y;}
};

int main () {
  CDummy d;
  CAddition* padd;
  padd = (CAddition*) &d;
  cout << padd->result(); // Runtime Error
  return 0;
}
```

C++ can perform type casting using the `()` syntax, just like C. [Code 1] shows type casting between classes using the `()` syntax. In C++, like C, there are no restrictions on type casting between pointers. Therefore, it is possible to put the address of a CDummy instance into a CAddition class pointer through type casting. However, a runtime error occurs when calling the result function because the CDummy instance does not have a result function. To control type casting between classes more precisely, C++ provides four additional type casting syntaxes.

### 1.1. dynamic_cast

```cpp {caption="[Code 2] dynamic_cast Example", linenos=table}
class CBase { virtual void dummy() {} };
class CDerived: public CBase {};

CBase b; CBase* pb;
CDerived d; CDerived* pd;

pb = dynamic_cast<CBase*>(&d);      // OK
pd = dynamic_cast<CDerived*>(&b);   // Error - NULL
```

dynamic_cast is used for **safe** type casting between classes in an **inheritance relationship**. If type casting fails, it sets the target pointer of type casting to NULL. In [Code 2], the first dynamic_cast succeeds because it is upcasting, but the second dynamic_cast fails because it is downcasting, and pd is initialized to NULL.

```cpp {caption="[Code 3] dynamic_cast Example", linenos=table}
class CBase { virtual void dummy() {} };
class CDerived: public CBase {};

CBase* pba = new CDerived;
CBase* pbb = new CBase;
CDerived* pd;

pd = dynamic_cast<CDerived*>(pba); // Success
pd = dynamic_cast<CDerived*>(pbb); // Error - NULL
```

However, safe downcasting can be performed using dynamic_cast on pointers where polymorphism is applied. In [Code 3], since pba is set to point to a CDerived instance using polymorphism, the first dynamic_cast succeeds, but since pbb is set to point to a Base instance, the second dynamic_cast fails.

Since dynamic_cast requires additional information about each instance at runtime, to use dynamic_cast, the compiler must compile the program using the **Run-Time Type Information (RTTI)** option. Also, the parent class must have a virtual function. If the parent class does not have a virtual function, a compile error occurs.

### 1.2. static_cast

```cpp {caption="[Code 4] static_cast Example", linenos=table}
class CBase {};
class CDerived: public CBase {};

CBase * a = new CBase;
CDerived * b = static_cast<CDerived*>(a);
```

static_cast is used for **free** type casting between classes in an **inheritance relationship**. While dynamic_cast requires an RTTI verification process at runtime, causing additional overhead, static_cast only checks class inheritance relationships at compile time, so no additional overhead occurs at runtime. However, developers must directly determine whether downcasting is possible due to polymorphism and write the program accordingly.

### 1.3. reinterpret_cast

```cpp {caption="[Code 5] reinterpret_cast Example", linenos=table}
class A {};
class B {};

A* a = new A;
B* b = reinterpret_cast<B*>(a);
```

reinterpret_cast is used for free type casting between classes that are **not in an inheritance relationship**. In [Code 5], Class A and Class B have no relationship, but an A* type pointer is type cast to B* type using reinterpret_cast.

### 1.4. const_cast

```cpp {caption="[Code 6] const_cast Example", linenos=table}
void print (char * str)
{
  cout << str << endl;
}

int main () {
  const char* c = "const_cast";
  print ( const_cast<char *> (c) );
  return 0;
}
```

const_cast is used to remove the const or volatile attributes of a type. In [Code 6], pointer c of const char* type is type cast to char* using const_cast and used.

## 2. References

* [http://www.cplusplus.com/doc/oldtutorial/typecasting/](http://www.cplusplus.com/doc/oldtutorial/typecasting/)


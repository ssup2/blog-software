---
title: C++ Smart Pointer
---

This document analyzes C++ smart pointers.

## 1. Smart Pointer

```cpp {caption="[Code 1] Smart Pointer Implementation", linenos=table}
#include <iostream>
using namespace std;

template <class T>
class SmartPtr
{
   T *ptr;  // Actual pointer
public:
   // Constructor
   explicit SmartPtr(T *p = NULL) { ptr = p; }

   // Destructor
   ~SmartPtr() { delete(ptr); }

   // Overloading dereferncing operator
   T& operator*() { return *ptr; }

   // Overloding arrow operator
   T* operator->() { return ptr; }
};

int main()
{
    SmartPtr<int> ptr(new int());
    *ptr = 20;
    cout << *ptr;

    return 0;
}
```

Smart pointers are pointers that **automatically delete instances created with the `new` syntax without requiring explicit deletion using the `delete` syntax**, unlike regular pointers. [Code 1] shows a simple smart pointer. The actual pointer inside the smart pointer is initialized and allocated with the smart pointer's constructor, and released with the delete syntax in the destructor. Also, by overriding the `*` and `->` operators, developers can use smart pointers similarly to regular pointers.

Inside the `main()` function, the `ptr` smart pointer points to an instance allocated through `new int()`. Since `ptr` smart pointer is a local variable allocated on the stack, the destructor of `ptr` smart pointer is called when the main function ends. Since delete is called when the destructor is called, the allocated instance is released.

### 1.1. auto_ptr

```cpp {caption="[Code 2] auto_ptr Example", linenos=table}
#include <iostream>
#include <memory>
using namespace std;

class A
{
public:
    void show() {  cout << "A::show()" << endl; }
};

int main()
{
    // p1 is an auto_ptr of type A
    auto_ptr<A> p1(new A);
    p1 -> show();

    // returns the memory address of p1
    cout << p1.get() << endl;

    // copy constructor called, this makes p1 empty.
    auto_ptr <A> p2(p1);
    p2 -> show();

    // p1 is empty now
    cout << p1.get() << endl;

    // p1 gets copied in p2
    cout<< p2.get() << endl;

    return 0;
}
```

```shell {caption="[Shell 1] auto_ptr Example Output"}
A::show()
0x1b42c20
A::show()
0          // NULL
0x1b42c20
```

auto_ptr is a smart pointer that uses the **Exclusive Ownership Model**. That is, an instance pointed to by one auto_ptr cannot be pointed to by another auto_ptr. [Code 2] shows an example where Instance A is assigned to p1, and then p1 is copied to p2 through the copy operator. Although only the value of p1 is copied to p2, you can see that p1's value is initialized to NULL. This is because ownership of Instance A that p1 had has been transferred to p2.

auto_ptr has the characteristic of being initialized to NULL just by calling the copy operator, as shown in [Code 2]. Because auto_ptr performs a **move** operation rather than a copy when the copy operator is called, auto_ptr cannot be used in STL. Also, if an array is allocated through auto_ptr, there is a problem where memory is not properly released. Therefore, the use of auto_ptr is currently not recommended.

### 1.2. unique_ptr

```cpp {caption="[Code 3] unique_ptr Example", linenos=table}
#include <iostream>
#include <memory>
using namespace std;

class A
{
public:
    void show()
    {
        cout<<"A::show()"<<endl;
    }
};

int main()
{
    unique_ptr<A> p1 (new A);
    p1 -> show();

    // returns the memory address of p1
    cout << p1.get() << endl;

    // transfers ownership to p2
    // unique_ptr<A> p2 = p1 (Comile Error)
    unique_ptr<A> p2 = move(p1);
    p2 -> show();
    cout << p1.get() << endl;
    cout << p2.get() << endl;

    return 0;
}
```

```shell {caption="[Shell 2] unique_ptr Example Output"}
A::show()
0x1c4ac20
A::show()
0          // NULL
0x1c4ac20
```

unique_ptr uses the **Exclusive Ownership Model** like auto_ptr, but is a smart pointer that fixes auto_ptr's shortcomings. It can be used in STL and has no problems with array allocation. Available from C++11. [Code 3] shows how to use unique_ptr. In unique_ptr, **copy constructor and copy assignment operator** cannot be used. A compile error occurs when used. Instead, unique_ptr provides the `std::move()` function to explicitly indicate ownership transfer. unique_ptr can only transfer ownership to another unique_ptr through the `std::move()` function.

```cpp {caption="[Code 4] unique_ptr return Example", linenos=table}
unique_ptr<A> fun()
{
    unique_ptr<A> ptr(new A);

    /* ...
       ... */

    return ptr;
}
```

unique_ptr can also be passed as a function's return argument, as shown in [Code 4]. Ownership of the instance is transferred to the unique_ptr that receives the return result.

### 1.3. shared_ptr

```cpp {caption="[Code 5] shared_ptr Example", linenos=table}
#include <iostream>
#include <memory>
using namespace std;

class A
{
public:
    void show()
    {
        cout<<"A::show()"<<endl;
    }
};

int main()
{
    shared_ptr<A> p1 (new A);
    cout << p1.get() << endl;
    p1->show();
    shared_ptr<A> p2 (p1);
    p2->show();
    cout << p1.get() << endl;
    cout << p2.get() << endl;

    // Returns the number of shared_ptr objects
    //referring to the same managed object.
    cout << p1.use_count() << endl;
    cout << p2.use_count() << endl;

    // Relinquishes ownership of p1 on the object
    //and pointer becomes NULL
    p1.reset();
    cout << p1.get() << endl;
    cout << p2.use_count() << endl;
    cout << p2.get() << endl;

    return 0;
}
```

```shell {caption="[Shell 3] shared_ptr Example Output"}
0x1c41c20
A::show()
A::show()
0x1c41c20
0x1c41c20
2
2
0          // NULL
1
0x1c41c20
```

shared_ptr uses the **Reference Counting Ownership Model**. Therefore, unlike auto_ptr and unique_ptr, multiple shared_ptrs can point to one instance. The number of shared_ptrs pointing to an instance is stored and managed in each shared_ptr. When the number of shared_ptrs pointing to an instance decreases to 0, the instance is released. In [Code 5], shared_ptrs `p1` and `p2` are set to point to the same A instance. You can see that the count values of `p1` and `p2` are both 2, and after `p1` is initialized with the reset function, `p2`'s value decreases to 1.

### 1.4. weak_ptr

```cpp {caption="[Code 6] weak_ptr Example", linenos=table}
#include <iostream>
#include <memory>
using namespace std;

class A
{
};

int main()
{
    // weak_ptr initialize with shared_ptr
    shared_ptr<A> sp1(new A);
    weak_ptr<A> wp1 = sp1;

    // weak_ptr convert to shared_ptr
    shared_ptr<A> sp2 = wp1.lock();
    cout << sp2.get() << endl;

    // Reset sp1, sp2
    sp1.reset();
    sp2.reset();

    // weak_ptr convert to shared_ptr
    shared_ptr<A> sp3 = wp1.lock();
    cout << sp3.get() << endl;

    return 0;
}
```

```shell {caption="[Shell 4] weak_ptr Example Output"}
0x746c20
0         // NULL
```

weak_ptr performs the role of a reference that only **references the instance pointed to by shared_ptr**. weak_ptr does not manage the reference count. It does not affect the instance's lifecycle. Therefore, the instance pointed to by weak_ptr may not actually exist. [Code 6] shows how to use weak_ptr. weak_ptr points to the instance pointed to by shared_ptr through shared_ptr. In [Code 6], since wp1 is initialized through sp1, wp1 points to Instance A pointed to by sp1.

weak_ptr must be converted to shared_ptr through the `lock()` function before accessing the instance. When the `lock()` function is called, if the instance pointed to by weak_ptr exists, the converted shared_ptr points to the same instance. If the instance pointed to by weak_ptr does not exist, the converted shared_ptr has a NULL value. In [Code 6], when the first `lock()` function is called, Instance A exists because sp1 points to Instance A. Therefore, sp2 is not NULL. When the second `lock()` function is called, Instance A does not exist because `sp1` and `sp2` have both called the `reset()` function and are no longer pointing to Instance A. Therefore, `sp3` has a NULL value.

{{< figure caption="[Figure 1] Circular Reference" src="images/circular-reference.png" width="800px" >}}

weak_ptr can be used to remove the **Circular Reference** problem of shared_ptr. [Figure 1] shows the circular reference problem. Since shared_ptr manages instances based on reference count, if shared_ptrs reference each other's instances as shown in [Figure 1], the reference count value does not decrease and instances are not released. If one of the shared_ptrs is replaced with weak_ptr, weak_ptr does not affect the instance's lifecycle, so the circular reference problem can be solved.

## 2. References

* [http://www.geeksforgeeks.org/smart-pointers-cpp](http://www.geeksforgeeks.org/smart-pointers-cpp)
* [http://www.geeksforgeeks.org/auto_ptr-unique_ptr-shared_ptr-weak_ptr-2/](http://www.geeksforgeeks.org/auto_ptr-unique_ptr-shared_ptr-weak_ptr-2/)
* [http://egloos.zum.com/sweeper/v/3059940](http://egloos.zum.com/sweeper/v/3059940)


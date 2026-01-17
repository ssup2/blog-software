---
title: Java String
---

This document analyzes Java Strings.

## 1. Java String

```java {caption="[Code 1] String Class", linenos=table}
public final class String
    implements java.io.Serializable, Comparable<String>, CharSequence
{
    private final char value[];
    private final int offset;
    private final int count;

    public String() {
        this.offset = 0;
        this.count = 0;
        this.value = new char[0];
    }

    public String(String original) {
        int size = original.count;
        char[] originalValue = original.value;
        char[] v;
        if (originalValue.length > size) {
            // The array representing the String is bigger than the new
            // String itself.  Perhaps this constructor is being called
            // in order to trim the baggage, so make a copy of the array.
            int off = original.offset;
            v = Arrays.copyOfRange(originalValue, off, off+size);
        } else {
            // The array representing the String is the same
            // size as the String, so no point in making a copy.
            v = originalValue;
        }
        this.offset = 0;
        this.count = size;
        this.value = v;
    }

    public String(char value[]) {
        int size = value.length;
        this.offset = 0;
        this.count = size;
        this.value = Arrays.copyOf(value, size);
    }
```

Java provides the `String` Class for string processing. [Code 1] shows part of Java's `String` Class. Looking at the Member variables of the `String` Class, you can see that they all have `final` attached. This means that strings stored once in a `String` Instance cannot be changed. Therefore, when concatenating strings using the `+` operator of the `String` Class, a new `String` Instance is created. Because of this characteristic, if you perform many string concatenations using the `+` operator in Java Code, `String` Instances can occupy the Heap Memory area and cause Heap Memory space shortage.

### 1.1. StringBuilder, StringBuffer

```java {caption="[Code 2] StringBuilder Class", linenos=table}
public final class StringBuilder
    extends AbstractStringBuilder
    implements java.io.Serializable, CharSequence
{
    public StringBuilder() {
        super(16);
    }

    public StringBuilder(int capacity) {
        super(capacity);
    }

    public StringBuilder(String str) {
        super(str.length() + 16);
        append(str);
    }

    public StringBuilder(CharSequence seq) {
        this(seq.length() + 16);
        append(seq);
    }

    public StringBuilder append(Object obj) {
        return append(String.valueOf(obj));
    }

    public StringBuilder append(String str) {
        super.append(str);
        return this;
    }

    private StringBuilder append(StringBuilder sb) {
        if (sb == null)
            return append("null");
        int len = sb.length();
        int newcount = count + len;
        if (newcount > value.length)
            expandCapacity(newcount);
        sb.getChars(0, len, value, count);
        count = newcount;
        return this;
    }

    public StringBuilder append(StringBuffer sb) {
        super.append(sb);
        return this;
    }

    public StringBuilder append(CharSequence s) {
        if (s == null)
            s = "null";
        if (s instanceof String)
            return this.append((String)s);
        if (s instanceof StringBuffer)
            return this.append((StringBuffer)s);
        if (s instanceof StringBuilder)
            return this.append((StringBuilder)s);
        return this.append(s, 0, s.length());
    }

    public StringBuilder append(char[] str) {
        super.append(str);
        return this;
    }
```

```java {caption="[Code 3] AbstractStringBuilder Class", linenos=table}
abstract class AbstractStringBuilder implements Appendable, CharSequence {
    char[] value;
    int count;

    AbstractStringBuilder() {
    }

    AbstractStringBuilder(int capacity) {
        value = new char[capacity];
    }

    public int length() {
        return count;
    }

    public int capacity() {
        return value.length;
    }

    public AbstractStringBuilder append(Object obj) {
        return append(String.valueOf(obj));
    }

    public AbstractStringBuilder append(String str) {
        if (str == null) str = "null";
        int len = str.length();
        ensureCapacityInternal(count + len);
        str.getChars(0, len, value, count);
        count += len;
        return this;
    }

    public AbstractStringBuilder append(StringBuffer sb) {
        if (sb == null)
            return append("null");
        int len = sb.length();
        ensureCapacityInternal(count + len);
        sb.getChars(0, len, value, count);
        count += len;
        return this;
    }

    public AbstractStringBuilder append(CharSequence s) {
        if (s == null)
            s = "null";
        if (s instanceof String)
            return this.append((String)s);
        if (s instanceof StringBuffer)
            return this.append((StringBuffer)s);
        return this.append(s, 0, s.length());
    }

    public AbstractStringBuilder append(char[] str) {
        int len = str.length;
        ensureCapacityInternal(count + len);
        System.arraycopy(str, 0, value, count, len);
        count += len;
        return this;
    }
```

Java recommends using the `StringBuilder` Class or `StringBuffer` Class rather than the `String` Class when string changes occur frequently. [Code 2] shows the `StringBuilder` class, and [Code 3] shows the `AbstractStringBuilder` Class, which is the parent Class of the `StringBuilder` Class. Looking at the Member Variables of the `AbstractStringBuilder` Class, you can see that there is a Character Array without `final` attached.

Looking at the Methods of the `AbstractStringBuilder` Class, you can see that it uses the Character Array as a **Memory Pool** and directly changes the contents of the Character Array when manipulating strings. Therefore, when manipulating strings using a `StringBuilder` Instance, unnecessary Heap Memory usage can be prevented.

The `StringBuffer` Class performs the same role as the `StringBuilder` Class but has `synchronized` attached to Methods, so it can be used Thread-safely even in multi-thread environments. On the other hand, it has lower performance than the `StringBuilder` Class in single-thread environments. Therefore, use the `StringBuilder` Class in single-thread environments and the `StringBuffer` Class in multi-thread environments.

### 1.2. String Literal

```java {caption="[Code 4] String Literal", linenos=table}
// main
public class main {
    public static void main(String[] args) {
        String strConstuctor1 = new String("ssup2");
        String strConstuctor2 = new String("ssup2");

        String strLiteral1 = "ssup2";
        String strLiteral2 = "ssup2";

        System.out.printf("%b", strConstuctor1.equals(strConstuctor2)); // true
        System.out.printf("%b", strLiteral1.equals(strLiteral2));       // true
        
        System.out.printf("%b", strConstuctor1 == strConstuctor2);      // false
        System.out.printf("%b", strLiteral1 == strLiteral2);            // true
    }
}
```

There are two ways to initialize a `String` Instance: using a Constructor and using a String Literal. Lines 4 and 5 of [Code 4] show the method using a Constructor, and Lines 7 and 8 of [Code 4] show the method using a String Literal. Since all `String` Instances have the string "ssup2", when comparing using the `equal()` Method, the result shows that the strings are the same, but you can see different results when comparing with the "==" operator.

When initializing a `String` Instance with a Constructor, the String Instance is newly allocated in the Heap area. Therefore, the address of `strConstuctor1` and the address of `strConstuctor2` are different. On the other hand, when initializing using a String Literal, if the strings are the same, the same String Literal is shared. Therefore, the address of `strLiteral1` and the address of `strLiteral2` are the same.

String Literals are located in the **Constant String Pool**. The Constant String Pool is located in the "Permanent Generation" area of the Heap in Java 6 Version and below, and is located in the "Young/Old Generation" of the Heap from Java 7 Version onwards, making it subject to Garbage Collection.

## 2. References

* [https://velog.io/@new_wisdom/Java-String-vs-StringBuffer-vs-StringBuilder](https://velog.io/@new_wisdom/Java-String-vs-StringBuffer-vs-StringBuilder)
* [https://velog.io/@ditt/Java-String-literal-vs-new-String](https://velog.io/@ditt/Java-String-literal-vs-new-String)


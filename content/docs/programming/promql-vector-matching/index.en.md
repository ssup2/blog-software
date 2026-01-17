---
title: PromQL Vector Matching
---

This document summarizes PromQL Vector Matching syntax.

## 1. PromQL Vector Matching

PromQL Vector Matching is syntax that matches two Instant Vector Type Data and performs operations, as the name suggests. It is one of the most commonly used syntaxes in PromQL. Depending on how to operate one value existing in Instant Vector Type, there are **One-to-one Matching**, **One-to-many/Many-to-one Matching**, and **Many-to-many Matching**. Here, Matching is based on **Labels** that exist in values.

### 1.1. One-to-one Vector Matching

One-to-one Vector Matching is syntax that matches one value existing in Instant Vector Type with one value existing in another Instant Vector Type **1:1** and performs operations. It can be divided into cases where all Labels must match when matching and cases where only some Labels match.

```promql {caption="[Instant Vector 1] Candy 1 Count"}
#--- query ---
candy1{}

#--- result ---
candy1{color="blue", size="big"} 1
candy1{color="red", size="medium"} 3
candy1{color="green", size="small"} 5
```

```promql {caption="[Instant Vector 2] Ice 1 Count"}
--- query --- 
ice1{}

--- result ---
ice1{color="blue", size="big"} 2
ice1{color="red", size="medium"} 4
ice1{color="green", size="big"} 6
```

[Instant Vector 1] and [Instant Vector 2] show virtual Instant Vector Type Data candy1-count and ice1-count used to explain One-to-one Vector Matching.

#### 1.1.1. All Label Matching

```promql {caption="[SQL Syntax 1] One-to-one, All Label Matching"}
<Instant Vector> <Op> <Instant Vector>

ex) candy1{} + ice1{}
ex) candy1{} * ice1{}
```

[SQL Syntax 1] shows the syntax and examples for matching all Labels in One-to-one Vector Matching.

```promql {caption="[Query 1] One-to-one, All Label Matching"}
#--- query ---
candy1{} + ice1{}

#--- result ---
{color="blue", size="big"} 3 (1+2)
{color="red", size="medium"} 7 (3+4)
```

[Query 1] shows matching all Labels One-to-one for `candy1` and `ice1`. Although the Cardinality of `candy1` and `ice1` is 3, the reason the Cardinality of the result is 2 is because there are only 2 cases where all Labels match: `{color="blue", size="big"}` and `{color="red", size="medium"}`. Since the Operand is `+`, the two values are added.

#### 1.1.2 Partial Label Matching

```promql {caption="[SQL Syntax 2] One-to-one, Partial Label Matching, on"}
<Instant Vector> <Op> on(<label>, ...) <Instant Vector>

# --- example ---
candy1{} + on(color) ice1{}
candy1{} - on(color) ice1{}
```

In One-to-one Matching, when matching only some Labels, there are two syntaxes: the `on` syntax that specifies Labels to match and the `ignoring` syntax that specifies Labels to exclude from matching. [SQL Syntax 2] shows the syntax and examples for specifying Labels to match using the `on` syntax.

```promql {caption="[Query 2] One-to-one, Partial Label Matching, on"}
#--- query --- 
candy1{} - on(color) ice1{}

#--- result ---
{color="blue"} -1 (1-2)
{color="red"} -1 (3-4)
{color="green"} -1 (5-6)
```

[Query 2] shows matching only the `color` Label using the `on` syntax for `candy1` and `ice1`. Operations are performed for each value of the `color` Label values `blue`, `red`, `green` of `candy1` and `ice1`. Since the Operand is `-`, subtraction is performed.

```promql {caption="[SQL Syntax 3] One-to-one, Partial Label Matching, ignoring"}
<Instant Vector> <Op> ignoring(<label>, ...) <Instant Vector>

# --- example ---
candy1{} + ignoring(size) ice1{}
candy1{} / ignoring(size) ice1{}
```

[SQL Syntax 3] shows the syntax and examples for explicitly excluding Labels from matching using the ignoring syntax.

```promql {caption="[Query 3] One-to-one, Partial Label Matching, ignoring"}
#--- query --- 
candy1{} - ignoring(size) ice1{}

#--- result ---
{color="blue"} -1 (1-2)
{color="red"} -1 (3-4)
{color="green"} -1 (5-6)
```

[Query 3] shows matching using only Labels other than `size` using the `ignoring` syntax for `candy1` and `ice1`. Since both `candy1` and `ice1` only have `color` and `size` Labels, and only `size` Label is excluded from matching, matching is performed using only the `color` Label. Therefore, the results of [Query 2] and [Query 3] are the same.

When selecting Labels for One-to-one partial Label Matching, the selected Labels must satisfy the following conditions. If these conditions are not met, a Query Error occurs.
* Values of selected Labels within one Instant Vector Type Data must not be duplicated.
* Values of selected Labels between two Instant Vector Type Data must be matched 1:1.

```promql {caption="[Query 4] One-to-one, Partial Label Matching, Error"}
#--- query --- 
candy1{} + on(size) ice1{}

#--- result ---
Error
```

[Query 4] shows a case where matching fails by selecting the `size` Label for `candy1` and `ice1`. The reason an Error occurs when selecting the `size` Label is because one of the `size` Label values of `ice1`, "big", is duplicated. It violates the first Label selection rule.

The only Label that satisfies all Label selection rules for `candy1` and `ice1` is the `color` Label. If you want to perform Matching by selecting the `size` Label for `candy1` and `ice1`, you must use One-to-many Matching instead of One-to-one.

### 1.2. One-to-many(Many-to-one) Vector Matching

One-to-many Vector Matching is syntax that matches one value existing in Instant Vector Type with multiple values existing in another Instant Vector Type 1:N and performs operations.

```promql {caption="[Instant Vector 3] Candy 2 Count"}
#--- query ---
candy2{}

#--- result ---
candy2{color="blue", size="big"} 1
candy2{color="green", size="small"} 3
candy2{color="green", size="big"} 5
```

```promql {caption="[Instant Vector 4] Ice 2 Count"}
#--- query --- 
ice2{}

#--- result ---
ice2{color="blue", size="big", flavor="soda"} 2
ice2{color="red", size="medium", flavor="cherry"} 4
ice2{color="green", size="big", flavor="lime"} 6
```

[Instant Vector 3] and [Instant Vector 4] show virtual Instant Vector Type Data `candy2` and `ice2` used to explain One-to-many Vector Matching.

```promql {caption="[SQL Syntax 4] One-to-many Matching"}
<Instant Vector> <Op> on/ignoring(<label>, ...) group-left <Instant Vector>
<Instant Vector> <Op> on/ignoring(<label>, ...) group-right <Instant Vector>

# --- example ---
candy2{} * on(color) group-left ice2{}
candy2{} * on(color) group-right ice2{}
```

[SQL Syntax 4] shows the syntax of One-to-many Matching. You can see that only `group-left` and `group-right` are added to the One-to-one partial Label Matching syntax. For 1:N Matching, `group-left` is used when setting the left Instant Vector Type Data as "N" and the right Instant Vector Type Data as "1", and `group-right` is used when setting the right Instant Vector Type Data as "N" and the left Instant Vector Type Data as "1".

Here, Instant Vector Type Data set as "1" must have **only one value selected** by Labels specified in the on, ignoring syntax, and Instant Vector Type Data set as "N" can have 0 or multiple values selected by Labels specified in the on, ignoring syntax.

```promql {caption="[Query 5] One-to-many, group-left"}
#--- query --- 
candy2{} * on(color) group-left ice2{}

#--- result ---
{color="blue", size="big"} 2 (1*2)
{color="green", size="small"} 18 (3*6)
{color="green", size="big"} 30 (5*6)
```

[Query 5] shows a One-to-many Query using group-left. Based on the color Label, `ice2` selects blue/1, green/1, red/1, i.e., only 1 Value each, so it qualifies to be "1", while `candy2` has blue/1, green/2, red/0 based on the color Label, so it cannot be "1" and can only be "N". Therefore, Matching must be performed so that `candy2` becomes "N" through group-left.

```promql {caption="[SQL Syntax 5] One-to-many, Many-to-one Matching with Label"}
<Instant Vector> <Op> on/ignoring(<label>, ...) group-left(<label>, ...) <Instant Vector>
<Instant Vector> <Op> on/ignoring(<label>, ...) group-right(<label>, ...) <Instant Vector>

# --- example ---
candy2{} * on(size) group-left(flavor) ice2{}
```

Looking at the results of [Query 5], you can see that only Labels of `candy2` that became "N" are maintained, and Labels of `ice2` that became "1" disappear. To maintain Labels of "1", you can specify Labels of "1" that should be maintained in the `group-left`, `group-right` syntax. [SQL Syntax 5] shows how to specify Labels of "1" in `group-left`, `group-right`.

```promql {caption="[Query 6] One-to-Many, group-left with Label"}
#--- query --- 
candy2{} * on(color) group-left(flavor) ice2{}

#--- result ---
{color="blue", size="big", flavor="soda"} 2 (1*2)
{color="green", size="small", flavor="lime"} 18 (3*6)
{color="green", size="big", flavor="lime"} 30 (5*6)
```

The Query in [Query 6] only changed the part where the `flavor` Label of `ice2` was specified in `group-left` from the Query in [Query 5]. Therefore, you can see that the `flavor` of `ice2` that was matched exists in the Query results.

### 1.3. Many-to-many Vector Matching

TO-DO

## 2. References

* [https://iximiuz.com/en/posts/prometheus-vector-matching/](https://iximiuz.com/en/posts/prometheus-vector-matching/)
* [https://devthomas.tistory.com/15](https://devthomas.tistory.com/15)
* [https://blog.naver.com/PostView.nhn?blogId=alice-k106&logNo=221535575875](https://blog.naver.com/PostView.nhn?blogId=alice-k106&logNo=221535575875)


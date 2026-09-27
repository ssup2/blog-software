---
title: Redux
---

This post analyzes Redux, which is used as a store for State information in JavaScript.

## 1. Redux

{{< figure caption="[Figure 1] Redux Architecture" src="images/redux-architecture.png" width="650px" >}}

**Redux** serves as a State store that stores State information in JavaScript. Redux is mainly used to store the State information of React Components. [Figure 1] shows the Architecture of Redux. The Store represents the State store where State information is kept in Redux, and it is the core component of Redux. The Store consists of State, Reducer, and Middleware.

```text {caption="[Text 1] State Example", linenos=table}
{
  counters: [
    {
      color: 'red',
      number: 4
    },
    {
      color: 'blue',
      number: 3
    },
    {
      color: 'black',
      number: 7
    }
  ]
}
```

State refers to the space among the Store's components that actually stores State information. State stores State information in a Key-value based Tree form, like JSON. Redux refers to it as an Object Tree. State stores and manages only one Object Tree. This means that State maintains only one piece of **Global state information**. [Text 1] shows the State information of Counter Components stored in State. It can be seen that three Counters exist under a single Tree, and that the color and number State information of each Counter is stored in JSON form.

The State information stored in State can only be changed through a function called a Reducer. A Reducer is a function that takes the Current State information stored in State and an Action created by an Action Creator as Parameters, and then returns the Next State. The Next State returned by the Reducer is stored back into State. When the Next State information is stored in State, it is **Serialized** before being stored. Although Serialization incurs a performance penalty, it eliminates the need to consider Race Conditions, making JavaScript App development and Debugging easier.

```text {caption="[Text 2] Action Example", linenos=table}
{ type: 'ADD-TODO', text: 'Go to swimming pool' }
{ type: 'TOGGLE-TODO', index: 1 }
{ type: 'SET-VISIBILITY-FILTER', filter: 'SHOW-ALL' }
```

An Action created by an Action Creator refers to a JavaScript Object that describes an Event. [Text 2] shows examples of Actions. An Action by itself must clearly describe what Event has occurred. The View is exposed to the user and delivers the user's input to the Action Creator as an Event. In addition, the View registers itself as a Subscriber of State, so that when the State information stored in State is changed by the Reducer, it receives the changed State information and exposes it to the user.

### 1.1. React without Redux vs with Redux

{{< figure caption="[Figure 2] React Component Tree without Redux" src="images/react-component-tree-without-redux.png" width="350px" >}}

React Components provide the ability to store their own State. Therefore, Components with State can be composed using only React, without the help of Redux. [Figure 2] shows the Component Tree and Component State changes when Components are composed using only React without Redux. React Components can have parent-child relationships. For example, in [Figure 2], if Component D is composed using Components F and G, Component D becomes the parent Component of Components F and G. Conversely, the child Components of Component D are Components F and G.

React does not recommend the method shown in [Figure 2] where a child Component directly changes the State of a parent Component. Instead, it recommends using a separate **Global Event System**. If Components directly change each other's State, complexity increases as the number of Components grows, and the difficulty of development and Debugging inevitably increases accordingly, but introducing a Global Event System can solve this problem. Since Redux provides the ability to deliver changed State contents to Components (Views) when State changes, it can serve as React's Global Event System.

{{< figure caption="[Figure 3] React Component Tree with Redux" src="images/react-component-tree-with-redux.png" width="350px" >}}

[Figure 3] shows the Component Tree and Component State changes when Components are composed using React together with Redux. Redux serves as the Global Event System. A child Component sends an Action to the Store instead of to its parent Component. The Reducer of the Store that receives the Action delivers the changed State to the Component, changing the Component's State.

## 2. References

* Getting Started with Redux : [https://redux.js.org/introduction/getting-started](https://redux.js.org/introduction/getting-started)
* Redux 를 통한 React 어플리케이션 상태 관리 :: 1장. 카운터 만들기 : [https://velopert.com/3346](https://velopert.com/3346)
* Docs need one or more diagrams · Issue #653 · reduxjs/redux : [https://github.com/reduxjs/redux/issues/653](https://github.com/reduxjs/redux/issues/653)
* When and when not to use Redux : [https://blog.logrocket.com/](https://blog.logrocket.com/)

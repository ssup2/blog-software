---
title: React Hook
---

This document briefly summarizes React Hooks.

## 1. React Hook

React Hook is functionality that allows pure JavaScript functions to be used as React Components instead of developing React Components by inheriting existing Component Classes. The method of developing by inheriting existing React Components had problems requiring a lot of Code for Component development and causing unnecessary Code duplication. Since React Hook uses pure JavaScript functions as Components, it allows quick Component implementation with less Code writing and removal of unnecessary Code duplication. React Hook was added in React 16.8.

### 1.1. useState()

```javascript {caption="[Code 1] useState()", linenos=table}
function Hello(props) {
  const [date, setDate] = useState(new Date());
  setInterval(() => tick(), 1000);

  function tick() {
    setDate(new Date());
  }

  return (
    <div>
      <h1>Hello, {props.name}, {date.toLocaleTimeString()}</h1>
    </div>
  );
}

ReactDOM.render(
  <Hello name='ssup2' />,
  document.getElementById('root')
);

// Web Output
// Hello, ssup2, 오후 10:47:59
```

The `usetState()` Hook is a Hook used to store State of React Components. It replaces the state Class variable of existing React Component Classes. Pass the initial value of State as a Parameter to the `useState()` Hook. The `useState()` Hook returns State with an initial value set and a State change function that can change State. In [Code 1], the `useState()` Hook is used to initialize the date State of the Hello Component, and the function that changes the date State is used to change the date State every 1 second.

### 1.2. useEffect()

```javascript {caption="[Code 2] useEffect()", linenos=table}
function Hello(props) {
  const [date, setDate] = useState(new Date());
  setInterval(() => tick(), 1000);

  function tick() {
    setDate(new Date());
  }

  // first 
  useEffect(() => {
    console.log('After Rendering, Hello');
    return () => {
      console.log('Unmount, Hello')
    }
  });

  // second
  useEffect(() => {
    console.log('After Rendering, Only Rendering');
  });

  // third
  useEffect(() => {
    console.log('After Rendering, First');
    return () => {
      console.log('Unmount, First')
    }
  }, []);

  // fourth
  useEffect(() => {
    console.log('After Rendering, Date ' + date);
    return () => {
      console.log('Unmount, Date ' + date)
    }
  }, [date])

  return (
    <div>
      <h1>Hello, {props.name}, {date.toLocaleTimeString()}</h1>
    </div>
  );
}

ReactDOM.render(
  <Hello name='ssup2' />,
  document.getElementById('root')
);

// Web Output
// Hello, ssup2

// Console Ouput
// After Rendering, Hello
// After Rendering, Only Rendering
// After Rendering, Name ssup2
// After Rendering, Date Thu Aug 13 2020 22:32:38 GMT+0900 (대한민국 표준시)
// Unmount, Hello
// Unmount, Date Thu Aug 13 2020 22:32:38 GMT+0900 (대한민국 표준시)
// After Rendering, Hello
// After Rendering, Only Rendering
// After Rendering, Date Thu Aug 13 2020 22:32:39 GMT+0900 (대한민국 표준시)
// Unmount, Hello
// Unmount, Date Thu Aug 13 2020 22:32:39 GMT+0900 (대한민국 표준시)
// After Rendering, Hello
// After Rendering, Only Rendering
// After Rendering, Date Thu Aug 13 2020 22:32:40 GMT+0900 (대한민국 표준시)
// Unmount, Hello
// Unmount, Date Thu Aug 13 2020 22:32:40 GMT+0900 (대한민국 표준시)
...
```

The `useEffect()` Hook is a Hook called according to the Lifecycle of React Components. It replaces Lifecycle functions of existing React Component Classes. In [Code 2], the first `useEffect()` Hook shows the basic method of using the `useEffect()` Hook. Pass a function that returns a function as a Parameter to the `useEffect()` Hook. The passed function is called after Rendering when the React Component is Mounted (created) or re-rendered due to State changes. It can be seen as performing the roles of both the `componentDidMount()` function and `componentDidUpdate()` function among existing React Component Lifecycle functions.

The function returned by the function passed to the `useEffect()` Hook is called before the React Component is Unmounted (removed). It performs the role of the `componentWillUnmount()` function among existing React Component Lifecycle functions. If you don't want to do anything when the React Component is Unmounted, the function passed to the `useEffect()` Hook should not return anything. The second `useEffect()` Hook in [Code 2] corresponds to this. If you want the function passed to the `useEffect()` Hook to be called only when the React Component is first Mounted, pass an empty Array as the second Parameter to the `useEffect()` Hook. The third `useEffect()` Hook in [Code 2] corresponds to this.

You can make the function passed to the `useEffect()` Hook be called only when a specific State of the React Component changes. Pass the State to detect changes as the second Parameter to the `useEffect()` Hook. The fourth `useEffect()` Hook in [Code 2] corresponds to this. You can also use Component local variables or State created through the `useState()` Hook in functions passed to the `useEffect()` Hook.

### 1.3. useReducer()

```javascript {caption="[Code 3] useReducer()", linenos=table}
const initialState = {count: 0};

function reducer(state, action) {
  switch (action.type) {
    case 'add':
      return {count: state.count + 1};
    default:
      throw new Error();
  }
}

function Hello(props) {
  const [state, dispatch] = useReducer(reducer, initialState);

  return (
    <div>
      <h1>Hello, {props.name}, {state.count}</h1>
      <button onClick={() => dispatch({type: 'add'})}>+</button>
    </div>
  );
}

ReactDOM.render(
  <Hello name='ssup2' />,
  document.getElementById('root')
);

// Web Output
// Hello, ssup2, 0
// + button
```

The `useReducer()` Hook is a Hook used to store Global State of React Apps. It was added to replace existing React Redux. Pass a Reducer function that changes Global State according to Actions and the initial value of Global State as Parameters to the `useReducer()` Hook. The `useReducer()` Hook returns Global State with an initial value set and a `Dispatch()` function that can change State. [Code 3] creates a Button in the `Hello` Component. When the created Button is pressed, an add Action occurs through the `Dispatch()` function and increases the Count value.

## 2. References

* [https://ko.reactjs.org/docs/hooks-overview.html](https://ko.reactjs.org/docs/hooks-overview.html)
* [https://gist.github.com/ninanung/25bdbf78a720846e4dc4c30ac1c9ec9b](https://gist.github.com/ninanung/25bdbf78a720846e4dc4c30ac1c9ec9b)


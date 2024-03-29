---
title: React Router
---

React Router를 간략하게 정리한다.

## 1. React Router

```javascript {caption="[Code 1] React Router Example - index.js", linenos=table}
ReactDOM.render(
  <BrowserRouter>
    <App/>
  </BrowserRouter>,
  document.getElementById('root')
);
```

```javascript {caption="[Code 2] React Router Example - App.js", linenos=table}
class App extends Component {
    render() {
        return (
            <div>
                <Route exact path="/" component={Home}/>
                <Route path="/blog" component={Blog}/>
            </div>
        );
    }
}
```

```javascript {caption="[Code 3] React Router Example - Home.js", linenos=table}
const Home = () => {
    return (
        <div>
            <h2>Home</h2>
        </div>
    );
};

// Home 
```

```javascript {caption="[Code 4] React Router Example - Blog.js", linenos=table}
const Blog = () => {
    return (
        <div>
            <h2>Blog</h2>
        </div>
    );
};

// Blog
```

React Router는 React App을 SPA(Single Page Application)으로 구현할 수 있도록 도와주는 React Component이다. [Code 1-4]는 간단한 React Router Example을 나타내고 있다. `/` Path로 이동할 경우 `Home.js`가 Rendering 되고, `/blog` Path로 이동할 경우 `Blog.js`가 Rendering 된다. 중요한 React Component는 `BrowserRouter` Component와 `Route` Component이다. `BrowserRouter` Component는 Path에 따라서 실제 Routing을 수행하는 React Component이고, `Route` Component는 BrowserRouter에서 Routing을 수행할 Path 및 관련 React Component를 등록하는 역할을 수행한다.

[Code 1]에서는 `BrowserRouter` Component가 선언되어 있다. [Code 2]에서는 `Route` Component를 통해서 Routing Path 및 관련 React Component를 등록한다. `/` Path에는 Home Component를 등록하고 있고, `/blog` Path에 Blog Component를 등록한다. `/` Path에 Home Component 등록시 **exact** 문법를 볼수 있는데, `/` Path와 정확하게 일치할 때만 Home Component를 Rendering (Routing) 한다는 의미이다. 만약 exact가 없다면 `/blog` Path로 이동시 Home Component와 Blog Component 둘다 Rendering 된다.

### 1.1. Path, Query Parameter

```javascript {caption="[Code 5] React Router Path, Query Parameter Example - index.js", linenos=table}
ReactDOM.render(
  <BrowserRouter>
    <App/>
  </BrowserRouter>,
  document.getElementById('root')
);
```

```javascript {caption="[Code 6] React Router Path, Query Parameter Example - App.js", linenos=table}
class App extends Component {
    render() {
        return (
            <div>
                <Route exact path="/" component={Home}/>
                <Route path="/:name" component={Home}/>
            </div>
        );
    }
}
```

```javascript {caption="[Code 7] React Router Path, Query Parameter Example - Home.js", linenos=table}
{% highlight javascript linenos %}
const Home = ({location, match}) => {
    const query = queryString.parse(location.search);
    return (
        <div>
            <h2>Home {match.params.name} {query.address}</h2>
        </div>
    );
};

// Home [name], [address]
```

React Router는 Path Parameter를 React Component엑 전달하는 기능을 제공한다. [Code 5~7]은 Path Parmater의 예제를 나타내고 있다. Path Parameter는 `Route` Component를 통해서 설정된다. [Code 6]에서는 `Route` Component를 통해서 `name`이라는 이름의 Path Parameter를 등록한다. React Component는 Path Parameter를 match.params Parameter를 통해서 얻을 수 있다. [Code 7]에서는 `Hello` Component가 `match.params` Parameter를 통해서 `name` Path Paramter의 값을 얻어 Rendering 한다. 따라서 `/ssup2` Path로 이동하게 되면, Home Component는 `Home ssup2` 문자열을 Rendering 한다.

React Router v4에서는 Query를 자체적으로 Parsing하는 기능을 제공하지는 않는다. 단지 현재의 Path 정보와 Sub-query 정보를 React Component가 얻을 수 있게만 제공하고 있다. React Component는 location Parameter를 통해서 현재의 Path 및 Sub-query 정보를 얻을수 있다. Sub-query 정보는 `location.search` Parameter에 포함되어 있다. [Code 7]에서는 Home Component가 address Sub-query를 `query-string` Library를 통해 얻어 Rendering한다. 따라서 `/ssup2?address=github` Path로 이동하게 되면, Home Component는 `Home ssup2 github` 문자열을 Rendering 한다.

### 1.2. Link Component

```javascript {caption="[Code 8] React Router Link Example - index.js", linenos=table}
ReactDOM.render(
  <BrowserRouter>
    <App/>
  </BrowserRouter>,
  document.getElementById('root')
);
```

```javascript {caption="[Code 9] React Router Link Example - App.js", linenos=table}
class App extends Component {
    render() {
        return (
            <div>
                <Route exact path="/" component={Home}/>
                <Route path="/blog" component={Blog}/>
            </div>
        );
    }
}
```

```javascript {caption="[Code 10] React Router Link Example - Home.js", linenos=table}
const Home = () => {
    return (
        <div>
            <h2>Home</h2>
            <Link to="/blog">Blog</Link>
        </div>
    );
};

// Home 
```

```javascript {caption="[Code 11] React Router Link Example - Blog.js", linenos=table}
const Blog = () => {
    return (
        <div>
            <h2>Blog</h2>
        </div>
    );
};

// Blog
```

Link Component는 React App 내부에서 다른 Path로 이동하기 위해 이용하는 React Component이다. [Code 8~11]은 Link Component의 예제를 나타내고 있다. [Code 10]에서는 `Home` Component가 `Link` Component를 통해서 `/blog` Path로 이동하는 `Link`를 Rendering 한다.

## 2. 참조

* [https://velopert.com/3417](https://velopert.com/3417)
* [https://jeonghwan-kim.github.io/dev/2019/07/08/react-router-ts.html](https://jeonghwan-kim.github.io/dev/2019/07/08/react-router-ts.html)
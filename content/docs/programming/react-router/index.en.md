---
title: React Router
---

This document briefly summarizes React Router.

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

React Router is a React Component that helps implement React Apps as SPA (Single Page Application). [Code 1-4] shows a simple React Router Example. When moving to the `/` Path, `Home.js` is Rendered, and when moving to the `/blog` Path, `Blog.js` is Rendered. Important React Components are the `BrowserRouter` Component and `Route` Component. The `BrowserRouter` Component is a React Component that actually performs Routing according to Path, and the `Route` Component performs the role of registering Paths and related React Components for Routing in BrowserRouter.

In [Code 1], the `BrowserRouter` Component is declared. In [Code 2], Routing Paths and related React Components are registered through the `Route` Component. The Home Component is registered for the `/` Path, and the Blog Component is registered for the `/blog` Path. When registering the Home Component for the `/` Path, you can see the **exact** syntax, which means that the Home Component is Rendered (Routed) only when it exactly matches the `/` Path. If exact is not present, both the Home Component and Blog Component are Rendered when moving to the `/blog` Path.

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

React Router provides functionality to pass Path Parameters to React Components. [Code 5~7] shows examples of Path Parameters. Path Parameters are set through the `Route` Component. In [Code 6], a Path Parameter named `name` is registered through the `Route` Component. React Components can obtain Path Parameters through the match.params Parameter. In [Code 7], the `Hello` Component obtains the value of the `name` Path Parameter through the `match.params` Parameter and Renders it. Therefore, when moving to the `/ssup2` Path, the Home Component Renders the string `Home ssup2`.

React Router v4 does not provide functionality to parse Queries on its own. It only provides the ability for React Components to obtain current Path information and Sub-query information. React Components can obtain current Path and Sub-query information through the location Parameter. Sub-query information is included in the `location.search` Parameter. In [Code 7], the Home Component obtains and Renders the address Sub-query through the `query-string` Library. Therefore, when moving to the `/ssup2?address=github` Path, the Home Component Renders the string `Home ssup2 github`.

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

The Link Component is a React Component used to move to other Paths within React Apps. [Code 8~11] shows examples of the Link Component. In [Code 10], the `Home` Component Renders a `Link` that moves to the `/blog` Path through the `Link` Component.

## 2. References

* [https://velopert.com/3417](https://velopert.com/3417)
* [https://jeonghwan-kim.github.io/dev/2019/07/08/react-router-ts.html](https://jeonghwan-kim.github.io/dev/2019/07/08/react-router-ts.html)


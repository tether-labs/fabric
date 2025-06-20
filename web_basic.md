# Web Development Basics - Introduction to Web Technologies

> **Target audience:** Complete beginners to web development who want to understand the foundation before diving into Fabric framework.

---

## 1. What is Web Development?

Web development is the process of creating websites and web applications that run in web browsers like Chrome, Firefox, Safari, or Edge. When you visit a website like Google, Facebook, or GitHub, you're interacting with a web application that someone built using web technologies.

### 1.1 The Client-Server Model

```
[Your Browser] ←→ [Internet] ←→ [Web Server]
   (Client)                      (Backend)
```

- **Client (Frontend)**: Your web browser that displays the website
- **Server (Backend)**: A computer somewhere that stores the website files and data
- **Internet**: The network that connects them

Most of this tutorial focuses on **frontend** development - the part that runs in your browser.

---

## 2. The Three Core Web Technologies

Every website is built using three fundamental technologies:

### 2.1 HTML (HyperText Markup Language)
**Purpose**: Structure and content

HTML defines what's on the page - headings, paragraphs, images, buttons, etc.

```html
<!DOCTYPE html>
<html>
<head>
    <title>My First Website</title>
</head>
<body>
    <h1>Welcome to My Site</h1>
    <p>This is a paragraph of text.</p>
    <button>Click Me!</button>
</body>
</html>
```

Think of HTML as the **skeleton** of a webpage.

### 2.2 CSS (Cascading Style Sheets)
**Purpose**: Appearance and layout

CSS controls how things look - colors, fonts, sizes, positioning.

```css
h1 {
    color: blue;
    font-size: 32px;
}

button {
    background-color: green;
    padding: 10px;
    border-radius: 5px;
}
```

Think of CSS as the **skin and clothes** that make the skeleton look good.

### 2.3 JavaScript
**Purpose**: Behavior and interactivity

JavaScript makes things happen when users interact with the page.

```javascript
function handleButtonClick() {
    alert("Hello! You clicked the button!");
}

document.querySelector('button').onclick = handleButtonClick;
```

Think of JavaScript as the **muscles and brain** that make the page move and respond.

---

## 3. How Web Browsers Work

### 3.1 The Loading Process

When you type a URL like `https://example.com` and press Enter:

1. **Browser requests files** from the server
2. **Server sends back** HTML, CSS, and JavaScript files
3. **Browser parses HTML** and builds the page structure
4. **Browser applies CSS** to style everything
5. **Browser runs JavaScript** to add interactivity
6. **Page is displayed** and ready for interaction

### 3.2 The DOM (Document Object Model)

The DOM is how JavaScript sees and manipulates the webpage. It treats the HTML as a tree of elements:

```
html
├── head
│   └── title
└── body
    ├── h1
    ├── p
    └── button
```

JavaScript can:
- Find elements: `document.querySelector('button')`
- Change content: `element.textContent = 'New text'`
- Respond to clicks: `element.onclick = myFunction`
- Add/remove elements dynamically

---

## 4. Modern Web Development Challenges

### 4.1 Complexity Growth

Modern websites are complex applications, not just documents. Think about Gmail, Facebook, or online games - they need to:

- Handle user interactions in real-time
- Manage complex state (what's displayed, user data, etc.)
- Update parts of the page without reloading
- Work on phones, tablets, and desktops
- Load quickly and run smoothly

### 4.2 Traditional Approach Limitations

Writing everything in HTML, CSS, and JavaScript directly becomes difficult for complex apps because:

- **Code organization**: Hard to keep thousands of lines organized
- **State management**: Tracking what's happening across the app
- **Performance**: Manually updating the DOM is slow and error-prone
- **Code reuse**: Hard to reuse components across different pages

### 4.3 Modern Solutions: Frameworks

Frameworks are tools that make complex web development easier. Popular ones include:

- **React** (by Facebook): Component-based UI building
- **Vue.js**: Approachable progressive framework
- **Angular** (by Google): Full-featured application platform
- **Svelte**: Compile-time optimized framework

**Fabric fits here** - it's a framework that lets you build web applications using the Zig programming language instead of JavaScript.

---

## 5. What is WebAssembly (WASM)?

### 5.1 The Problem with JavaScript

JavaScript was originally designed for simple webpage scripts, not complex applications. While it has evolved, it has limitations:

- **Performance**: Slower than compiled languages
- **Type safety**: Easy to make errors that only show up at runtime
- **Language choice**: You're stuck with JavaScript syntax and paradigms

### 5.2 WebAssembly Solution

WebAssembly (WASM) is a technology that lets you run code written in other languages (like C++, Rust, or Zig) in web browsers at near-native speed.

```
Traditional:  [Your Code in JS] → [Browser]
WebAssembly:  [Your Code in Zig] → [Compile to WASM] → [Browser]
```

### 5.3 Benefits of WebAssembly

- **Performance**: Runs much faster than JavaScript
- **Language choice**: Use any language that compiles to WASM
- **Interoperability**: Can work alongside JavaScript
- **Security**: Runs in the same secure sandbox as JavaScript

### 5.4 WebAssembly + JavaScript Integration

WASM doesn't replace JavaScript entirely - they work together:

```javascript
// JavaScript side - loads and calls WASM functions
const wasmModule = await WebAssembly.instantiateStreaming(fetch('app.wasm'));
const result = wasmModule.instance.exports.calculate(10, 20);
```

```zig
// Zig/WASM side - exports functions JavaScript can call
export fn calculate(a: i32, b: i32) i32 {
    return a + b;
}
```

---

## 6. Development Environment Setup

### 6.1 Essential Tools

To develop web applications, you need:

1. **Code Editor**: 
   - VS Code (most popular, free)
   - Sublime Text, Atom, or others

2. **Web Browser with Developer Tools**:
   - Chrome DevTools (F12 key)
   - Firefox Developer Tools
   - Used for debugging, inspecting elements, viewing console output

3. **Local Web Server**:
   - `python -m http.server` (if Python installed)
   - `npx serve` (if Node.js installed)
   - VS Code "Live Server" extension
   - **Why needed**: Many web features don't work when opening HTML files directly

### 6.2 Browser Developer Tools Crash Course

Press F12 in any browser to open developer tools:

- **Elements tab**: Inspect and modify HTML/CSS live
- **Console tab**: See JavaScript errors and output
- **Network tab**: See what files are being loaded
- **Sources tab**: Debug JavaScript code step-by-step

### 6.3 Basic Workflow

1. **Write code** in your editor
2. **Save files** 
3. **Refresh browser** to see changes
4. **Check console** for errors
5. **Use dev tools** to debug issues

---

## 7. Single Page Applications (SPAs)

### 7.1 Traditional Multi-Page Sites

Old-school websites worked like this:
- Click a link → Browser requests new page → Server sends new HTML → Page reloads
- Each page is a separate HTML file
- Every navigation causes a full page refresh

### 7.2 Single Page Applications

Modern web apps work differently:
- Initial load gets one HTML file + JavaScript bundle
- JavaScript handles navigation by changing what's displayed
- No page reloads - just content updates
- Examples: Gmail, Twitter, Facebook

### 7.3 SPA Benefits

- **Faster navigation**: No page reloads
- **Better user experience**: Smooth transitions
- **Mobile-like feel**: More like a native app
- **Shared state**: Data persists across "pages"

### 7.4 SPA Challenges

- **Complexity**: More complex than simple websites
- **SEO**: Search engines have trouble indexing
- **Initial load time**: Larger JavaScript bundles
- **Browser history**: Must manually manage back/forward buttons

---

## 8. Component-Based Architecture

### 8.1 The Problem with Large Applications

Imagine building a complex interface like Facebook:
- News feed with hundreds of posts
- Each post has likes, comments, share buttons
- Navigation bar, sidebar, chat windows
- Writing this as one big HTML file would be unmaintainable!

### 8.2 Component Solution

Break the interface into reusable pieces (components):

```
Facebook Page
├── NavigationBar
├── Sidebar
│   ├── FriendsList
│   └── GroupsList
├── NewsFeed
│   ├── Post (repeated many times)
│   │   ├── PostHeader
│   │   ├── PostContent
│   │   └── PostActions
│   └── ...
└── ChatWindow
```

### 8.3 Component Benefits

- **Reusability**: Write once, use everywhere
- **Organization**: Each component is self-contained
- **Testing**: Test components individually
- **Team collaboration**: Different people work on different components

### 8.4 Component Example (Conceptual)

```
Button Component:
- Input: text, color, click handler
- Output: Styled button that responds to clicks
- Usage: <Button text="Save" color="blue" onClick={saveData} />
```

---

## 9. State Management

### 9.1 What is "State"?

State is all the data that determines what your application displays at any moment:

- Is the user logged in?
- What page are they viewing?
- What items are in their shopping cart?
- Is a modal dialog open?
- What text is in the search box?

### 9.2 State Management Challenges

In complex apps, state becomes difficult because:
- Multiple components need the same data
- User actions in one component affect other components
- Data changes over time (user types, server updates, etc.)
- Need to keep UI in sync with data

### 9.3 State Management Solutions

Different approaches to handle state:

- **Local component state**: Each component manages its own data
- **Global state**: Shared data store accessible by all components
- **State lifting**: Move shared state to parent components
- **State management libraries**: Redux, MobX, Zustand, etc.

---

## 10. Build Tools and Bundlers

### 10.1 Why Build Tools?

Modern web development involves:
- Multiple JavaScript files that need to be combined
- CSS preprocessing (Sass, Less)
- Code optimization (minification, compression)
- Asset management (images, fonts)
- Development servers with hot reloading

### 10.2 Popular Build Tools

- **Webpack**: Powerful but complex bundler
- **Vite**: Fast, modern build tool
- **Parcel**: Zero-configuration bundler
- **Rollup**: Library-focused bundler

### 10.3 What Build Tools Do

```
Development Files:
├── src/
│   ├── component1.js
│   ├── component2.js
│   ├── styles.css
│   └── images/
│
Build Process:
↓
Production Files:
├── bundle.js (all JS combined & minified)
├── styles.css (processed & minified)
└── assets/ (optimized images)
```

---

## 11. Where Fabric Fits In

### 11.1 Fabric's Approach

Fabric is a web framework that:
- Uses **Zig** instead of JavaScript for application logic
- Compiles to **WebAssembly** for performance
- Provides **component-based** architecture
- Handles **state management** through signals
- Manages **routing** for single-page applications

### 11.2 Why Choose Fabric?

**Advantages**:
- **Performance**: WebAssembly is faster than JavaScript
- **Type safety**: Zig's strong type system prevents many bugs
- **Memory control**: Manual memory management for predictable performance
- **Familiar patterns**: Component-based like React, but with Zig

**Trade-offs**:
- **Learning curve**: Need to learn Zig + WebAssembly concepts
- **Ecosystem**: Smaller community compared to JavaScript frameworks
- **Tooling**: Less mature development tools

### 11.3 Fabric Development Flow

1. **Write components** in Zig using Fabric APIs
2. **Compile to WebAssembly** using Zig compiler
3. **Load WASM module** in browser via JavaScript
4. **Fabric handles** DOM updates, routing, and state management

---

## 12. Getting Ready for the Fabric Tutorial

### 12.1 Concepts You Should Now Understand

After reading this guide, you should understand:
- How web browsers load and display websites
- The role of HTML, CSS, and JavaScript
- What WebAssembly is and why it's useful
- Component-based architecture
- Single-page applications
- State management basics

### 12.2 What You'll Learn in the Fabric Tutorial

The main tutorial will teach you:
- How to set up a Fabric project
- Writing components in Zig
- Managing application state with signals
- Handling user interactions
- Building a complete tic-tac-toe game

### 12.3 Don't Worry If...

It's normal if you don't fully grasp everything yet:
- Concepts will become clearer with practice
- The Fabric tutorial provides concrete examples
- Web development has a learning curve for everyone
- Focus on understanding the big picture first

---

## 13. Next Steps

1. **Read the Zig Basics guide** (if you're new to Zig)
2. **Try the Fabric tutorial** with this foundation
3. **Experiment** with the examples
4. **Build something small** to practice
5. **Join communities** (Zig Discord, web dev forums) for help

Remember: Every expert was once a beginner. Web development can seem overwhelming at first, but breaking it down into pieces makes it manageable. The Fabric framework provides a structured way to build web applications - now you have the context to understand why and how it works.

---

## Glossary

**API**: Application Programming Interface - how different pieces of software communicate  
**Bundle**: Combined and optimized files ready for production  
**DOM**: Document Object Model - browser's representation of the webpage  
**Framework**: Pre-built tools and patterns for building applications  
**Hot Reloading**: Automatically updating the browser when code changes  
**Minification**: Removing unnecessary characters to reduce file size  
**SPA**: Single Page Application - web app that doesn't reload pages  
**WASM**: WebAssembly - binary format for running code in browsers  
**Component**: Reusable piece of user interface  
**State**: Data that determines what the application displays  
**Build Tool**: Software that processes and optimizes code for production

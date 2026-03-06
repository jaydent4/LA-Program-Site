import { useState } from "react";
import reactLogo from "./assets/react.svg";
import viteLogo from "/vite.svg";
import "./App.css";

function App() {
  const [message, setMessage] = useState("");

  const fetchData = async () => {
    const response = await fetch("https://api.laprogramucla.com/test"); // Replace with your API endpoint
    if (!response.ok) {
      throw new Error("Network response was not ok");
    }
    const result = await response.json();
    setMessage((message) => message + result);
  };

  return (
    <>
      <div>
        <a href="https://vite.dev" target="_blank">
          <img src={viteLogo} className="logo" alt="Vite logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
      </div>
      <h1>Vite + React</h1>
      <div className="card">
        <button onClick={fetchData}>click me to test the api</button>
        <p>Response: {message}</p>
      </div>
    </>
  );
}

export default App;

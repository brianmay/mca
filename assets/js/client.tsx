import ApolloClient from "apollo-boost";

let authorization = null;
if (document.querySelector("meta[name=token]")) {
  const jwt = document.querySelector("meta[name=token]")['content'];
  authorization = "Bearer "+jwt
}

const client = new ApolloClient({
  uri: "/api",
  headers: {
    // 'Content-Type': 'application/json',
    'authorization': authorization,
  },
});
export default client;

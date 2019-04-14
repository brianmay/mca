import * as React from 'react'
import * as ReactDOM from 'react-dom'
import { BrowserRouter } from 'react-router-dom'
import { ApolloProvider } from "react-apollo";

import { routes } from './routes'
import client from './client'

// This code starts up the React app when it runs in a browser. It sets up the routing
// configuration and injects the app into a DOM element.
ReactDOM.render(
  <ApolloProvider client={client}>
    <BrowserRouter children={ routes } />
  </ApolloProvider>,
  document.getElementById('react-app')
)

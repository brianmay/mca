import * as React from 'react'
import { Route } from 'react-router-dom'
import Root from './Root'
import Planner from './components/Planner'

export const routes = (
  <Root>
    <Route exact path="/planner" component={ Planner } />
  </Root>
)

import * as React from 'react'
import { Route } from 'react-router-dom'
import Root from './Root'
import Planner from './components/Planner'
import UserList from './components/user_list'

export const routes = (
  <Root>
    <Route exact path="/planner" component={ Planner } />
    <Route exact path="/users" component={ UserList } />
  </Root>
)

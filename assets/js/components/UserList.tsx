import * as React from 'react'
import { Button } from 'reactstrap';
import User from './User';


interface Props {
  allUsers: any;
}

interface State {
  edit_id: number | null;
  add: boolean;
}


class UserList extends React.Component<Props, State> {
  constructor(props) {
    super(props);

    this.state = {
      edit_id: null,
      add: false,
    }
  }

  setAdd(): void {
    this.setState({ edit_id: null, add: true })
  }

  setEdit(user): void {
    this.setState({ edit_id: user.id, add: false })
  }

  setEditDone(): void {
    this.setState({ edit_id: null, add: false })
  }

  render() {
    const { allUsers } = this.props;
    const { edit_id } = this.state;

    let add_user: JSX.Element;
    if (this.state.add) {
      add_user = <User
        user={null}
        edit={true}
        onEdit={() => null}
        onEditDone={() => this.setEditDone()}
      />
    } else {
      add_user = <Button onClick={() => this.setAdd()}>Add user</Button>
    }
    return (
      <ul>
        {allUsers.map(user =>
          <User
            key={user.id}
            user={user}
            edit={user.id == edit_id}
            onEdit={() => this.setEdit(user)}
            onEditDone={() => this.setEditDone()}
          />
        )}
        {add_user}
      </ul>
    );
  }
}

export default UserList;

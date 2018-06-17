import * as React from 'react'
import { Button } from 'reactstrap'
import { Environment } from 'relay-runtime';
import { graphql, createFragmentContainer, commitMutation } from 'react-relay';

import environment from '../relay';
import { User_user } from './__generated__/User_user.graphql';
import { UpdateUserParams } from './__generated__/UserUpdateMutation.graphql';

const add_mutation = graphql`
mutation UserAddMutation($user: UpdateUserParams) {
  addUser(user: $user) {
    successful
    messages {
      field
      message
    }
    result {
      id
      isAdmin
      email
    }
  }
}`;

const update_mutation = graphql`
mutation UserUpdateMutation($id: ID!, $user: UpdateUserParams) {
  updateUser(id: $id, user: $user) {
    successful
    messages {
      field
      message
    }
    result {
      id
      isAdmin
      email
    }
  }
}`;

const delete_mutation = graphql`
mutation UserDeleteMutation($id: ID!) {
  deleteUser(id: $id) {
    successful
    messages {
      field
      message
    }
    result {
      id
      isAdmin
      email
    }
  }
}`;

type ErrorFields = { [id: string]: string };

function process_response(response, errors, onError: (error: string, fields: ErrorFields) => void, onSuccess: () => void): void {
  console.log('Response received from server.', response, errors);
  if (errors) {
    onError(errors.map(value => value['message']).join(", "), {})
  } else {
    if (response.successful) {
      onSuccess()
    } else {
      const fields = response.messages.reduce((map, error) => {
        map[error.field] = error.message;
        return map;
      }, {});
      onError("You made a mistake. Don't blame me.", fields);
    }
  }
}

function process_error(error, onError: (error: string, fields: ErrorFields) => void) {
  console.log(error);
  onError("Something went wrong. Sorry. It wasn't my fault.", {})
}

function commit_add(environment: Environment, updates: UpdateUserParams, onError: (error: string, fields: ErrorFields) => void, onSuccess: () => void): void {
  commitMutation(
    environment,
    {
      mutation: add_mutation,
      variables: {
        user: updates,
      },
      updater: (store) => {
        const payload = store.getRootField('addUser');
        if (payload) {
          const user = payload.getLinkedRecord('result');
          console.log(payload, user);
        }
      },
      onCompleted: (response, errors) => {
        process_response(response.addUser, errors, onError, onSuccess);
      },
      onError: err => process_error(err, onError),
    }
  )
}

function commit_update(environment: Environment, user: User_user, updates: UpdateUserParams, onError: (error: string, fields: ErrorFields) => void, onSuccess: () => void): void {
  commitMutation(
    environment,
    {
      mutation: update_mutation,
      variables: {
        id: user.id,
        user: updates,
      },
      onCompleted: (response, errors) => {
        process_response(response.updateUser, errors, onError, onSuccess);
      },
      onError: err => process_error(err, onError),
    }
  )
}

function commit_delete(environment: Environment, user: User_user, onError: (error: string, fields: ErrorFields) => void, onSuccess: () => void): void {
  commitMutation(
    environment,
    {
      mutation: delete_mutation,
      variables: {
        id: user.id,
      },
      onCompleted: (response, errors) => {
        process_response(response.deleteUser, errors, onError, onSuccess);
      },
      onError: err => process_error(err, onError),
    }
  )
}

function commit(environment: Environment, user: User_user | null, updates: UpdateUserParams, onError: (error: string, fields: ErrorFields) => void, onSuccess: () => void): void {
  if (user) {
    return commit_update(environment, user, updates, onError, onSuccess);
  } else {
    return commit_add(environment, updates, onError, onSuccess);
  }
}

interface Props {
  user: User_user | null;
  edit: boolean;
  onEdit: () => void;
  onEditDone: () => void;
}

interface State {
  user: UpdateUserParams;
  error: string | null;
  error_fields: ErrorFields;
  message: string | null;
}

class UserComponent extends React.Component<Props, State> {
  constructor(props) {
    super(props);
    this.state = {
      user: {
        isAdmin: false,
        email: "",
      },
      error: null,
      error_fields: {},
      message: null,
    }
    this.onCancel = this.onCancel.bind(this);
    this.onSave = this.onSave.bind(this);
    this.onDelete = this.onDelete.bind(this);
    this.handleInputChange = this.handleInputChange.bind(this);
  }

  onCancel() {
    this.setState({ error: null, message: null });
    this.props.onEditDone();
  }

  onSave(event) {
    event.preventDefault();
    this.setState({
      error: null,
      error_fields: {},
      message: null,
    })
    commit(environment, this.props.user, this.state.user, (err, error_fields) => {
      this.setState({ error: err, error_fields: error_fields, message: null });
    }, () => {
      this.props.onEditDone();
      this.setState({ error: null, message: "Saved!" });
    });
  }

  onDelete() {
    this.setState({
      error: null,
      error_fields: {},
      message: null,
    })
    commit_delete(environment, this.props.user, (err, error_fields) => {
      this.setState({ error: err, error_fields: error_fields, message: null });
    }, () => {
      this.props.onEditDone();
      this.setState({ error: null, message: "Deleted!" });
    });
  }

  componentWillReceiveProps(nextProps: Props) {
    // Any time props.email changes, update state.
    if (nextProps.edit && !this.props.edit) {
      this.setState({
        user: {
          email: this.props.user.email,
          isAdmin: this.props.user.isAdmin,
        },
        message: null,
        error: null,
        error_fields: {},
      });
    }
    if (!nextProps.edit) {
      this.setState({
        error: null,
        message: null,
        error_fields: {},
      })
    }
  }

  handleInputChange(event) {
    const target = event.target;
    const value = target.type === 'checkbox' ? target.checked : target.value;
    const name = target.name;

    let user = Object.assign({}, this.state.user)
    user[name] = value

    this.setState({
      user: user,
    });
  }

  render() {

    const { edit } = this.props;

    let message: JSX.Element;
    if (this.state.error) {
      message = <div className="alert alert-danger">{this.state.error}</div>
    } else if (this.state.message) {
      message = <div className="alert alert-success">{this.state.message}</div>
    }

    let delete_button: JSX.Element;
    if (this.props.user) {
      delete_button = (
        <Button onClick={this.onDelete} color="danger">
          Delete
        </Button>
      )
    }

    if (edit) {
      const { email, isAdmin } = this.state.user;

      return (
        <li className="item">
          <form>
            <div className="form-row">
              <div className="col-md-1 mb-3">
                  <label htmlFor="isAdmin">Is Administrator:</label>
                  <input
                    id="isAdmin"
                    name="isAdmin"
                    type="checkbox"
                    checked={isAdmin}
                    className={"form-control " + (this.state.error_fields.isAdmin ? 'is-invalid' : '')}
                    onChange={this.handleInputChange} />
                  <div className="invalid-feedback">
                    {this.state.error_fields.isAdmin}
                  </div>
              </div>
              <div className="col-md-11 mb-3">
                  <label htmlFor="email">E-Mail:</label>
                  <input
                    id="email"
                    name="email"
                    value={email}
                    className={"form-control " + (this.state.error_fields.email ? 'is-invalid' : '')}
                    onChange={this.handleInputChange}/>
                  <div className="invalid-feedback">
                    {this.state.error_fields.email}
                  </div>
              </div>
            </div>
            <div className="form-row">
              <div className="col-md-12 mb-3">
                <Button onClick={this.onCancel} color="secondary">
                  Cancel
                </Button>
                <Button onClick={this.onSave} color="primary" type="submit">
                  Save
                </Button>
                {delete_button}
              </div>
            </div>
          </form>
          {message}
        </li>)
    }

    const { email, isAdmin } = this.props.user;
    return (
      <li className="item">
        <div>
          <input
            checked={isAdmin}
            type="checkbox"
            readOnly
          />
          <label>
            {email}
          </label>
          <Button onClick={() => this.props.onEdit()} color="primary">
            edit
          </Button>
        </div>
        {message}
      </li>
    );
  }
}

export default createFragmentContainer<Props>(
  UserComponent,
  graphql`
    # As a convention, we name the fragment as '<ComponentFileName>_<propName>'
    fragment User_user on User {
      id,
      email,
      isAdmin
    }
  `
)

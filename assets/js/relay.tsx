import {
  Environment,
  Network,
  RecordSource,
  Store,
} from 'relay-runtime';

function fetchQuery(
  operation,
  variables,
) {
  let authorization = null;
  if (document.querySelector("meta[name=token]")) {
    const jwt = document.querySelector("meta[name=token]")['content'];
    authorization = "Bearer "+jwt
  }
  return fetch('/api', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'authorization': authorization,
    },
    body: JSON.stringify({
      query: operation.text,
      variables,
    }),
  }).then(response => {
    return response.json();
  });
}

const environment = new Environment({
  network: Network.create(fetchQuery),
  store: new Store(new RecordSource()),
});

export default environment;

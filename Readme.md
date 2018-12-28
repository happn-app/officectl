# officectl

## Compilation On macOS

**For macOS**
```bash
Scripts/build_for_macos.sh
```

**For Linux**
```bash
Scripts/build_for_linux_on_macos.sh
```
You’ll need to have Docker running.
I did not find a way to have ssh re-use the SSH auth sock of macOS, so I mounted the ssh private
key in the container (it is expected to be located at `$HOME/.ssh/id_rsa`). If a password is needed
to unlock the private key, the Docker uses the `ask_pass.sh` script (you must create it first in the
`Scripts` folder). The script should output the password of the private key.

The resulting built product will be in the `linux_build` folder.

## Project Structure

This is a standard `SPM` project, so the sources are in the `Sources` folder, then each source in the
folder named after the target it is a part of. The tests are in the `Tests` folder.

### The OfficeKit Target
Contains the library with which the `officectl` command line tool is built.

#### Model
The “OfficeKit” part of the model is used to represent objects used by OfficeKit directly.

The LDAP model contains a generic `LDAPObject` structure and some utilities. It also contains
some classes that match the LDAP schema RFC1274 (cosine) + RFC2798 (inetOrgPerson) and
the “core” scheme in OpenLDAP.

Other models are straightforward in general and used directly to store the results from different APIs.

#### Connectors & Authenticators
These are the classes that are responsible for connecting or authenticating the different services.

The connectors are responsible for “creating a connection” to a given service. For instance, for the
LDAP service, the connector will create the socket to connect to the LDAP server. For a REST
connector (e.g. GitHub), the connector will generate the token that will be used to authenticate
the requests made to this service.

The authenticators are responsible for “authenticating requests.” For instance, the GitHub authenticator
will add the required HTTP headers in an URLRequest.

An object can be both a connector and an authenticator at the same time. For instance, the
`GitHubJWTConnector` is both.

#### Operations
They are standard Foundation’s `Operation`s. For more information see below.

An operation represents a single unit of work, synchronous or asynchronous. The work can only
be executed once. The configuration can be done at init time, or after the init, but before the operation
is started. There are no rules on how to retrieve the results of an operation; usually the operation
stores the result and you retrieve it once the operation is over.

Usually, you’ll want to start an Operation in an OperationQueue, which allows operations to have
priorities and dependencies. The queue will launch the operations in the correct order depending
on these properties. Launching an Operation in the queue is particularly important for synchronous
operations: you probably don’t want to block your current thread until your operation is finished!

#### Actions
An action is like an operation, as they both represent a single unit of work.

Unlike an operation, an action is always asynchronous though, and **can** be retried.

Furthermore actions are *SemiSingleton*s too. Which means you must instantiate them via a SemiSingletonStore,
and can potentially retrieve an already executing action from the store. This has been done to avoid
launching two actions doing the same thing at the same time.

For instance, let’s say we have an action to reset a password. We instantiate the `ResetPasswordAction`
for user A and launch the reset. We can instantiate a *new* action for user B, but if we try to instantiating
the action for the user A, we will get the one we have already started.

### The officectl Target
This is the officectl executable. It features a command line, which can be used to launch the officectl server.

#### Commands
These contains the functions that are called directly from the command line. To search for the function
that get called when running `officectl backup mails`, you’ll go the `root/backup/mails.swift`
file.

The config of the available command line actions and parameters is done in the `guaka_config.swift`
file.

#### Server
The “Server” folder contains the controllers for the web server.

The config of the routes is done in the `setup_routes.swift` file.

#### main
A typical `Vapor` main, except the CLI arguments parsing is done via `guaka`. Everything you’ll want to
do will be in the `configure.swift` file; in particular registering the services and the middlewares is
done here.

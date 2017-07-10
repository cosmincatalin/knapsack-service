# Knapsack Problem Solving as a Service

## How to run the stack?

#### Prerequisites

This guide is targeting _MacOS_ system, as recommended in the assignment.
A recent version of _Docker_ must be installed and running.

#### Fetch the repository

`git clone git@github.com:cosmincatalin/knapsack-service.git` or `git clone https://github.com/cosmincatalin/knapsack-service.git`

#### Build

* `docker run -v ./knapsack-api:/scala-project cosmincatalin/sbt-assembly` - this will take a few minutes.
* `docker run --rm -v $(pwd):$(pwd) -w $(pwd) znly/protoc --python_out=knapsack-deap/src -I=knapsack-deap/protobuf knapsack-deap/protobuf/knapsack.proto`.

##### Run the solution

* `docker-compose up -d` - to start the stack.
* `docker-compose down` - to stop the stack.

## How to interact with the service?

The _API_ exposes two endpoints. One is used for submitting optimization requests, and the other one is used for fetching solutions.

### Ask to solve an optimization problem.

To make an optimization request you need to make a `POST` request and supply a `JSON` payload with a structure that follows this rule:

```
{
	"volume": <integer>,
	"items": <array> [
    {
      "name": <string>
      "volume": <integer>
      "value": <integer>
    }
	]
}
```

Example: `curl -X POST http://$(docker-machine ip):5000/solve -H 'cache-control: no-cache' -H 'content-type: application/json' -d '{"volume": 15,"items": [{"name": "knife", "volume": 1, "value": 10},{"name": "cup", "volume": 5, "value": 5},{"name": "laptop", "volume": 8, "value": 15},{"name": "phone", "volume": 1, "value": 12},{"name": "adaptor", "volume": 2, "value": 7},{"name": "watch", "volume": 1, "value": 1},{"name": "pants", "volume": 6, "value": 3},{"name": "camera", "volume": 4, "value": 9}]}'`.

On success, the `id` of the problem will be returned. Use this to ask for a solution to the other endpoint. Some typical request errors are being handled and informative messages are being sent back (Eg: a problem with no items.)

### Ask for the solution to a problem

Having the `id` of problem, you can ask for its solution. A solution is a `JSON` with the following schema:

```
{
	"items": <array> [
    {
      "name": <string>
      "volume": <integer>
      "value": <integer>
    }
	]
}
```

Example:

`curl -X GET 'http://'$(docker-machine ip)':5000/solution?id=24fb9e5a-ed4f-41ec-b6d6-a3fb1dc2e184' -H 'cache-control: no-cache'`

If the solution has not been computed yet, status `449` is returned. Also, if the engine decided that a solution won't happen, status `500` will be returned. Anything else is considered as `404`.

## Architecture

#### General Architecture

The architecture that was chosen focuses on flexibility and decoupling of components and concerns. It allows for easy horizontal scaling and is partially resilient as it is (via the message bus). It is a solid foundation for an application that can be auto-scaled in a production environment.

#### API

The frontend to the service is the _API_. It is multithreaded and very light. Its role is just to offload requests to a message bus and handle communication with the clients. It is essentially a proxy to the _engine_.

* Can be scaled horizontally if it is placed behind an autoscaling group.
* It is stateless, meaning that when of a cluster, different instances can serve a single client, without keeping track of sessions. This is also part of the reason while scaling can be done seamlessly.
* It is based on an established high performance

#### Database

The _API_ works with a database where problems are being recorded. Also the _engine_ writes solutions to the same database.

#### Message Bus/Queue

The _API_ forwards work via a _message queue_ (RabbitMQ being the chosen implementation). This allows for some desirable features:

* It enables decoupling between the _engine_ and the _API_.
  * A consequence of that is that the _engine_ can now easily be upgraded or replaced with different implementations in any language, not just JVM based.
* It acts as a buffer for the engine, allowing it to work at it's own pace, albeit with the risk of not keeping it up.
* It allows for the _engine_ to be scaled horizontally based on the size of the queue.
* It allows the _engine_ instances to act as _Competing consumers_, therefor distributing the load.

No special consideration has been made as to have a solid storage for RabbitMQ data. In the context of running docker locally I have chosen to consider messages as volatile. A production system would, of course, require more guarantees. Ideally a service such as _Amazon SQS_ or _Azure Queue Service_.

The _API_ is responsible for creating a queue if it does not exist. The _engine_ expects the queue to exist and will not create it, as it only needs to consume from it and not write to it.

###### Why use Protocol Buffers?

_Protocol Buffers_ is used behind the scenes in the backend of the service. It offers a few benefits:

* Seamless schema evolution. Adding a new field like `maximumNumberOfItems` is handled transparently when being added either from the producer or consumer.
* Less size overhead. While in this specific scenario, size is not a concern, in practice it can become an issue.
* Rich ecosystem of languages supported.
* Works out of the box with binary channels like _RabbitMQ_.

#### Knapsack Engine

The _engine_ is an implementation of the _Genetic Algorithm_ using the _deap_ library package.

* Simple set-up. Receives work from a queue, writes outcomes to a database.
* If it gets killed the rest of the service works fine, albeit with no new solutions being provided.
* Can be replaced by anything else that is able to read from the queue and write to a database.

## A graphical representation

#### Submitting a problem

![problem](problem.png)

#### Getting a solution

![problem](solution.png)

## Requirements discussion

- include a concise description of the design (architecture) of your solution - **DONE**
- include complete code needed to execute the solution - **DONE**
- use a build system with targets for building, testing, deploying, and executing the solution - Only the API needs to be built
  - Only the _API_ is actually built with a build system, _sbt_. The engine, doesn't need building per say.
- either contain all additional dependencies (e.g., external libraries, if you use any) or handle the download and installation thereof as needed (ideally, as part of the build process) - **DONE**
- include a concise instruction on how to start and use the solution - **DONE**

- start your solution as a single-process service on a local machine - The solution requires multiple Docker containers, so this is not technically achieved, but the impression is that of a single atomic service.
- interact with your solution on the command line - **DONE**
- submit a synchronous optimisation request - **DONE**
- terminate the running solution in an elegant way (i.e., not by killing the process). - Docker can be gracefully terminated via `docker-compose down`

- contain a discussion of the architecture, alternative designs, and justifications for choosing the one you chose - **DONEish**
- enable the user to run multiple, configurable instances of the service with parameters passed as command line options, environment variables, and/or in config files.
  - This is certainly possible. The two main components have environment variables exposed for fine tuning. A core feature of this service is that it is stateless and many instances of the components can run at the same time, albeit they need to communicate with the same database.
- enable the user to submit multiple asynchronous requests (jobs) - **DONE**
- provide logging and/or monitoring of a running service, possibly with a graphical dashboard - **DONEish** available by default with `docker-composer logs`. The level of detailed can be configured. No graphical touch however.
- provide a modular solution, with clear decomposition into functional (micro)services, running in separate processes and communicating through appropriate APIs - **DONE**
- provide a solution deployable on a remote machine or cluster, or in the cloud - **DONEish** the solution is not deployableas it is, the database and message bus need to be set-up in advance in a production grade system.
- allow the user to run the solution on any operating system by means of an abstraction layer (e.g., docker); **DONE**
- provide an elegant, intuitive graphical UI; **NOT**
- enable one to upload a custom optimiser implementing an API you specify (e.g., a python script with a class or function with appropriate signature, an OSGi bundle, an executable binary or compilable code, etc.) - **DONEish** anyone can provide a new custom solution engine as long as it is able to read from the message bus and write to the database. That is a pretty flexible scenario.
- enable authentication and authorisation, so that users can safely store their optimisation details in the system without exposing them to the public. **NOT** some additional services (Eg: Oauth) would have been required.

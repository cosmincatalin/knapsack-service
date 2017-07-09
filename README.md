# Knapsack Problem Solving as a Service

## How to run the stack?

#### Prerequisites

This guide is targeting _MacOS_ system, as recommended in the assignment.
A recent version of _Docker_ must be installed and running.

#### Fetch the repository

`git clone git@github.com:cosmincatalin/knapsack-service.git` or `git clone https://github.com/cosmincatalin/knapsack-service.git`

#### Compile the code

* `docker run -v ./knapsack-api:/scala-project cosmincatalin/sbt-assembly` - this will take a few minutes.
* `docker run --rm -v $(pwd):$(pwd) -w $(pwd) znly/protoc --python_out=knapsack-deap/src -I=knapsack-deap/protobuf knapsack-deap/protobuf/knapsack.proto`.

##### Run the solution

* `docker-compose up -d` - to start the stack.
* `docker-compose down` - to stop the stack.


## Architecture

```mermaid
graph TD;
    A-->B;
    A-->C;
    B-->D;
    C-->D;
```

## Knapsack API

**Knapsack API** is essentially a proxy to the _engine_.

* Can be scaled horizontally if it is placed behind an autoscaling group.
* It is stateless, meaning that when of a cluster, different instances can serve a single client, without keeping track of sessions. This is also part of the reason while scaling can be done seamlessly.
* It is based on an established high performance

#### Why use a message queue?

The _API_ forwards work via a _message queue_ (RabbitMQ being the chosen implementation). This allows for some desirable features:

* It enables decoupling between the _engine_ and the _API_.
  * A concequence of that is that the _engine_ can now easily be upgraded or replaced with different implementations in any language, not just JVM based.
* It acts as a buffer for the engine, allowing it to work at it's own pace, albeit with the risk of not keeping it up.
* It allows for the _engine_ to be scaled horizontally based on the size of the queue.
* It allows the _engine_ instances to act as _Competing consumers_, therefor distributing the load.

No special consideration has been made as to have a solid storage for RabbitMQ data. In the context of running docker locally I have chosen to consider messages as volatile. A production system would, of course, require more guarantees. Ideally a service such as _Amazon SQS_ or _Azure Queue Service_.

The _API_ is responsible for creating a queue if it does not exist. The _engine_ expects the queue to exist and will not create it, as it only needs to consume from it and not write to it.

#### Why use Protocol Buffers?

_Protocol Buffers_ is used behind the scenes in the backend of the service. It offers a few benefits:

* Seamless schema evolution. Adding a new field like `maximumNumberOfItems` is handled transparently when being added either from the producer or consumer.
* Less size overhead. While in this specific scenario, size is not a concern, in practice it can become an issue.
* Rich ecosystem of languages supported.
* Works out of the box with binary channels like _RabbitMQ_.

## Knapsack Engine

The _engine_ is an implementation of the _Genetic Algorithm_ using the _deap_ library package.

* Simple set-up. Receives work from a queue, writes outcomes to a database.
* If it gets killed the rest of the service works fine, albeit with no new solutions being provided.
* Can be replaced by anything else that is able to read from the queue and write to a database.

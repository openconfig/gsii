# gSII Motivation
Contributors: {robjs, vasilis}@google.com  
May 2024


> [!NOTE]
> For SDN applications there are cases where there is a need to manipulate
> parameters that are traditionally part of a WBB device's' "configuration" in
> a manner that allows for faster application, and ephemeral application. This
> document defines an extension to the g* suite of protocols (a new gNMI
> sub-service) that allows for control-plane systems to manipulate such
> parameters, and coexists with existing configuration.

## Background

In a “hybrid” SDN network - i.e., one that consists of both on-device
controllers (e.g., vendor NOS components such as routing protocols) and off-box
controllers, there is a need for each set of controllers to manipulate the
state of a network device. A significant amount of this state is covered by the
device’s configuration – and hence APIs that manipulate the config can be used
to control it. For example, a SDN controller application that implements some
form of egress traffic engineering may create static MPLS label state on a
network device through creating MPLS LSPs within the configuration. As we have
evolved the ecosystem around such hybrid SDN applications – we have defined new
APIs to be able to manipulate some of the state of a network device in a more
dynamic manner than can be achieved by the configuration. For example, gRIBI
was [motivated
by](https://github.com/openconfig/gribi/blob/master/doc/motivation.md) a need
to inject routing entries in a manner that was incompatible with the
configuration APIs based on the need for fast application, per-entry rather
than per-transaction validation, and at a scale at which treating the state as
static configuration would introduce significant complexities in terms of
configuration scale. P4RT provides a similar mechanism when considering
injecting FIB state – i.e., directly adding forwarding entries without
considering the RIB.

These mechanisms allow for certain subsets of the state of a network device to
be dynamically controlled independently of the configuration of a network
device, however, they do not cover all the state of a network device. As new
applications are proposed within such hybrid SDN environments, we observe that
there is a requirement to manipulate state that is not RIB or FIB state in a
more dynamic manner. This document discusses the use cases for such state
manipulation, and proposes a solution to meet this requirement.


### Prior Art

As with most ideas, we acknowledge that we are not the first observers of this
problem space. Particularly, there is much discussion in RFC7921 and RFC8242
for a need for a means to be able to manipulate the “ephemeral” state of a
network device. Whilst this observation was made – we observe that there is not
a widely-available standardised means to be able to meet these requirements,
and the requirements are incomplete when considering a SDN system design where
there may be concepts such as multiple redundant controllers, and a need for
reconciliation - which are not typical of today’s configuration generation and
application systems within modern management planes.

JUNOS’ [ephemeral config
database](https://www.juniper.net/documentation/us/en/software/junos/junos-xml-protocol/topics/concept/ephemeral-configuration-database-overview.html)
provides a solution to a subset of the requirements described in this document.


## Use Cases

### Fast Device Drain

A typical mitigation action when experiencing a network fault is to “drain” a
device that has been pin-pointed as the root cause of a fault – in such
situations, the mean time to recover (MTTR) of the network is defined based on
the time to identify the device to be drained, compute the change required to
remove it from service, and apply the change to the device. “Drain” actions can
consist of multiple types of actions – for example, shutting an interface or
interfaces down, applying the IS-IS overload bit, or applying a new BGP policy
to stop route announcements occuring. In all these cases, it is desirable that
the drain action:

*   Is applied quickly (so as to minimise the MTTR).
*   Does not require significant validation.
*   Can be triggered by an entity outside of the NOS which has knowledge of the
    safety and logic to apply to remove traffic from the device – which can be
    operator specific.

In these cases, it is desirable for a controller entity to be able to quickly
manipulate interface or protocol configuration, in a way that the device
applies in the lowest-latency way possible.

### Custom Routing Policy Logic

In a network utilising eBGP – policy logic is used to control the routes both
accepted and advertised to peers. As BGP security mechanisms evolve, new route
characteristics that are not encapsulated in BGP attributes are being used to
make routing decisions. One example is that of RPKI ROA status – where the RPKI
validation state of a route is one of the characteristics that is considered
before accepting a route. RFC8210 describes the RTR protocol that can be used
to communicate explicitly this information to a router from an RPKI cache –
however, it does not consider other cases where some external logic is needed
to consider how a BGP route should be handled. For example, systems that
manipulate prefix announcements dynamically based on observed load, or reject
routes based on security characteristics other than their RPKI ROA status
cannot easily use such a system. In such cases, it is desirable to have a
mechanism to be able to quickly manipulate routing policy logic from a
device-external source, in a manner that is applied quickly.


### Custom Quality of Service Policies

In networks that are providing L2/L3VPN services – often connectivity is
offered to customers in terms of a committed bandwidth to an end site. In the
case that such end sites are connected by multiple ports, there can be a need
to have product-specific policies defined as to the allowed traffic rate from
each port. Whilst these approaches can statically define a committed bandwidth,
and a maximum data rate – this leads to cases suboptimality in some cases.
Consider a site that has two downstream connections, with a committed data rate
of 50Gbps across the two – a static configuration must consider whether each
port gets a 50Gbps “CIR” (which could lead to >50Gbps “in contract” traffic
being accepted) if the customer site sends >50Gbps traffic split across the two
ports, or whether 25Gbps is offered to each port - which requires the customer
splits their traffic equally across the two ports, and cannot send the
contracted rate of “in contract” traffic during a single port outage. The ideal
solution in such a case is to have a dynamic CIR per port – with the ability to
adjust the committed rate per port based on the operational state of the
network.

To do so, configuration that has typically been static – QoS policy rate
parameters – becomes dynamic, and must be manipulated in a way that reacts to
the real-time state of the network, significantly increasing its churn rate
over and above that which is expected of the devices’ configuration today. In
such a case, a means by which these parameters can be manipulated quickly, and
can be triggered by an NOS-external application.

## Requirements

* **[R1]** The elements that are able to be changed more rapidly should be _in
  addition_ to the current static “intended” state of a device. It should be
  possible to fall back from the configuration that is provided to the current
  static intended state of the device.
* **[R2]** The semantics of the RPC that is used for configuration set should
  support concepts coherent with control plane applications – e.g., those that
  are implemented by gRIBI. Particularly:
    * **[R2.1]** There must be a means to have multiple writers of data – with
      defined prioritisation between them.
    * **[R2.2]** It must be possible for the presence of written data to be
      tied to the liveliness of the session with the control-plane system _or_
      statically persisted after the failure of the primary controller.
* **[R3]** The API provided must be asynchronous – rather than the current
  synchronous `Set` provided by gNMI. Each “write” should be responded to
  individually with an ACK, or NACK.
* **[R4]** It must be possible to relate the rapidly-changing state to that
  which is provided by current “configuration” APIs. Particularly, it should be
  possible to understand what the rapidly-changing state is, what the current
  intended state is, and subsequently what the applied state is.
* **[R5]** Authentication, and authorisation of the API should use standard
  mechanisms that allow for both RBAC, as well as payload authentication (e.g.,
  path-based authentication).
* **[R6]** The solution must coexist with gNMI-based configuration
  manipulation, and OpenConfig-modelled intended, applied and operational state
  (as defined by
  [draft-openconfig-netmod-opstate](https://datatracker.ietf.org/doc/html/draft-openconfig-netmod-opstate-01)).
* **[R7]** Performance requirements [TBD]

## Proposed Solution

To meet the requirements above, we propose a new service which extends
[gNMI](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md).
Whilst the service will re-use a number of the primitive message types from
gNMI it will provide a streaming `Modify` RPC, similarly to the `Modify` RPC
provided by gRIBI. The new `Modify` RPC is defined to be a bidirectional
streaming RPC.

The payload of the RPC is defined to be a single data structure consisting of a
path, an operation (`ADD` or `DELETE`[^1]), and a payload (for the `ADD`
operation).  The data structure consists of a subtree (which may consist of a
single leaf). The proposed modelling approach for this data is discussed below.

Responses are provided by the server in response to each `SetOperation` that is
sent by the client using an operation identifier to correlate transactions.
Errors are reported as RPC responses, unless the error is fatal for the
session.

Similarly to gRIBI, an initial handshake at the start of the `Modify` RPC
determines:

*   Leader election – as with gRIBI it is expected that elections happen
    outside of the target, and the target is solely responsible for enforcing
    that the `election_id` received in each `SetOperation` corresponds to the
    `election_id `that is the current master
*   Persistence mode – determining whether the failure of _this_ controller’s 
    RPC results in the received input being flushed, or it is rather flushed
    only when specified by an explicit signal.

In order to allow for removal of all entries in a failure case, a `Flush` RPC
will be provided to remove dynamically written state that is being persisted.
In order to reconcile after restarts, controllers will use gNMI’s existing
`Subscribe` RPC.

The `v1/proto/gsii/gsii.proto` file in this repository contains the protobuf
defining the gSII service.

### Data Modelling

Data that is provided through the service will be modelled data – and MUST have
a tree format similarly to gNMI. No constraints are placed on the modelling
language that can be used via this interface as long as this tree format is
maintained.

The primary format for which this service is intended to be used is
OpenConfig-modelled data. As such:

*   Paths specified in input messages MUST therefore correspond to a path within
    an OpenConfig model.
*   The payload MUST represent a leaf or container within the OpenConfig schema.

The gNMI `TypedValue` message that is used as the payload <span
style="text-decoration:underline;">could</span> contain multiple different
types of data. As a starting point we propose only using `proto_bytes `as this
input format. This has advantages over `json_ietf_val` since:

*   The on-the-wire data volume is significantly smaller if a subtree is
    provided - since string values that make up the `path` are no longer
    encoded.
*   A protobuf value can be generated from a YANG schema using the ygot suite
    of tools, and this approach is well-proven in gRIBI.
*   Since limited/no validation will need to occur in this scenario – and
    control plane systems likely do not already support YANG-modelled data,
    this increases the applicability of this interface beyond languages that
    have existing YANG tooling ecosystems. The advantages of YANG over protobuf
    tend to be in its ability to express more detailed constraints around the
    data that is carried in the message. In the case that smaller subsets of
    state are being updated, there is little to no need for this
    cross-validation within a wider tree.

It is not our initial expectation that every OpenConfig subtree be supported
via this new API – since clearly there are some cases where strong validation
is needed (e.g., dynamically being able to remove a linecard would mean also
invalidating many other entities that depend on that linecard and its
interfaces - so it does not seem a good candidate for the mechanisms
described in this document). Therefore, we propose that where payloads are
generated for the `Modify` RPC, we give these a new place within the OpenConfig
schema, particularly, defining a new
`volatile`/`ephemeral` subtree to correspond with the `config` and
`state` subtrees within the schema. Considering the case of an interface
`enabled` leaf, we would therefore propose to have:

*   `/interfaces/interface/config/enabled` – today’s intended state, and
    written by a standard gNMI client.
*   `/interfaces/interface/state/enabled` – today’s applied state, indicating
    the value that the system is currently running.
*   `/interfaces/interface/volatile/enabled` – a new path, indicating that this
    path can be written to via the `Modify` RPC.

The latter path can be added to a YANG tree via an `augment` in a specific
dynamic module, allowing the subset of paths that are writable to be
discovered. Protobufs would be generated or written to correspond to the
`volatile` path.

The `volatile` path SHOULD be streamed via gNMI `Subscribe` as per the existing
expectations around the `config` path.

> [!NOTE]
> The naming volatile is chosen for this "more dynamic" configuration based on
> fact that:
>  * This state can be cached in volatile storage (i.e., stored only in memory
>    that is available when the device is powered on).
>  * It corresponds with the idea of `volatile` variables in C-like programming
>    languages, where a different reader/writer may access this value (mostly,
>    we expect that volatile paths are written to by different systems than
>    NMSes, namely control-plane entities).
>  * Such state is expected to be liable to rapid change, corresponding to the
>    common English definition of volatile.

#### Determining the System's applied state value

Today, the intended state (`config`) path is the value that a client expects
the target to be running for the specified leaf. With the introduction of the
`volatile` path, there is a requirement to choose between the `config` and the
`volatile` path.

It is proposed that the target adopts the rule of:

 * if the `volatile` leaf is present, this is the preferred value and should
   be used,
 * if no `volatile` leaf is present, the intended state (`config` path) should
   be used.

with a strict preference to prefer the volatile configuration value. In the case
that the `volatile` value is removed (e.g., due to an RPC failure with a
persistence mode that indicates that the values should be cleared on RPC
failure), the system should apply the `config` value if one is present.

### Validation Requirements

In order to ensure that the application time of the configuration is minimised
– some relaxation in validation is required. Particularly, we do not expect
that a target system performs complete validation of the input data before
indicating the transaction is to be applied – as is required in `gNMI.Set`.
Thus, it is expected that <span style="text-decoration:underline;">any</span>
syntactically valid input is accepted, and the system tries to apply such a
value. In the case that a failure occurs, a `NACK` is returned via the
`ModifyResponse` and the client system is responsible for providing additional
to roll the target forward to its expected state. No rollback is provided via
`Modify`.

The target should honour the order of transactions only on a per-path basis –
i.e., repeated operations for `/a` of `1` → `2` → `3` should result mean that
the target does not apply the update with value `2` after value `3`. This
assumes the existence of a coalescing queue on input. The client SHOULD NOT
assume that transactions for different paths are processed in the order in
which they are received.

### Persistence of Configuration

Like other control-plane protocols, the "volatile" configuration of a device
is not expected to be persisted across device reboots. Data that is written
via gNMI to a `config` path is expected to be persisted (saved to non-volatile
storage) after each transaction. Not requiring persistence of data across 
reloads allows both for the target device to avoid the cost of writing the 
configuration to persistent storage (potentially reducing throughput); as well
as models where a "default" value is written to a persistent `config` path,
and an amended value is written to the `volatile` path according to some
runtime condition of the wider network system.

Note that `persistence` within the service definition refers to persistence
across RPCs (i.e., clients connecting or disconnecting) not across device
reboots.

It is expected that volatile configuration persists across device control-plane
card switchovers (simililarly to gRIBI) such that a client switchover does not
require an external controller to re-push the volatile configuration.

### Security

The proposed service should:

*   Be authorized using `gnsi.Authz `policies.
*   Be accounted using `gnsi.Acctz`.
*   Be subject to `gnsi.Pathz` policies – using the path within the
    `ModifyRequest`.

<!-- Footnotes themselves at the bottom. -->
## Notes

[^1]:
     In practice, gRIBI’s explicit `REPLACE` has added little value – applying
lessons from other systems, the semantics of `ADD` were clarified to allow
implicit replace operations, which in turn avoids errors being created in the
case of duplicate `ADD` operations, given this modification, there is little
reason to use `REPLACE` other than to check whether there was prior contents.


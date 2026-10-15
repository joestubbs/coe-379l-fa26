Requirements and Formal Specifications 
======================================

In this introductory lecture, we tackle the following question: 

  *How do we state the intended behavior of a system in a mathematically precisely enough way to reason about it?*

Typically, we begin with requirements in natural language, which are useful for a variety of different users, 
including developers, QA, product and project managers, etc. However, these natural language descriptions tend 
to be imprecise, and the ultimate goal is to refine these into a mathematically exact specification. 

A *formal specification* expresses a requirement in a language with precisely defined syntax and
semantics. *Formal* here means means that the statement has an interpretation precise enough
that we can determine what would satisfy or violate it mathematically. 

In this lecture, we'll use the Laboratory Agent software system to examine how we go from an informal requirement to a
formal property. We won't be using proofs just yet. Rather, the current goal is to learn how to identify the
objects, states, transitions, assumptions, and predicates that will form the foundation that proofs will 
interact with in a subsequent lecture. 

By the end of this module, students should be able to:

* distinguish a requirement, model, specification, implementation, and proof
* explain the difference between validation and verification
* recognize ambiguity in apparently reasonable natural-language requirements
* express simple requirements as predicates over inputs, states, and transitions
* distinguish preconditions, postconditions, and invariants
* explain why abstraction is necessary and what information an abstraction may lose

Imprecise Natural language Requirements 
----------------------------------------

Software requirements written in natural language are inherently imprecise, sometimes in ways that 
are deceptive. Consider the following example: 

  *Only authorized users may reserve equipment.*

On the surface, this requirement may seem reasonable. But in fact, there are many details that 
have been left out. For example: 

* What does *authorized* mean? Does it simply mean being a member of the lab? Does it require membership in a project? 
  Does it require equipment training? Perhaps all of the above? 
* When does the authorization have to be valid? Is it when the tool is reserved? Is it when the tool will be used; i.e., the 
  scheduled time of the reservation? And if the latter, is it at the beginning of the reservation, at the end, or throughout 
  the entire time period? 
* Does *equipment* include every resource or only certain resources governed by this policy?
* What should happen if authorization information is unavailable?

These are questions for which individuals could reasonably have very different answers, and different answers produce 
different systems with different desirable properties and different proof obligations.

Consider one more example: *what should happen to an unauthorized call?*  
Again, the requirement is not clear, and there are multiple valid interpretations. 

Here are some possible ones: 

1. Unauthorized calls must not succeed.
2. Unauthorized calls must not be dispatched at all. 
3. The proposed user must be authorized. 
4. The authenticated user must be the reservation owner and must be authorized.

On the surface, these may seem similar, but in fact, the required properties (and associated proofs establishing that the 
system has the property) vary in ways that matter for what will be checked.

For example, 1) might be interpreted as a property about the response from the tool call; 2) is a property that states that the tool call was 
never made in the first place; 3) states that the proposed user must be authorized but seems to allow for the proposed 
user to be different from the calling user; and 4) eliminates that possibility, requiring that the authenticated user and 
the proposed user must be the same. 

How might we tighten the requirement to remove the ambiguity? Try to rewrite it in one or two sentences so that it 
addresses the following: 

1. Which user is being authorized?
2. For which project and resource?
3. At what point in the execution?
4. Is the prohibited event a proposal, dispatch, or successful reservation?


Here is a potential solution: 

    *Before the application dispatches a reservation request, the requested reservation owner must
    equal the authenticated user, and that user must have current authorization for the specified
    project and resource at the time of dispatch.*

This is definitely an improvement, but it still leaves some ambiguity. Can you think of anything 
left out? For example, it doesn't explicitly address which equipment the policy applies to or what should happen 
if authorization information for the user is not available. 


The Objects of Formal Reasoning for Software 
---------------------------------------------

When attempting to apply formal methods to software system, we must contend with several important, related objects.
We'll adopt the following definitions: 

* Requirement -- A desscription of the behaviors stakeholders intend for the system. 
* Formal system model (or just *model*) -- A mathematical representation of certain aspects of the system that we wish to 
  analyze 
* Specification -- A descriptions of the precise mathematical properties we wish to establish about the system model. 
* Implementation -- The executable system that will actually be deployed and run. 

In the above, we allow for requirements to be specified in natural language, while a specification (or we may refer to 
a *formal specification* for emphasis) must be mathematically precise. It will thus typically use mathematical 
notation. 

Then, the practice of applying formal methods to software usually involves two activities: 

* *Validation* -- The process of establishing that a requirement of formal specification actually represents the 
  desired properties of the stakeholders. 

* *Verification* -- The process of establishing that the model or implementation satisfy the specification. 

In this class, we will be focusing on verification, but it should be noted that validation is equally important. If we 
have not validated that our specification actually reflects the desired outcomes, our verification process could lead 
to proving the wrong theorems. 


Program States, Transitions, Propositions, and Predicates 
---------------------------------------------------------

For a given program, we previously defined its state space as the set of all variables and their values and a 
program trace is a precise set of values for each variable at all given 
instruction steps, starting with step 0. Mathematically, we can define all of this as follows. 

Suppose the program uses variables :math:`z_1, ..., z_n` with each :math:`z_i` taking values in domain :math:`D_i`. 
The (abstract) state space then is the product of the domains, :math:`S = D_1 \times ... \times D_n`, and 
we can think of a specific program trace as a function 
:math:`T: \mathbb{N} \to (\prod_i D_i)` where :math:`T(m)` maps the :math:`m^{th}` instruction step to the 
asssigment of all variables to their associated values. 

We can choose to model *variables* at different levels of specificity and/or abstraction. For example, it is common 
to represent the program call stack and the heap (dynamically allocated memory) separately. For our 
lab agent software, we can choose to use a higher-level abstraction and define the variables as follows: 

* :math:`R` = trusted request objects 
* :math:`M` = input messages 
* :math:`T` = finite sequences of trace events 
* :math:`E` = estimator states 
* :math:`B` = set of step budgets for the agent loop; i.e., :math:`b_1, ..., b_{max}`
* :math:`C` = control phases (i.e., *requested*, *validating*, *awaiting clarification* , *finished*)

The state space, :math:`S`, would then be the cartesian product: 

.. math::

  S = R \times M \times T \times E \times B \times C`

Then, within a single execution of the program, we can specify the values of the variables at a given execution 
step with a tuple, :math:`s = (r, m, t, e, b, c)`. A full program execution trace then corresponds to a sequence 
of these tuples, one for each program step. This can be represented mathematically as a function: 

.. math:: 

  \pi: \mathbb{N} \to S = R \times M \times T \times E \times B \times C


where :math:`\pi(j)` corresponds to the set of values for each of the variables at step :math:`j`. If there are 
only finitely many steps in the trace, then we could instead write: 

.. math:: 

  \pi: \{0, 1, ... n\} \to S

where :math:`n` is the number of steps. 

State Transitions 
^^^^^^^^^^^^^^^^^
Suppose an instance of the program is in state :math:`s\in S` at step :math:`t`, and then, after a single execution, 
moves to state :math:`s^\prime\in S` at step :math:`t+1`. In this case, we say that the program *transitioned* from 
:math:`s` to :math:`s^\prime` (at step :math:`t`) and we define the tuple :math:`(s, s^\prime)` to be the *transition*. 
A transition is therefore an element of the product :math:`S\times S`.

Propositions 
^^^^^^^^^^^^

We will write :math:`Prop` for the collection of all logical propositions. 
A proposition is a statement that may be true or false, such as “the resource is available” or “the proposed
user equals the authenticated user.”

We are keeping this initial definition intentionally non-technical for now. Later, when we introduce Lean, 
we will make the notion of :math:`Prop` more technical. 

.. note::

   :math:`Prop` and the data type ``Bool`` (from Python, say) play slightly different roles. A value of 
   type ``Bool`` is executable data in some program: it is either ``true`` or ``false``. A value of 
   ``Prop`` is a logical statement that typically requires a proof. This distinction will make more sense later 
   as we cover Lean. 

Predicates 
^^^^^^^^^^
In general, a *predicate* is a property that may hold or fail for one or more elements of a set. 
Commonly, we will think of predicates for software verification as  
a propositional-valued function over a product space of the program's state space, i.e., a map 
:math:`P: \prod_i S_i \to Prop`. The most common cases are unary and binary predicates over a single copy 
and a product of two copies of :math:`S`, respectively. 

Let's look at a few specific predicates that are worth naming. 

The *initial-state predicate* identifies where executions are allowed to begin. It is defined as: 

.. math:: 

    Init : S \to Prop 

In other words, if :math:`Init(s)` is false for some value :math:`s\in S`, then the program cannot begin with the initial 
values described by :math:`s`, while if :math:`Init(s)` is true, then the program emits an initial state described by 
:math:`s`. 

Similarly, the *transition predicate* identifies allowable state transitions. We put: 

.. math:: 

    Next : (S \times S) \to Prop 

and then if :math:`Next(s, s^\prime)` is false, it means there is no program trace that emits a transition from state 
:math:`s` to state :math:`s^\prime`. 


Some Lab Agent Examples 
^^^^^^^^^^^^^^^^^^^^^^^

Suppose :math:`S` is the system-state space, :math:`U` is the set of users,
:math:`P` is the set of projects, and :math:`E` is the set of equipment resources.
We can introduce the predicate

.. math::

   \operatorname{Authorized}:S\times U\times P\times E\to Prop.

The proposition

.. math::

   \operatorname{Authorized}(s,u,p,e)

means that, in state :math:`s`, user :math:`u` is authorized under project
:math:`p` to use equipment :math:`e`.


Note that we still must actually define what :math:`\operatorname{Authorized}` means. For example, does it require:

* membership in the project
* a current laboratory-safety qualification
* equipment-specific training
* a policy version effective at the time of the request?

Thus, with the above we have inly begun to define a precise :math:`\operatorname{Authorized}` predicate. 
More on this to come.. 

Combining Conditions: Conjunction (:math:`\land`) and Disjunction (:math:`\lor`)
---------------------------------------------------------------------------------

We have seen how to define a single predicate such as :math:`\operatorname{Init}` and :math:`\operatorname{Next}`. 
But typically, a rule about a software system usually involves multiple conditions working together. To build these 
compound rules, we rely on two fundamental logical connectors: conjunction and disjunction.

Conjunction (:math:`\land`): The "And" Operator
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
The "And" OperatorA conjunction, denoted by the symbol :math:`\land`, combines two or more predicates where 
all of them must be true for the overall statement to hold. 

* We use the notation: :math:`P \land Q` and it is read ":math:`P` and :math:`Q`"

For example, if :math:`P(u)` is the predicate that user :math:`u` is a member of a given project, and if 
:math:`Q(u)` is the predicate that user :math:`u` has a current lab-safety qualification, then :math:`P(u) \land Q(u)`
is the predicate that the user is **BOTH** a member of the project and has a current lab-safety qualification. 


Disjunction (:math:`\lor`): The "Or" Operator
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
A disjunction, denoted by the symbol :math:`\lor`, combines predicates where at least one of them 
must be true for the statement to hold. 

* Notation: :math:`P \lor Q` and it is read :math:`P` or :math:`Q`"

Continuing with the example above, if :math:`P(u)` is the predicate that user :math:`u` is a member of a given project, and if 
:math:`Q(u)` is the predicate that user :math:`u` has a current lab-safety qualification, then :math:`P(u) \lor Q(u)`
is the predicate that the user is **EITHER** a member of the project or has a current lab-safety qualification. 


Quantifiers and Implications
-----------------------------

We have talked about program states, transitions, and predicates as specific execution steps or 
snapthots. We may evaluate a variable at a specific moment, or check a single execution step. 
But as we know, real software systems run across thousands, millions, or even an infinite number of 
possible execution paths.

When writing formal requirements, we can't inspect every single state manually. Instead, we need a way 
to make statements about collections of states or behaviors all at once. The logic tool we use for these 
situations are called *quantifiers*. Quantifiers allow us to talk about all possible outcomes or 
some specific path through a system without listing them one by one.

Universal Quantifier
^^^^^^^^^^^^^^^^^^^^

First we introduce the *universal quantifier*, denoted by the symbol :math:`\forall`. 
(This is an upside-down 'A' for 'All'). We use the universal quantifier within logic statements to refer to 
all objects within a set. 

For example, let :math:`S` be a set, and let :math:`P` be a predicate over :math:`S`. 
We write 

.. math:: 
    
    \forall s \in S, P(s) 
    
to assert that predicate :math:`P` must be True for every single element :math:`s` in the set :math:`S`.
Note that this is the meaning of the statement regardless of whether :math:`S` is a finite or infinite set.

To give an agent lab example, let :math:`R` be the set of all trusted requests. Then we might have: 

.. math:: 

    \forall r \in R, r.user\_id \not= None

What is the meaning of this statement? 


Existential Quantifier 
^^^^^^^^^^^^^^^^^^^^^^

The second important quantifier we will introduce is the *existential quantifier*, written :math:`\exists` (like 
a backward "E" for "exists"). We use the existential quantifier within a logic statement to state that there exists an element 
with some property. 

For example, let :math:`S` be a set and :math:`P` a predicate over :math:`S`. Then the statement 

.. math:: 

    \exists s \in S, P(s)

states that there exists an element :math:`s` in the set :math:`S` such that :math:`P(s)` is true.  
The phrase *there exists* is synonymous with *there is at least one* or *there exsits one*. Like with 
the universal quantifier, the existential quantifier has the same meaning regardless of whether 
:math:`S` is a finite or infinite set --- there is at least one element with the property. There could be 
more than one, it could even be that every element of :math:`S` has the property, but it cannot be the 
than none have it. 

Logical Implication 
^^^^^^^^^^^^^^^^^^^

We can now use mathematically precise language to describe *all* elements in a sets (e.g., all state transitions) 
using :math:`\forall` and the existence of *some* element (e.g., some state) with :math:`\exists`, but 
we need a way to link conditions together. In software requirements, we rarely deal with isolated facts. 
Instead, we deal with conditional obligations: If a certain condition is true, then a specific 
outcome must follow.

For this, we use logical implication, denoted by the arrow :math:`\implies`. An implementation statement 
takes the form 

.. math:: 

    P \implies Q 

and is read ":math:`P` implies :math:`Q`" or "if :math:`P` then :math:`Q`". Here: 

* :math:`P` is called the *premise* (alternatively, the *antecedent*, *precondition*, or *hypothesis*).
* :math:`Q` is called *consequent* (or the *postcondition*). 

In formal systems, implications are how we describe properties or rules that only hold true under certain 
conditions. 

Examples 
^^^^^^^^

For example, let :math:`a\in A` be some action, let :math:`\operatorname{SafeAction}(a)` be 
the predicate that the action :math:`a` is safe, and let 
:math:`\operatorname{Dispatched}(a)` be the predicate that :math:`a` was executed. Compare: 

.. math::

   \exists a,\quad \operatorname{SafeAction}(a)

with:

.. math::

   \forall a,\quad
   \operatorname{Dispatched}(a)
   \Longrightarrow
   \operatorname{SafeAction}(a).

*Discussion:* What do these mean, and which one is more desirable? 

The first says at least one safe action exists. That is (hopefully) pretty useless as a system-safety claim. 
The second statement makes a much stronger claim: it says that every dispatched action is safe.

The use of words such as *all*, *every*, *some*, *eventually*, *never*, *before*, and *until* in 
natural language requirements often conceal the
logical structure of a requirement. Formalization forces us to make those structures mathematically 
precise.


A More Involved Example
^^^^^^^^^^^^^^^^^^^^^^^

Let:

* :math:`r` denote the trusted request
* :math:`a` denote a proposed action
* :math:`s` denote the state immediately before dispatch and 
* :math:`s'` denote the state afterward

We might define:

.. math::

   \operatorname{Bound}(r,a)
   \;\stackrel{\mathrm{def}}{:=}\;
   a.\mathit{userId}=r.\mathit{authenticatedUserId}.

.. math:: 

   \operatorname{DispatchReserve}(s,r,a)
   \;\stackrel{\mathrm{def}}{:=}\;
   a \text{ is a reservation and is dispatched}


(*Question: what kind of objects are* :math:`\operatorname{Bound}` and :math:`\operatorname{DispatchReserve}`?)

We might then express a requirement as follows:

.. math::

   \forall r,a,s,\quad
   \operatorname{DispatchReserve}(s,r,a)
   \Longrightarrow

.. math:: 

   \operatorname{Bound}(r,a)
   \land
   \operatorname{Authorized}
      (s,r.\mathit{authenticatedUserId},a.\mathit{projectId},a.\mathit{resourceId}).

What is the natural language description of this statement? 


    *For every request, proposed action, and pre-dispatch state, if the application dispatches that
    action as a reservation, then the action is bound to the authenticated user and that user is
    authorized for the proposed project and resource in the pre-dispatch state.*

This formulation makes several choices mathematically precise:

* The property applies to every modeled request, action, and state.
* It constrains dispatch, not merely successful completion.
* It uses the trusted request identity rather than trusting a model-generated identity.
* Authorization is evaluated in the state immediately before dispatch.


Preconditions and Postconditions
--------------------------------

Formal specifications frequently organize properties around an operation.

Preconditions
^^^^^^^^^^^^^

A *precondition* describes what must hold before an operation is permitted or before its advertised
guarantee applies. Often, a precondition is described by a predicate. 

For example, let :math:`s` denote the current state, :math:`r` denote the trusted request, and :math:`a` the action. 
For an abstract reservation operation, we might define:

.. math::

   \operatorname{Permitted}(s,r,a)

to be the predicate that the action is permitted for the give request in the current state. Then this predicate 
could be the precondition for the operation of executing a ``reserve_resource`` action. 

Note that the actual definition of this predicate could include references to the request, authorization, 
resource availability, calibration, and so on. The exact definition will depend on the policy.


Postconditions
^^^^^^^^^^^^^^

A *postcondition* describes what must hold after an operation returns.
Often, preconditions and postconditions are tied together by the opertation in an implication. 

For instance, continuing with the example above, let :math:`: \operatorname{ReserveSucceeded}(o)` be 
the predicate that a reservation operation succeeded. 
Then, if :math:`s^\prime` is some future state, and :math:`\operatorname{MatchingReservationExists}(s',r,a,o)`
is the predicate that a matching reservation exsits in state :math:`s^\prime`, then we might write 
the following requirement: 

.. math::

   \operatorname{Permitted}(s,r,a)
   \land
   \operatorname{ReserveSucceeded}(o)
   \Longrightarrow
   \operatorname{MatchingReservationExists}(s',r,a,o).

We can read this as saying that if the precondition was met and the operation reported success, then the resulting state
contains a matching reservation. To increase the usefulness of the statement, :math:`\operatorname{MatchingReservationExists}` 
should specify which fields must agree: user, project, resource, interval, and perhaps a returned reservation
identifier.

Note that the use of an implication means the conclusion is conditional. We are not saying that the operation must 
succeed whenever it is permitted. The system could experience a failure after checking if the action is permitted but before the 
reservation is made. 

Invariants, Safety and Liveness Properties 
-------------------------------------------

We now have enough mathematical foundation to express the invariants, safety and liveness properties in 
precise terms. We begin with invariants. 

Invariants
^^^^^^^^^^

As we mentioned in the previous lecture, an *invariant* is a property that should hold in every reachable state.
We can express an invariant using a universal quantifier. 

First, note that an implication statement can be true if it doesn't meet its precondition. For example, 
consider the statement :math:`\forall s \in \{ 1, 3, 5\}, \operatorname{Even}(s) \implies s=0` where 
:math:`\operatorname{Even}` is the predicate that checks whether an integer is even. This statement is 
true because no elements meet the precondition: if :math:`s\in \{1, 3, 5\}` then :math:`s` cannot be even. 
In some sense, there are no :math:`s`'s to check the conclusion against. 
In such a case, we sometimes say the statement is *vacuously true*. 

Now, let us consider the following example dealing with reservations in the lab agent system. 
An invariant might be:

.. math::

   \forall s \in \operatorname{Reachable},\quad
   \forall q \in \operatorname{ConfirmedReservations}(s),\quad
   q.\mathit{owner}=q.\mathit{authenticatedRequester}.

This invariant can be read as follows: 

  *For every reachable state, s, and for all confirmed reservations at state s, the owner of the 
  reservation must be the same as the authenticated user.*

Note that it is entirely possible that, at some reachable state, :math:`s`, there will be no confirmed 
reservations. In that case, the predicate is vacuously true -- there is nothing to check. However, if there 
are reservations, then the implication has content. 


Safety, Liveness, and Termination Revisited
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In the preceding lecture, we introduced the following definitions:

* **Safety Property** -- Something bad never happens.
* **Liveness Property** -- Something good eventually happens.
* **Termination Property** -- A particular computation eventually returns.

And we have the following examples:     

* an identity subsitution never occurs in a reservation action.
* every accepted request eventually reaches a final outcome.
* the agent loop returns after a bounded number of model decisions, assuming each external
  operation returns or times out.

Let's make these mathematically precise. 

Suppose:

* :math:`S` is the state space
* :math:`A` is the set of modeled events or actions
* :math:`\pi:\mathbb{N}\to S` is an execution
* :math:`\alpha:\mathbb{N}\to A` is the corresponding event sequence and 
* :math:`\operatorname{Next}(\pi(k),\alpha(k),\pi(k+1))` holds at every step

Write :math:`\operatorname{ValidExecution}(\pi,\alpha)` for the predicate that means the initial-state and transition requirements are
satisfied. We can define a bad event as follows:

.. math::

   \operatorname{IdentitySubstitution}(s,a)
   \;\stackrel{\mathrm{def}}{:=}\;
   \operatorname{ReservationDispatch}(a)
   \land
   a.\mathit{owner}
   \neq
   s.\mathit{authenticatedUser}.

This predicate holds when :math:`a` dispatches a reservation whose requested owner differs from the
authenticated user recorded in state :math:`s`.

The safety property can then be defined as follows:

.. math::

   \forall \pi,\alpha,k,\quad
   \operatorname{ValidExecution}(\pi,\alpha)
   \Longrightarrow
   \neg\operatorname{IdentitySubstitution}(\pi(k),\alpha(k)).

We are using one symbol we haven't introduces -- the "not" symbol (:math:`\neg`). This simply means that the 
proposition is *not* true. 

Preconditions, postconditions, and invariants describe where a property applies. Safety, liveness,
and termination describe the kind of behavior being constrained. These classifications overlap rather
than compete. An invariant commonly expresses a safety property.

In-class Exercise
^^^^^^^^^^^^^^^^^

Classify each statement and identify any missing qualification:

1. A failed reservation is never reported as completed.
2. Every accepted request eventually produces either a completed, blocked, or failed response.
3. If a reservation tool reports success, the returned reservation identifier appears in the trace.
4. The agent performs at most ten model-decision steps.

*Discussion*:

* Statement 1 is a safety property and could be expressed as a trace/response invariant.
* Statement 2 is a liveness property and requires assumptions about model and tool responses.
* Statement 3 resembles a postcondition for processing a successful observation.
* Statement 4 is a bounded-execution property, but it does not establish a wall-clock bound unless
  individual operations also return or time out.




.. Technique Summary 
.. ^^^^^^^^^^^^^^^^^

.. We can summarize various techniques as follows: 

.. * Type systems and type checking -- Reject programs or values that violate typing rules 
.. * Contracts and runtime checking -- Check preconditions, postconditions, or invariants during execution
.. * 









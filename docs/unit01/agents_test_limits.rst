From Tests to Guarantees: Safety, Liveness, and Formal Specifications
=====================================================================

In the proceeding lecture, we developed an agent that produces typed decisions, calls tools, records
observations, maintains a trace of events, and leverages validation across the application 
including in front of any state changing mutations. Those approaches improve the 
overall system robustness and reliability, but they raise an important question: *What exactly 
have we been able to ensure about the system?* 

Executing a benchmark establishes how the system performs on a specific set of inputs 
under controlled conditions. Similarly, a test suite establishes that the
implementation behaved as expected on specific cases. But neither of these approaches provides 
a guarantee about every possible execution.

In this module, we use the Laboratory Agent to distinguish observed facts, runtime enforcement,
example-based evidence, and universal claims. These distinctions motivate the transition from ordinary
software testing to formal specification and machine-checked reasoning. These ideas will motivate our 
introduction of formal methods and the Lean programming language which we will develop over the 
next several weeks. 

Note that the issue is not about any limitation in the power of the Python programming language. 
Indeed, Python is a general purpose and Turing-complete programming language, and nothing prevents 
us from implementing formal tools in Python. The issue is what ordinary
application code and finite testing can establish directly and with relative ease, compared with 
what requires explicit formal specifications and reasoning over all possible cases.

By the end of this module, students should be able to:

* distinguish a fact about one execution from a claim about every possible execution
* identify safety, liveness, termination, and invariant properties
* explain what Atlas's schemas, trace validators, and tests establish
* identify the assumptions and obligations of a runtime check
* explain why additional tests increase confidence without automatically proving a universal claim
* describe formal verification as reasoning over a model, specification, and stated assumptions
* translate an informal agent requirement into an initial formal specification

An Initial Example 
------------------

Consider the following scenario from our lab agent software. 

Alice asks to reserve the tensile tester for
``polymer-study`` from 10:00 to 11:00. The trace records four successful tool calls:

.. code-block:: text

    1. search_lab_documents
    2. get_user_authorizations(user_id="alice")
    3. get_resource_status(
           resource_id="tensile-01",
           start="2026-10-15T10:00:00",
           end="2026-10-15T11:00:00",
       )
    4. reserve_resource(
           user_id="alice",
           project_id="polymer-study",
           resource_id="tensile-01",
           start="2026-10-15T10:00:00",
           end="2026-10-15T11:00:00",
       )

The final trace event contains:

.. code-block:: json

    {
      "step": 4,
      "decision": {
        "kind": "tool_call",
        "tool": "reserve_resource",
        "arguments": {
          "user_id": "alice",
          "project_id": "polymer-study",
          "resource_id": "tensile-01",
          "start": "2026-10-15T10:00:00",
          "end": "2026-10-15T11:00:00"
        },
        "reasoning_summary": "All required preconditions are satisfied."
      },
      "observation": {
        "ok": true,
        "tool": "reserve_resource",
        "data": {
          "status": "confirmed"
        },
        "error_code": null,
        "message": null
      },
      "mutating": true
    }

Now consider the following statements:

1. In this run, ``reserve_resource`` returned a successful observation.
2. All six public benchmark scenarios returned their expected statuses.
3. The agent can never execute a reservation for anyone other than the authenticated user.

Which of these statements is supported by the trace? 

Are all of these statements true? Possibly, but the evidence required to justify them is not the same.

*Discussion:* Which statement do you think is the easiest to establish? Which one do you think will be 
hardest? 

The first statement is quite easy and is established directly by the trace above. The second statement requires 
executing the public bench and verifying the output statues. So, arguably more involved, but still quite doable 
with normal programming. 

The final statement, however, is differnt, and, arguably, qualitatively more difficult because it requires 
establishing a fact *for every possible authenticated user*. This is known as a universal quantifier. 

Different Sources and Types of Evidence 
---------------------------------------

When we are establishing truths about a software system, there are different sources and types of evidence that 
we must deal with, and each has different qualities. 

Trace Facts
^^^^^^^^^^^

A trace fact describes a recorded event in one execution:

.. code-block:: python

    successful_reservations = [
        event
        for event in run.trace
        if event.observation.tool == "reserve_resource"
        and event.observation.ok
    ]

    assert len(successful_reservations) == 1

The ``assert`` check can establish that from within *the current program execution*, the ``successful_reservations`` list 
contains one successful reservation event. But, importantly, it is only is able to establish facts about the current run. 
It says nothing directly about any another run.

Trace facts are very important because they support auditing, debugging, final-response validation, and incident
analysis, but they are limited in the scope of what they can be used to establish.

Runtime-Enforced Conditions
^^^^^^^^^^^^^^^^^^^^^^^^^^^

A runtime validator checks a predicate when the program executes. Consider the following example: 

.. code-block:: python

    if (
        "user_id" in decision.arguments
        and decision.arguments["user_id"] != request.authenticated_user_id
    ):
        errors.append("user_id_must_match_authenticated_user")


For the inputs of the current run, this code deterministically checks whether there is a mismatch between the `
`user_id`` used in the decision arguments and the one provided in the authenticated request. If in subsequent code, 
the action validation refuses to execute the scheduler tool whenever ``errors`` is nonempty, the current unsafe 
proposal will not reach the tool through that path.

This is, of course, stronger than a prompt instruction that tells the model to maintain the authenticated user throughout all 
tool calls. A model can simply ignore our instructions and swap ``alice`` for ``joe`` at any point. 

Nevertheless, the check above only establishes the predicate it implements at the points in the program where it 
is actually invoked. 


Tested Properties
^^^^^^^^^^^^^^^^^

A test runs the implementation against a selected set of inputs, for example:

.. code-block:: python

    def test_rejects_identity_substitution():
        errors = validate_request_binding(
            substituted_decision,
            request=alice_request,
        )

        assert "user_id_must_match_authenticated_user" in errors

The test above demonstrates that our software rejects a particular example involving ``substituted_decision`` and 
``alice_request``. Of course, we can write more tests to establish more cases, and we may also expose bugs or other 
defects in our code. But, a finite collection of successful tests still only describes the executions that were actually 
tested. It does not establish a universal claim about *all* inputs. 


Universal Claims
^^^^^^^^^^^^^^^^

A universal claim (or sometimes, a universal property)) is a statement that is true for all inputs or executions:

.. code-block:: text

    For every trusted request r and proposed reservation d:

        if d.user_id != r.authenticated_user_id,
        then d is not dispatched to reserve_resource.

The words “for every” are doing a substantial amount of work. We cannot evaluate this claim by selecting one value
of ``r`` and one value of ``d``. We need to establish that the statement is true foe all possible vsalues of ``r`` and 
``d``.

Counterexamples and Proof Obligations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A single counterexample is sufficient to disprove a universal claim. For example, suppose 
we had the following pseudo trace: 

.. code-block:: text

    request.authenticated_user_id = "alice"
    proposed user_id = "joe"
    reserve_resource was dispatched

This one example is enough to establish that the universal claim above is *false*. 

But, collecting individual examples cannot establish the universal claim in the same way. This asymmetry explains why
testing is often highly effective at finding bugs while remaining incomplete as a proof technique.

Safety, Liveness, Termination, and Invariants
---------------------------------------------

Formal methods begin with a precise statement of the property to be established. In the context of software engineering, 
we are usually interested in establishing specific types of properties of our system. Different kinds of
properties require different forms of reasoning.

Safety Properties
^^^^^^^^^^^^^^^^^

A **safety property** says that something undesirable never happens.

In the context of the software systems we have been looking at, examples of safety properties include:

* a final response never cites a passage absent from the retrieval trace
* a tool call that fails is never recorded as successful in the trace
* a reservation is never made with a substituted user identity

A safety violation generally has what is referred to as a *finite witness* , that is, a finite execution trace of the 
entire program or system that generates or exhibits a violation. In the last example above, if we can find even a single input 
where the system substitutes the authenticated identity for another user's identity in a reservation, the system trace of 
the execution up to that event is enough to demonstrate the failure in the safety property.

Liveness Properties
^^^^^^^^^^^^^^^^^^^

A **liveness property** says that something desirable eventually happens.

Some examples include the following:

* every agent execution eventually returns some result
* every dispatched tool call eventually receives an observation
* after a recoverable failure, the agent eventually retries, asks for clarification, or returns an
  explicit final response

Unlike a safety violation, a liveness failure may not be evident from a finite witness. A tool that
has not returned yet might return one second later or might remain blocked forever.

Some liveness claims may look attractive but are ultimately not true, for example: 

    “Every valid reservation request eventually succeeds.”

Any number of things could happen in between the time the request is made, the time it is considered valid, 
and the time at which the system successfully saves the reservation. For example, the entire program could 
crash because it ran out of memory or because someone unplugged the computer. 

Conditional Termination
^^^^^^^^^^^^^^^^^^^^^^^
Termination, either of a specific function, a program loop, or an entire program, can be an example of a liveness 
property. It is sometimes (though not always) the case that we want to know that a particular piece of software 
eventually terminates. However, in many cases proving termination can be difficult. 

Recall that the agent lab software we discussed used a bounded loop:

.. code-block:: python

    def run_with_step_budget(max_steps):
        trace = []

        for step in range(1, max_steps + 1):
            decision = obtain_and_handle_one_decision(step)
            if decision.is_terminal:
                return decision.result

        return _failed(
            f"The agent exceeded its step budget of {max_steps}.",
            trace,
            "maximum_steps_exceeded",
        )


This supports the conditional property:

    If each call to the model and each tool invocation returns, ``run_agent`` requests at most
    ``max_steps`` model decisions before returning.

The *condition* specified with the *if* is essential to the correctness of the statement. A loop with ten iterations 
can still wait forever during its first HTTP request. A step budget limits the number of iterations while a timeout limits 
the duration of an individual operation.


Program States and Invariants
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

One way to model a program is as a set of states. We begin with the execution of the program at time :math:`t = 0`, 
and the program has some initial state corresponding to the initial values of its variables. Then, the program executes 
its first instruction, and the values of the variables are updated. Moreover, new variables could be created, and some 
existing variables could be destroyed. The set of all variables and their values after the first instruction is executed 
is the program's state at :math:`t=1`. Proceeding in this way, we get a set of states for each value of :math:`t = 0, 1, 2, 3, ...`
for forever or until the program terminates. (Turing-complete languages have the ability to create programs that never 
terminate, so, in such languages, it is possible for the program's states to continue forever.)

Note that the program's behavior can (and usually will) depend on some input. For example, the input, ``t``, determines 
how many iterations of the loop are executed, and thus, how many states the program moves through. 

.. code-block:: python3 

    t = int(input())
    x = 10 
    for i in range(t):
        x = x + i 
    print(x)

Thus, we can define a *state* (or sometimes called an *abstract state* for emphasis) to be *any* assignment of values 
to the variables of the program and then we define the *total state space* of the program to be the set of all such 
states. It is important to note that a state may not ever be realized by the program for 
any specific input. We say that a state is *reachable* if, after some finite number of steps, the program reaches the 
state for some input. 

An **invariant**, then, is a property of a program that holds in every reachable state. For example, in our la 
agent software setting, the following would be a desirable invariant: 

    Every successful ``reserve_resource`` event in the trace uses the authenticated user and the
    resolved project, resource, and interval from the trusted request.

An invariant is not a predicate that is just checked at a single point in time, like once at the beginning. 
In invariant must remain true after every allowed state transition.

Preconditions and Postconditions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A **precondition** states what must hold before an operation. A **postcondition** states what must hold
after it completes.

For a reservation operation, we have the following pre and postconditions:

.. code-block:: text

    Preconditions:
      - proposed user matches authenticated user
      - project is authorized
      - qualification is present
      - resource is available and ready

    Postcondition after success:
      - the simulator contains a confirmed reservation
      - the successful observation identifies that reservation

There is a natural interaction between preconditions, postconditions, and invariants. For instance, the action validator 
checks selected preconditions, the tool and simulator determine whether the postcondition is produced and an invariant relates these
operations across the entire execution.


In-Class Exercise
^^^^^^^^^^^^^^^^^

Classify each statement as either a: safety property, liveness or termination property, 

1. A denied reservation proposal never modifies simulator state.
2. Every run eventually returns.
3. Every successful mutation has a corresponding successful trace observation.
4. A live-model call completes within 60 seconds.

Statements 1 and 3 are safety properties. Statements 2 and 4 concern liveness or termination. The
fourth requires an implemented timeout and assumptions about what cancellation means for the remote
operation.

What Ordinary Python Enforcement Establishes
---------------------------------------------

Runtime checks are essential enforcement mechanisms that must be implemented in any robust software. But it is 
important to understand the limitations of what they can establish. 

Structural Validation
^^^^^^^^^^^^^^^^^^^^^

Pydantic can establish that a received decision satisfies the declared runtime schema:

.. code-block:: python

    decision = DecisionAdapter.validate_python(raw_decision)

After successful validation, the application knows that ``decision`` matches one permitted decision
variant and satisfies its field constraints.

It does not know that:

* the selected tool is appropriate for the user's goal
* the argument values are authorized
* the cited facts are true
* executing the proposed action is safe

Structure is a real property, but it is only one of a number of properties we would like to establish. 


Request Binding
^^^^^^^^^^^^^^^

The request-binding validator compares a proposed action with the current task state:

.. code-block:: python

    def validate_request_binding(decision, *, request):
        args = decision.arguments
        errors = []

        if (
            "user_id" in args
            and args["user_id"] != request.authenticated_user_id
        ):
            errors.append("user_id_must_match_authenticated_user")

        return errors

For a given ``decision`` and ``request`` object, the code deterministically checks whether the ``user_id`` 
in the decision's arguments is the same as the authenticated user. 








Structured Decisions, Tools, and Agents
=======================================

In the previous modules, we looked at RAG systems, including their basic architecture, various 
algorithms for implementing their primary components, and how to evaluate them. 
We saw that it is important to evaluate an AI system at several stages, not just 
the final answer. 

In this module, we extend the notion of a retriever to that of a *tool*, and we introduce the 
*agentic* architecture. A tool-using system needs strong intermediate contracts specified with types. 
At each step, the model should produce a structured proposal that ordinary application code can 
validate, record, and either execute or reject.

In addition to introducing the high-level concepts, we will present the architecture and a number of implementation details 
of a lab management software system that leverages tool calling via an agentic architecture. You will be 
working with this code base in your midterm project. 

By the end of this module, students should be able to:

* explain why free-form model output is a weak control interface
* define Pydantic models and an annotated union for model decisions
* distinguish a tool-call proposal from tool execution
* explain the separate roles of decision validation, tool validation, and action validation
* interpret successful and failed ``ToolObservation`` objects
* distinguish trusted request fields from untrusted model-produced values


Background: Lab Equipment Management Software 
---------------------------------------------

We first introduce the laboratory equipment management software that will be used throughout the lecture and in the 
midterm project. The software, referred to as "Atlas Lab",  
allows members of the lab to type requests in natural language, and the software attempts to interpret the 
request, assess it for compliance with the lab's policies and procedures, and then act accordingly. 

For example, the application might receive a requests such as:

 *Reserve the tensile tester for my project tomorrow afternoon.*

Before taking an action, the application may need to retrieve laboratory policy, 
inspect user qualifications, check project authorization, check resource status, or 
ask the user for missing information. An LLM will be used to process the natural language request, 
but the application augments this with tools and validation that allow the requests to be 
fulfilled when possible. 

Tools: An Initial Look 
-----------------------

We saw with RAG that an application can provide additional information from an external source 
to the LLM at generation time. *Tools* or *tool calling* extends this notion to more arbitrary 
external function calls. However, while with RAG, the application code deterministically calls the 
retriever prior to calling the LLM, with *tool calling*, the LLM usually requests the invocation 
of a specific tool with certain parameter values. 

For example, a first tool might provide the current date and time while a second tool might provide 
basic arithmetic calculations like a basic calculator. The application provides descriptions of these 
available tools to the LLM, including any required and optional parameters, in addition the user input. 
The prompt might conceptually be provided to the LLM as a JSON object similar to the following: 

.. code-block::  json 

    { 
      "question": "What is the date today?", 
      "tools": [ 
        { 
          "id": "calculator", 
          "description": "Perform basic arithmetic calculation", 
          "required_parameters": [
            { "expression": "string" }
          ],
          "optional_parameters": null, 
        },
        {
          "id": "date-time", 
          "description": "Get the current data and time", 
          "required_parameters": null, 
          "optional_parameters": null
        }
      ]
    }
      
The LLM may parse the input, in this case *"What is the date today?"*, and decide that a tool should be 
invoked before a final answer can be returned to the user. In this case, which tool should the LLM 
request be invoked? 

The Agent Loop 
--------------

How do we leverage tools in a modular, scalable, and extensible way, and one that leverages 
the full power of foundation AI models? The idea is to structure the application as a bounded 
loop that repeats at most a finite number of times. Various architectures have been and continue 
to be explored, but a good initial baseline is that which is referred to as the ReAct architecture, 
for "Reason+Action". The complete loop can be depicted as five steps: 

1. Provide the model with input and ask it for a single typed decision
2. If the decision is a clarification or a final response, handle that. Otherwise, if the 
   decision is a tool call, validate the call. 
3. Execute a valid tool call or generate a tool execution denial 
4. Record the decision and/or observation 
5. returns the observation to the model as part of the next iteration. 

We will provide details into all of the steps above in the coming sections. 
Crucial to this approach will be the use of strong types, as we will see. 

Typed Decisions 
---------------

Returning to our laboratory management software, suppose the application receives a reservation 
request from Alice like: 

  *I would like to reserve the tensile tester tomorrow*

and the model responds with:

    *I should check Alice's qualifications and then reserve the tensile tester if everything looks
    acceptable.*

As free-form text, this response is difficult for the application to act upon. The application must 
discern if:

* the model is requesting to invoke a tool, and if so, which tool and what arguments to provide to it. 
* the model is requesting a single action or multiple actions 
* the model has determined it doesn't have enough information to proceed and needs to follow up with the user.

Trying to parse the LLM's reply --- for example, based on key words --- will be very fragile and will, 
to a large extent, undermine the value the LLM was providing to the application. 

Typed Responses 
^^^^^^^^^^^^^^^

Instead, the application should require the model to choose one specific option and describe that 
decision in a structured object, like: 

.. code-block:: json

    {
      "kind": "tool_call",
      "tool": "get_user_authorizations",
      "arguments": {
        "user_id": "alice"
      },
      "reasoning_summary": "Check the authenticated user's permissions."
    }

The application no longer needs to infer the response's basic shape. It can check that:

* ``kind`` specifies an allowed decision option 
* ``tool`` specifies an allowed tool
* required arguments to the tool call are provided 
* no unexpected decision arguments have values specified

Note that specifying types for the output does **not** establish that the proposed action is safe or correct. 
The LLM could easily generate a proposed action that is inappropriate or incorrect.
For example, it could specify the wrong user to check authorization for, 
it could an unavailable resource, or incomplete tool arguments. However, it does create a reliable 
interface upon which stronger checks can run.


Validating Proposals Prior to Execution 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Our approach can be summarized as follows:

1) AI model proposes execution plan 
2) Application validates plan 
3) If valid, application executes plan and obtains the result of the call

For example, at step 1, the model could produce ``ToolCallDecision(tool="reserve_resource", ...)``. At this 
point, no reservation has been attempted.

At step 2, the application validates that tool call; for example, it could check for a configured policy violation. 

In step 3), if the application approves the tool call, then it executes it. 
This could result in the tool returning ``ToolObservation(ok=True, ...)``. 
At this point, a response could be returned to the user or another execution plan could be generated. 


Validation Layers 
^^^^^^^^^^^^^^^^^

The application will implement validation in the following 4 layers in the order listed: 

1. **Serialization:** This checks that the output syntactically valid JSON.
2. **Decision validation:** This checks that the decision field matches exactly one allowed decision option?
3. **Tool and policy validation:** Are the tool arguments valid, and are they permitted by
   the policy?
4. **Execution validation:** Did the tool actually return a successful observation?

Once a validation check fails at one layer, the application should take the appropriate remediation. There is 
typically no need to do the later validation checks, and in some cases, the checks may be impossible to perform. 
For example, if the output is not valid JSON then it will be impossible to check the decision field. 

Decision Types 
--------------

The agent in this system is allowed to make exactly three different types of decisions: 

1. ``ToolCallDecision`` -- used to make an external function call, either to retrieve information, update state, 
   or a combination of both. In this case, the application will validate the requested tool call before executing 
   it. 

2. ``ClarificationDecision`` -- used to request additional information from the user, indicating
   that further progress cannot be made without user input. 
   In this case, the application will make a clarification request to the user without calling a tool. 

3. ``FinalDecision`` -- used when the model proposes that the loop should end with a user-facing response.
   Different from a ``ClarificationDecision``, here the model is proposing a terminal response indicating that 
   no additional tool execution or user input is required for the current request.

Each of these will be implemented as a typed decision using Pydantic. We describe this below. 

JSON Schema and Pydantic 
---------------------------

As we have seen before, JSON Schema is a machine-readable description of the allowable JSON objects. 
One can use JSON Schema to define the following:

* required and optional fields 
* the types associated with each field 
* a list of all allowable values for certain types of fields (Literals or Enums)
* constraints on allowable ranges for numeric fields
* complex and/or nested objects such as dictionaries and lists 
* whether additional, unspecified fields can be included 

Using Pydantic, we can create Python types that can be used to validate data in a Python application, 
but we can also generate a JSON Schema for use in other applications. 

Our goal is to define Pydantic types for the three decision types mentioned above, and to be able to 
generate JSON schema for them. We'll build up that over the next couple of sub-sections. 

We'll begin by defining a base ``DecisionModel`` type that all decision types will inherit from. 


A Base ``DecisionModel``: Forbidding Extra Fields 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For our base ``DecisionModel`` type, the main feature we want is that all decision types 
forbid including additional, unspecified fields. 
This can done with the ``extra="forbid"`` parameter to the ``ConfigDict`` constructor. For example: 

.. code-block:: python

    from __future__ import annotations

    from typing import Annotated, Any, Literal

    from pydantic import BaseModel, ConfigDict, Field, TypeAdapter

    class DecisionModel(BaseModel):
        model_config = ConfigDict(extra="forbid")
        # ... actual fields defined in child classes of the Decision model...

This allows the application to prevent unintended use --- if a decision object adds a field like 
``execute_immediately=True``, the decision object will fail validation immediately. 


Use of Literal for the Tool Name 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The application will leverage a ``Literal`` that specifies the only allowable tool names that can be 
selected:

.. code-block:: python

    ToolName = Literal[
        "search_lab_documents",
        "get_user_authorizations",
        "get_resource_status",
        "reserve_resource",
    ]

This approach makes it very easy to determine: 1) if the model is requesting a valid tool, and 2) what 
arguments or parameters are required and/or optional for the tool. 

Sum Types or Discriminated Unions 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Ultimately, our agent will choose between one of three decision types to include in its response. 
How will we represent that as a type? 

A common pattern in type systems is that of a *sum type*, also called a *discriminated union* (or a *tagged union*). 
The idea is to allow one of a fixed set of possible types and to use a designated field (or *discriminator*) to 
specify which type is being used. 

In our example, the agent is choosing between: 1) calling a tool; 2) asking the user for clarification; or 3) making 
a final response. Thus, the idea is to implement each as its own type, and then the agent's decision will be 
implemented as a discriminated union type over all three of these types. 

In Python, we can implement this using a Pydantic data model for each option, where each model includes a 
``kind`` field which acts as the discriminator. For example: 

.. code-block:: python

    class ToolCallDecision(DecisionModel):
        kind: Literal["tool_call"]
        tool: ToolName
        arguments: dict[str, Any]
        reasoning_summary: str


    class ClarificationDecision(DecisionModel):
        kind: Literal["clarification"]
        question: str
        missing_fields: list[str]


    class FinalDecision(DecisionModel):
        kind: Literal["final"]
        response: TerminalResponse

All three define the ``kind`` field as a Literal with exactly one value. Moreover, the first two models define 
their other fields in-line, while the ``FinalDecision`` includes a ``response`` field which is its own model. 
It is defined like this: 

.. code-block:: python3 

    class AgentResponse(BaseModel):
        status: Literal[
            "completed",
            "blocked",
            "clarification_required",
            "failed",
        ]
        message: str
        citations: list[str] = Field(default_factory=list)
        completed_actions: list[str] = Field(default_factory=list)

    class TerminalResponse(AgentResponse):
        status: Literal[
            "completed",
            "blocked",
            "failed",
        ]

In any case, we can now define an ``AgentDecision`` as a discriminated union as follows: 

.. code-block:: python3 

    AgentDecision = Annotated[
        ToolCallDecision | ClarificationDecision | FinalDecision,
        Field(discriminator="kind"),
    ]

Note the use of the ``Annotated`` type from the ``typing`` module. This is a modern trick used by various 
third-party Python libraries like Pydantic to allow developers to attach additional metadata to a type. 
In general, the syntax is ``Annotated[base_type, metadata_1, metadata_2, ...]`` where ``base_type`` is the 
actual type that the linters (e.g., MyPy) use for validation, and the ``metadata_1``, ``metadata_2``, etc. are 
a list of additional metadata of arbitrary length. 

Here, we are specifying a single additional metadata, a Pydantic ``Field`` object where we specify the 
discriminator field (in this case, the ``kind`` field). That tells Pydantic to treat the union (specified 
using the ``Type 1 | Type 2 | ...`` notation) as a discriminated union using ``field`` as the discriminator. 

Thus, for example, when ``kind`` is ``"clarification"``, Pydantic validates against ``ClarificationDecision``.

Validating the Model's Output 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Note that while the ``DecisionModel`` and its child models ``ToolCallDecision``, etc. were ``BaseModel``
classes, defining ``AgentDecision`` as a union (i.e., ``ToolCallDecision | ClarificationDecision | FinalDecision``)
means that it is not a ``BaseModel``, and it therefore does not inherit a ``model_validate()`` method, etc. 

To handle this situation, Pydantic provides ``TypeAdapter`` to give ordinary Python type expressions a 
similar API to that of a Pydantic ``BaseModel``. 
To this end, the application defines ``DecisionAdapter`` as a ``TypeAdapter`` of an ``AgentDecision``:

.. code-block:: python3 

    DecisionAdapter = TypeAdapter(AgentDecision)

Thus, a ``DecisionAdapter`` object indeed has validation methods similar to those of a ``BaseModel``. 
Consider the following code: 


.. code-block:: python

    decision = DecisionAdapter.validate_python(
        {
            "kind": "clarification",
            "question": "What exact start and end times should I use?",
            "missing_fields": ["start", "end"],
        }
    )

Here, we are leveraging Pydantic's validation functionality to validate a plain Python dictionary 
against the discriminated union type defined by the ``DecisionAdapter`` (note the user of a slightly different 
method name, ``validate_python``). 

Do you think the code above will validate? And if so, what is the resulting type of the ``decision`` object? 

Try also the following code. What do you expect? 


.. code-block:: python

    objects = [
        {
            "kind": "tool_call",
            "tool": "delete_all_reservations",
            "arguments": {},
            "reasoning_summary": "Remove everything.",
        },
        {
            "kind": "clarification",
            "missing_fields": ["start", "end"],
        }
    ]

    DecisionAdapter.validate_python(objects[0])

    DecisionAdapter.validate_python(objects[1])

Generating JSON Schema
^^^^^^^^^^^^^^^^^^^^^^

Pydantic can produce the JSON schema associated with the ``DecisionAdapter``. This can be 
sent to the model: 

.. code-block:: python

    decision_schema = DecisionAdapter.json_schema()

    print(decision_schema["discriminator"]["propertyName"])
    print(len(decision_schema["oneOf"]))

As we described previously in the Foundation Models unit, many modern models and inference servers can use 
such a schema to constrain the responses that are generated, but errors can still happen. Thus, it is 
crucial that the application validates the response itself.


Tool Argument and ToolObservation Types
---------------------------------------

Each tool has a different set of arguments, including required and optional arguments. 
To formalize their associated contracts, we define data types for each tool. 

.. code-block :: python3

    class SearchArguments(BaseModel):
        query: str
        document_types: list[str] | None = None
        top_k: int = Field(default=5, ge=1, le=10)


    class AuthorizationArguments(BaseModel):
        user_id: str


    class ResourceStatusArguments(BaseModel):
        resource_id: str
        start: str
        end: str


    class ReservationArguments(ResourceStatusArguments):
        user_id: str
        project_id: str

In the code above, we have defined four Pydantic models, one for each of the four tools available in the 
lab management software. We can define a simple lookup dictionary to map the tool names to the argument 
models:

.. code-block:: python

    TOOL_ARGUMENT_MODELS: dict[str, type[BaseModel]] = {
        "search_lab_documents": SearchArguments,
        "get_user_authorizations": AuthorizationArguments,
        "get_resource_status": ResourceStatusArguments,
        "reserve_resource": ReservationArguments,
    }

Then, when the AI model returns a ``ToolCallDecision``, we simply use the corresponding model's ``model_validate`` 
method after looking up the model class from the ``TOOL_ARGUMENT_MODELS`` lookup to validate the arguments. 
The code for validating the proposed arguments is straight-forward:

.. code-block:: python

    def validate_tool_arguments(
        decision: ToolCallDecision,
    ) -> BaseModel:
        argument_model = TOOL_ARGUMENT_MODELS[decision.tool]
        return argument_model.model_validate(decision.arguments)

So, for example, if the AI model returns a ``ToolCallDecision`` like this: 

.. code-block:: python 

    decision =  ToolCallDecision(
            kind="tool_call",
            tool="search_lab_documents",
            arguments={
                "query": "tensile tester training requirements",
                "top_k": 3,
            },
            reasoning_summary="Retrieve the applicable training policy.",
        )

we validate it with: 

.. code-block:: python 

    validate_tool_arguments(decision)

Do you expect that tool call to validate? What about the following? 

.. code-block:: python 

    decision_2 =  ToolCallDecision(
            kind="tool_call",
            tool="get_resource_status",
            arguments={
                "resource_id": "tensile_tester"
            },
            reasoning_summary="Retrieve the applicable training policy.",
        )

    decision_3 =  ToolCallDecision(
            kind="tool_call",
            tool="search_lab_documents",
            arguments={
                "query": "tensile tester training requirements",
                "top_k": 25,
            },
            reasoning_summary="Retrieve the applicable training policy.",
        )

``ToolObservation``
^^^^^^^^^^^^^^^^^^^

The ``ToolObservation`` data type specifies a common response type for each tool call:

.. code-block:: python

    class ToolObservation(BaseModel):
        ok: bool
        tool: str
        data: dict[str, Any] = Field(default_factory=dict)
        error_code: str | None = None
        message: str | None = None

Here, the ``data`` field is an arbitrary dictionary. A successful observation look like: 

.. code-block:: python

    success = ToolObservation(
        ok=True,
        tool="get_user_authorizations",
        data={
            "qualifications": ["lab_safety", "laser_safety"],
            "projects": ["polymer-study"],
            "approvals": [],
        },
    )

while a failure might look like: 

.. code-block:: python

    failure = ToolObservation(
        ok=False,
        tool="get_resource_status",
        error_code="invalid_arguments",
        message="The required end field was not supplied.",
    )

Why is the first observation allowed to omit the ``error_code`` field while the second one includes 
it but omits the ``data`` field? 

Instead of having a single type to represent all tool call responses, one could have custom types 
for each tool, similar to the tool arguments approach. As usual, there are tradeoffs to both approaches. 
Can you think of some of them? 

From Observations to Trace Events 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
A ``ToolObservation`` records the result of a single attempted tool call. In general, the agentic application 
needs to preserve the complete list of tool calls and their responses across the iterations of the loop. 

The concept of traces, or *trace events*, is used to record this entire history. In the lab equipment management
software, a ``TraceEvent`` model is used: 

.. code-block:: python 

    class TraceEvent(BaseModel):
        step: int
        decision: dict[str, Any]
        observation: ToolObservation
        mutating: bool = False


A trace event brings together the following information:

- the model's proposed decision
- the resulting observation
- the position of the event in the run
- whether the proposed tool can mutate external state.

And, the agent's trace is maintained as a chronological list:

.. code-block:: python 

    trace: list[TraceEvent] = []

After every tool attempt, the loop appends another event:

.. code-block:: python 

    event = TraceEvent(
        step=step,
        decision=decision.model_dump(),
        observation=observation,
        mutating=decision.tool in MUTATING_TOOLS,
    )

    trace.append(event)

The list of traces, therefore, provides evidence about what the agent requested and what actually happened. 
Later decisions and validators can inspect the traces rather than relying on the model's description of earlier events.

For example, 

.. code-block:: python 

    TraceEvent(
        step=2,
        decision={
            "kind": "tool_call",
            "tool": "get_user_authorizations",
            "arguments": {"user_id": "alice"},
            "reasoning_summary": "Check the user's authorization.",
        },
        observation=ToolObservation(
            ok=True,
            tool="get_user_authorizations",
            data={
                "qualifications": ["lab_safety"],
                "projects": ["polymer-study"],
            },
        ),
        mutating=False,
    )    

This trace establishes some import facts, namely: 1) the application attempted to check user "alice"'s
authorizations, and it determined that she has authorization for the "polymer-study" project. 

Read-only tools and Mutating Tools 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

An important distinction is whether a tool is read-only or a tool *mutates* state, i.e., makes changes 
to the application state. Searching the existing lab 
documents is a read-only procedure while reserving a resource actually makes updates to the status 
of the resource. Sometimes, tools that update state are considered more security sensitive than read-only tools 
However, a tool that reads protected or otherwise highly-sensitive data presents significant security 
concerns. 

The lab equipment manager application code records the classification as a global constant:

.. code-block:: python

    MUTATING_TOOLS = {"reserve_resource"}


Request Object and Action Validation 
-------------------------------------

In addition to the user's input, every request to the lab management software includes a 
``LabRequest`` object constructed by authenticated application code:

.. code-block:: python

    class LabRequest(BaseModel):
        authenticated_user_id: str
        text: str
        project_id: str | None = None
        resource_id: str | None = None
        start: str | None = None
        end: str | None = None

For example, an actual request might look like: 

.. code-block:: python

    request = LabRequest(
        authenticated_user_id="alice",
        text=(
            "Reserve the tensile tester for my polymer project "
            "from 10:00 to 11:00."
        ),
        project_id="polymer-study",
        resource_id="tensile-01",
        start="2026-10-15T10:00:00",
        end="2026-10-15T11:00:00",
    )

The ``authenticated_user_id`` and other derived fields come from trusted application code. 
The natural-language text remains user-controlled input. The derived fields should not 
be modified by the AI model. For example, if the ``authenticated_user_id`` is ``alice``, the 
AI model should not change it to ``joe``. 

Identity Substitution Example
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For example, suppose the application receives the request from Alice above, and in response 
the model proposes the following:

.. code-block:: python

    substituted_decision = ToolCallDecision(
        kind="tool_call",
        tool="reserve_resource",
        arguments={
            "user_id": "joe",
            "project_id": "polymer-study",
            "resource_id": "tensile-01",
            "start": "2026-10-15T10:00:00",
            "end": "2026-10-15T11:00:00",
        },
        reasoning_summary="Create the requested reservation.",
    )

The object is structurally valid, and its tool arguments may also pass the corresponding Pydantic model, but
it still must be denied because the model has changes the authenticated user from Alice to Joe.


Action Validation 
^^^^^^^^^^^^^^^^^

Action validation, also sometimes referred to as an *action gate*, is just normal application code that 
runs after schema validation but before execution of the proposed action. For every proposed tool call, 
it checks arguments in the tool call against the derived fields in the ``LabRequest`` object. 
For the ``reserve_resource`` tool call, it also checks facts derived from the preceding trace of tool observations, 
including: 

* at least one policy search was successfully completed
* at least one authorization call for the proposed ``user_id`` was checked
* resource status was checked for the requested interval
* whether the proposed project appears in the authorization data, as a proxy for checking if it is authorized
* the required qualification is current, based on mapping the resource kind to its required qualification check 
* the resource is available, based on the ``available`` field from a matching resource-status trace
* calibration is current, based on the ``calibration_current`` field from that observation
* maintenance is clear, i.e., that ``matinenance`` is ``False`` 
* after-hours approval is satisfied when required. This is based on the interval and whether it is after hours. 

As you can see, the observation traces are key to being able to implement these action gate checks. 

Note also that some of these checks are more shallow then would be ideal. For example, the policy search 
check simply verifies that at least one successful call to ``search_lab_documents`` was made. The implementation 
is: 

.. code-block:: python 

    policy_retrieved = any(
        event.observation.tool == "search_lab_documents"
        and event.observation.ok
        for event in trace
    )    

In particular, that is not checking that the search even returned any chunks or that the retrieved chunks were 
relevant to the query, etc. Implementing complete policy checking is a significant engineering challenge, but it 
does not alter the overall design. 

Permission and Denial for Tool Call Proposals
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Recall that once the AI model proposes a typed tool call decision, there are two possible outcomes from our 
applicant's validation --- either the tool call is permitted and we execute the call or the tool call is denied: 

.. math::

    \text{typed proposal from AI model}
    \rightarrow
    \text{request and policy validation}
    \rightarrow

.. math:: 

    \begin{cases}
      \text{tool execution} & \text{if permitted} \\
      \text{denial observation} & \text{if denied}
    \end{cases}
    \rightarrow
    \text{trace event}

Both cases are represented by a ``ToolObservation`` object. 

A denied proposal becomes an observation such as:

.. code-block:: python

    denied = ToolObservation(
        ok=False,
        tool="reserve_resource",
        error_code="action_gate_denied",
        message="user_id does not match the authenticated user",
    )

This observation is recorded and returned to the model. The model may then propose a corrected action or
produce a truthful blocked response. It may not report that the reservation succeeded.


Midterm Project Repository Overview 
------------------------------------

Here is an overview of the code repository for the midterm: 

.. code-block:: text

    coe379lfa26-midterm/
    ├── ASSIGNMENT.md
    ├── IMPLEMENTATON_STEPS.md
    ├── ARCHITECTURE.md
    ├── corpus/
    │   └── policies.json
    ├── data/
    │   ├── initial_state.json
    │   ├── public_scenarios.json
    │   └── public_scripts.json
    ├── src/atlas_agent/
    │   ├── models.py
    │   ├── retrieval.py
    │   ├── simulator.py
    │   ├── tools.py
    │   ├── llm.py
    │   ├── policy_context.py
    │   ├── evaluation.py
    │   ├── public_benchmark.py
    │   ├── agent_models.py          # student edits
    │   ├── prompts.py               # student edits
    │   ├── agent.py                 # student edits
    │   └── validation.py            # student edits
    └── tests/
  │   └── test_student_cases.py.py   # student adds


Module Responsibilities
^^^^^^^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 28 52 20

   * - Module
     - Responsibility
     - Student edits?
   * - ``models.py``
     - Trusted requests, observations, traces, and final responses
     - No
   * - ``tools.py``
     - Tool argument models and deterministic dispatch
     - No
   * - ``llm.py``
     - Structured LLM interface, deterministic test double, and optional live adapter
     - No
   * - ``policy_context.py``
     - Converts trace events into reservation-policy facts
     - No
   * - ``agent_models.py``
     - Model decision variants and discriminated union
     - Yes
   * - ``prompts.py``
     - System instructions and initial message construction
     - Yes
   * - ``agent.py``
     - Bounded decision--action--observation loop
     - Yes
   * - ``validation.py``
     - Request binding, reservation preconditions, and final consistency
     - Yes

You should read all of the code, but you should only modify the modules marked ``Yes``.


``ScriptedLLM`` and Deterministic Development
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

As previously mentioned, the midterm code repo provides two implementations 
of the LLM backend. 
Both model backends implement the same interface:

.. code-block:: python

    from typing import Protocol

    class StructuredLLM(Protocol):
        def generate(
            self,
            *,
            messages: list[dict[str, str]],
            response_model: TypeAdapter[Any],
        ) -> Any:
            """Return one object validated against response_model."""

``ScriptedLLM`` returns a predefined sequence of decisions. It makes no network call, so tests remain
deterministic and do not depend on live-model availability. ``OpenAICompatibleLLM`` provides the 
same interface for working with a "live" HTTP inference service, like the one hosted at TACC. 

For the midterm, we do not require you to make use of the ``OpenAICompatibleLLM`` interface, 
but it is there if you would like to experiment with it. 


Step 0: Validating Your Checkout
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In Step 0 we make sure you are able to set up the environment and run the tests 
before you edit any source files.

First, install the development environment from the repository root:

.. code-block:: bash

  uv sync --extra dev

Run the supplied tests:

.. code-block:: bash

    uv run pytest \
      tests/test_retrieval.py \
      tests/test_tools.py \
      tests/test_llm.py \
      tests/test_policy_context.py

These tests should pass before any TODO is changed. A failure at this stage is an environment or
supplied-infrastructure problem, not a student agent implementation failure.

Invoke the tools without an LLM:

.. code-block:: bash

  uv run atlas-demo-tools

The command invokes three tools:

1. ``get_user_authorizations``;
2. ``get_resource_status``; and
3. ``search_lab_documents``.

Each invocation returns one ``ToolObservation``. For every observation, locate:

* ``ok``;
* ``tool``;
* ``data``;
* ``error_code``; and
* ``message``.

Finally, read ``ARCHITECTURE.md`` and inspect the supplied modules in this order:

1. ``models.py``;
2. ``tools.py``;
3. ``llm.py``; and
4. ``policy_context.py``.

Do not begin Milestone 1 until Milestone 0 passes.

Milestone 0: Check Your Understanding 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You should be able to answer the following questions: 

* Which object contains the authenticated user ID?
* Which module validates tool-specific arguments?
* Which object distinguishes success from a tool error?
* Which model backend performs no network calls?
* Which four modules are normally edited by students?

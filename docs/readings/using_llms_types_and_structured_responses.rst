Using Local Language Models: APIs, Hallucinations, Types, and Structured Responses
==================================================================================

Foundation models become useful components of software systems when applications can call them through
well-defined interfaces. The model itself generates a sequence of tokens, but the surrounding application
must decide how to construct the request, interpret the response, detect failures, and determine whether the
generated content is safe to use.

This reading introduces four related ideas:

1. calling a language model through an OpenAI-compatible HTTP API
2. observing and classifying hallucinations using a small fictional corpus
3. defining and validating typed data with Pydantic, and
4. requesting structured responses and checking them with ordinary Python code.

The examples use a TACC-hosted language model, but most of the client code is independent of the particular
model provider. We will provide the base URL, model identifier, and authentication instructions
for the course inference service.

Learning Objectives
-------------------

By the end of this reading, you should be able to:

* distinguish a language model from an inference service and a client application
* construct a basic request to an OpenAI-compatible chat-completions endpoint
* locate the generated content in the returned response object
* distinguish supported, contradicted, and unsupported claims
* define required, optional, nested, and constrained fields with Pydantic
* validate Python data and JSON text against a Pydantic model
* distinguish requesting JSON, validating JSON, and constraining generation to a JSON Schema
* explain why a structurally valid response can still contain an unsupported claim
* design an output type that allows a model to report insufficient evidence


Part 1: OpenAI-Compatible APIs and TACC Language Models
-------------------------------------------------------

Model, Service, and Application
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It is useful to distinguish three pieces of an AI system:

* The **model** consists primarily of an architecture and learned parameter values.
* The **inference service** loads the model and makes it available through a network interface.
* The **client application** constructs requests, calls the service, interprets the replies, and decides
  what to do with the generated content.

Changing a prompt changes the input to an inference request, but it does not make any change to its
parameters. Similarly, validating a response is work performed by the application after
model inference. In other words, validation is performed separately from the model and to some extent 
is application-specific. 

An HTTP Inference Interface
^^^^^^^^^^^^^^^^^^^^^^^^^^^

An inference service commonly exposes an HTTP API. A client sends a request containing data such as the model
identifier, messages, and decoding controls. The service returns a structured response containing the generated
message along with metadata about the request.

For a chat-style language model, the conceptual request looks like this:

.. code-block:: json

    {
      "model": "course-model-id",
      "messages": [
        {
          "role": "system",
          "content": "Answer as a concise scientific teaching assistant."
        },
        {
          "role": "user",
          "content": "What is the difference between training and inference?"
        }
      ],
      "temperature": 0.0
    }

The list of messages is structured data handled by the client and inference server. Before the model processes
the request, the server normally converts these messages into the model's expected token sequence using its
chat template.

The response is also structured. A simplified response might look like:

.. code-block:: json

    {
      "id": "request-123",
      "choices": [
        {
          "message": {
            "role": "assistant",
            "content": "Training updates model parameters, whereas inference uses fixed parameters to produce an output."
          }
        }
      ],
      "usage": {
        "prompt_tokens": 32,
        "completion_tokens": 17,
        "total_tokens": 49
      }
    }

The HTTP request succeeded if the server returned a successful status and a well-formed response, but that 
does not establish anything about the validity of the generated content.

What Does "OpenAI-Compatible" Mean?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Several inference servers implement request paths and data structures modeled after the OpenAI API. This is
commonly described as an **OpenAI-compatible API**. Compatibility makes it possible to use the same client
library with different model services by changing configuration such as the base URL and model identifier.

OpenAI compatibility should not be interpreted as a single, independently governed specification. Different
servers may support different endpoints, fields, or structured-output capabilities. Even when two servers
accept the same request, the available models and generated results may differ.

For this reason, application code should make its assumptions explicit:

* Which endpoint is required?
* Which request parameters are required?
* Which optional features does the server support?
* What errors or incomplete responses can occur?

The examples below use the chat-completions interface because it is widely implemented by local inference
servers. Other interfaces, including the OpenAI Responses API, use different request and response structures.

Getting an API Credential
^^^^^^^^^^^^^^^^^^^^^^^^^

For the class, we are providing you with access to TACC-hosted LLMs. In order to use these AI 
services, you need an authentication token. Navigate to the `Tapis UI dashboard <https://tacc.tapis.io>`_
and login with your TACC account, password and MFA token. Once logged in, you should see a 
wheel icon in the bottom-left corner of the screen with your username. Click that icon to expose 
your JSON Web Token (JWT), and in the modal window that opens up, click the "copy token" icon. 

.. figure:: ./images/Tapis-JWT.png
    :width: 700px
    :align: center
    :alt: Getting an API token

    Getting an API token

Note that the token expires. You will need to redo this step every four hours to get a fresh token. 

Configuring the Python Client
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The official OpenAI Python package can also serve as a client for many OpenAI-compatible services. The client
needs three pieces of configuration:

* the base URL of the inference service;
* an API key or other course-provided credential; and
* the identifier of a model served at that URL.

Store credentials in environment variables rather than placing them directly in a notebook:

.. code-block:: bash

    export TACC_LLM_BASE_URL="https://coe379l-fa26-llm.pods.tacc.tapis.io/v1"
    export TAPIS_JWT="YOUR-JWT"
    export TACC_LLM_MODEL="Llama-4-Maverick-17B-128E-Instruct"
    # or 
    export TACC_LLM_MODEL="MiniMax-M2.7"

There are different models available from our inference service. We recommend you try one of the 
two models above. 

.. warning::    

   Do not paste your JWT into a notebook that will be committed to Git, submitted with an assignment, or
   shared with another student.

Create the client in Python:

.. code-block:: python3

    import os

    from openai import OpenAI

    BASE_URL = os.environ["TACC_LLM_BASE_URL"]
    TAPIS_JWT = os.environ["TAPIS_JWT"]
    MODEL = os.environ["TACC_LLM_MODEL"]

    client = OpenAI(
        base_url=BASE_URL,
        api_key=API_KEY,
    )

Like many HTTP APIs, the base URL points the client code at a particular service. 
The ``model`` field in an individual request selects a model to use. This identifier must be known 
to the API service. A model identifier that works on one service is not necessarily meaningful on 
another service.

Making a Request
^^^^^^^^^^^^^^^^

The following helper sends a list of messages and returns the generated text:

.. code-block:: python3

    def generate_text(
        messages: list[dict[str, str]],
        *,
        temperature: float = 0.0,
    ) -> str:
        completion = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            temperature=temperature,
            max_tokens=300,
        )

        content = completion.choices[0].message.content
        if content is None:
            raise RuntimeError("The inference service returned no message content.")

        return content


    messages = [
        {
            "role": "system",
            "content": "Answer as a concise scientific teaching assistant.",
        },
        {
            "role": "user",
            "content": "Explain the difference between training and inference in two sentences.",
        },
    ]

    answer = generate_text(messages)
    print(answer)

Notice that ``completion`` and ``content`` are different objects:

* ``completion`` is the response envelope returned by the inference service.
* ``content`` is the text generated by the model and placed inside that envelope.

The response envelope can be structurally valid even when the generated content contains an error.

.. admonition:: Exercise 1: Inspect the interface

   1. Run the request above.
   2. Display ``completion`` before extracting its message content. If you use the helper exactly as written,
      temporarily add ``print(completion)`` inside the function.
   3. Locate the model identifier, generated message, finish reason, and token-usage information, if the service
      provides them.
   4. Change the user message without changing the model. Explain why this is inference rather than training.


Part 2: Hallucinations
----------------------

An Operational Definition
^^^^^^^^^^^^^^^^^^^^^^^^^

In this course, we will call generated content a **hallucination** when it presents a claim as factual or
supported even though the claim is unsupported by the evidence the system was required to use, contradicts
that evidence, or refers to fabricated evidence.

This definition is deliberately operational. If an application tells the model to use only a supplied corpus,
we can inspect that corpus and ask whether it supports the generated claims. NIST uses the term
**confabulation** for confidently presented erroneous or false generated content and notes that generated
citations and logic may also be confabulated.

Truth and evidential support are related but distinct:

* A claim may be correct and supported by the supplied evidence.
* A claim may happen to be correct but remain unsupported by the permitted evidence.
* A claim may be both unsupported and factually incorrect.

In a question-answering system, an unsupported answer is a system failure even if it happens to be
correct. The system has not demonstrated where the answer came from, and a user cannot inspect its basis.

A Fictional Polymer Corpus
^^^^^^^^^^^^^^^^^^^^^^^^^^

Continuing with our example from the first reading, suppose an industrial engineering lab maintains 
a catlog of the methods, results, and limitations recorded for all experiments that manufacture 
polymers. 

We'll make use of the following three fictional passages for this exercise. We'll assume 
this is the complete set of records for a given experiment. 

.. code-block:: python3

    POLYMER_CORPUS = """
    [POLY-17#methods]
    Specimens of grades P-A and P-B were conditioned at 23 degrees Celsius
    for 48 hours before tensile testing.

    [POLY-17#results]
    Mean tensile strengths were 41.2 MPa for P-A and 46.8 MPa for P-B.

    [POLY-17#limitations]
    The study did not perform ultraviolet-aging experiments.
    """.strip()

Because we're assuming the corpus above is complete, outside knowledge cannot legitimately supply 
any additional or missing experimental details. Thus, we want the model to distinguish information 
that is literally included in the passages from information that merely sounds plausible.

A Weak Initial Prompt
^^^^^^^^^^^^^^^^^^^^^

Begin with a minimally constrained prompt:

.. code-block:: python3

    def ask_weak(question: str, *, temperature: float = 0.0) -> str:
        messages = [
            {
                "role": "user",
                "content": f"""
                Read this report and answer the question.

                REPORT:
                {POLYMER_CORPUS}

                QUESTION:
                {question}
                """.strip(),
            }
        ]
        return generate_text(messages, temperature=temperature)


    questions = [
        "How were the specimens conditioned before tensile testing?",
        "After how many hours of UV exposure did P-B fall below 40 MPa?",
        "Why did the researchers choose 500 hours as the UV-exposure duration?",
    ]

    for question in questions:
        print("QUESTION:", question)
        print("ANSWER:", ask_weak(question))
        print()

The first question is answerable. The second asks for an experiment that the report explicitly says was not
performed. The third contains a false premise: the corpus never says that the researchers selected a 500-hour
duration.

A model might answer all three correctly, answer one or more with unsupported details, or explicitly reject the
false premise. Model behavior is an observation, not something that should be assumed before running the request.

The Evidence-Constrained Prompt
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Now state the evidence policy and desired abstention behavior:

.. code-block:: python3

    SYSTEM_PROMPT = """
    Answer using only the supplied report passages.
    Do not use outside knowledge or invent missing details.
    Cite the passage identifiers supporting factual claims.
    If the report does not contain enough information, say
    "insufficient evidence" and briefly identify what is missing.
    """.strip()


    def ask_grounded(question: str, *, temperature: float = 0.0) -> str:
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"REPORT:\n{POLYMER_CORPUS}\n\nQUESTION:\n{question}",
            },
        ]
        return generate_text(messages, temperature=temperature)


    for question in questions:
        print("QUESTION:", question)
        print("ANSWER:", ask_grounded(question))
        print()

The stronger prompt does not guarantee correct behavior. It does, however, communicate four requirements that
the weak prompt omitted:

1. the permitted evidence;
2. the prohibition against filling gaps with outside knowledge;
3. the citation requirement; and
4. the option to abstain.

Classifying the Responses
^^^^^^^^^^^^^^^^^^^^^^^^^

Classify each factual claim in a response using the following categories:

``supported``
    The supplied passage entails or directly establishes the claim.

``contradicted``
    The supplied passage conflicts with the claim.

``unsupported``
    The passages neither establish nor directly contradict the claim.

``appropriate abstention``
    The response correctly states that the corpus lacks the evidence needed to answer.

For example, suppose the response says:

    P-B fell below 40 MPa after 500 hours of UV exposure [POLY-17#results].

The cited identifier exists, but the passage says nothing about UV exposure. The claim is unsupported. Citation
existence and citation support are therefore different properties.

.. admonition:: Exercise 2: Evaluate generated claims

   1. Run the weak and evidence-constrained prompts on all three questions.
   2. Record the model identifier and temperature used.
   3. Classify each response as supported, contradicted, unsupported, or an appropriate abstention.
   4. Check every cited passage identifier. Does it exist? Does its passage actually support the associated
      claim?
   5. Repeat at least one question with a higher temperature. Did the wording or factual content change?

If the live inference service is unavailable, use the instructor-provided captured responses. These should be
actual responses previously collected from the course model together with their prompts and decoding settings.

Temperature and Factuality
^^^^^^^^^^^^^^^^^^^^^^^^^^

Temperature changes how the inference server selects tokens from the model's predicted distribution. A higher
temperature generally increases sampling variation. A temperature of zero commonly requests greedy decoding or
otherwise disables sampling on local inference servers.

Lowering temperature may make repeated outputs more stable but it does not automatically eliminate 
hallucination. A confidently generated unsupported answer can appear at temperature zero.


Part 3: Data Types and Validation with Pydantic
------------------------------------------------

Why Introduce Types?
^^^^^^^^^^^^^^^^^^^^

So far, ``generate_text`` returns a string. A string permits just about any kind of response, 
including a paragraph, a Markdown table, JSON, which may or may not be properly formatted, and so on. 
If the application needs to make a decision based on the output, an unconstrained string is a 
very weak interface.

A **type** describes the values a program is prepared to accept and manipulate. Python type 
annotations document the intended types of values. We have seen some types just above, for example:

.. code-block:: python3

    question: str
    temperature: float
    citations: list[str]

Note that Python type annotations are optional and, by themselves, do not provide the same guarantees 
that type systems in compiled languages like Rust or Java provide. Moreover, even when the type 
system provides some compile-time guarantees, data arriving over HTTP or generated by
an LLM remains untrusted. We will use Pydantic data models and Python type annotations to parse and 
validate such data at runtime.

A First Pydantic Model
^^^^^^^^^^^^^^^^^^^^^^
In COE 332, we looked at Pydantic data models and types extensively. In what follows, we provide 
a quick review of that material. The treatment here is not intended to be a full, exhuastive treatment. 
If you are unfamiliar with these concepte or want a more comprehensive treatment, we suggest 
you review the COE 332 materials; e.g., 
`here <https://coe-332-sp26.readthedocs.io/en/latest/unit02/json.html#modeling-data-with-pydantic-a-first-look>`_ 
and `here <https://coe-332-sp26.readthedocs.io/en/latest/unit06/advanced_fastapi.html#the-post-and-put-modeling-request-messages-with-pydantic>`_. 

A Pydantic model is a class that inherits from ``BaseModel`` and describes a more 
complex data structure. For example, we could describe a ``Citation`` object and an 
``EvidenceResponse`` object using Pydantic as follows: 

.. code-block:: python3

    from pydantic import BaseModel, ConfigDict


    class Citation(BaseModel):
        model_config = ConfigDict(extra="forbid")

        passage_id: str


    class EvidenceResponse(BaseModel):
        model_config = ConfigDict(extra="forbid")

        answer: str
        citations: list[Citation]

The ``Citation`` object has a single field, ``passage_id``, providing the identifier of the 
passage. This ``EvidenceResponse`` model describes a response with two required fields:

* An ``answer`` field, which must contain a string
* A ``citations`` field, which must contain a list of ``Citation`` objects. 

This is an example of composing two Pydantic models together. 

One powerful aspect of Pydantic is its ability to automatically validate some data as conforming 
to the specified structure. The parameter 
``extra="forbid"`` causes Pydantic's built-in validation to reject fields that the schema did not 
declare. Without that setting, Pydantic's default behavior may ignore additional input fields. 
Rejecting extra fields is often preferable at a strict software boundary because unexpected 
information does not silently disappear.

Constructing and Serializing a Model
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Pydantic can validate whether an ordinary Python dictionary contains a valid 
``EvidenceResponse`` object, and generate one if it does:

.. code-block:: python3

    response = EvidenceResponse.model_validate(
        {
            "answer": "The specimens were conditioned at 23 degrees Celsius for 48 hours.",
            "citations": [
                {"passage_id": "POLY-17#methods"},
            ],
        }
    )

    print(response.answer)
    print(response.citations[0].passage_id)
    print(response.model_dump())
    print(response.model_dump_json(indent=2))

After successful validation, ``response`` is an ``EvidenceResponse`` object. It contains fields 
corresponding to the structure defined by the ``EvidenceResponse`` data type. For example, it 
contains a list of ``Citation`` objects, each with a ``passage_id`` field. 

Validation Errors
^^^^^^^^^^^^^^^^^

If the input does not match the model, Pydantic raises ``ValidationError``:

.. code-block:: python3

    from pydantic import ValidationError


    invalid_data = {
        "answer": "The specimens were conditioned before testing.",
        "citations": "POLY-17#methods",
    }

    try:
        EvidenceResponse.model_validate(invalid_data)
    except ValidationError as exc:
        print(exc)

The value of ``citations`` is a string, but the model requires a list. A validation error is an expected result
when untrusted data does not conform to the interface. Applications should be written to handle 
these kinds of errors.

Validating JSON Text
^^^^^^^^^^^^^^^^^^^^

LLM-generated content normally arrives as text. If that text is intended to be JSON, our applications 
should validate it. For example:

.. code-block:: python3

    raw_json = """
    {
      "answer": "The specimens were conditioned at 23 degrees Celsius for 48 hours.",
      "citations": [
        {"passage_id": "POLY-17#methods"}
      ]
    }
    """

    parsed = EvidenceResponse.model_validate_json(raw_json)
    print(parsed)

This operation can fail in at least two kinds of ways:

* the text may not be syntactically valid JSON
* the JSON may be valid but fail the Pydantic field requirements.

These are different from a factual or evidential failure. The answer can pass JSON parsing and Pydantic validation
while still citing an irrelevant passage.

Required, Nullable, and Optional Fields
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Consider the following declarations:

.. code-block:: python3

    class Example(BaseModel):
        required_text: str
        required_but_nullable: str | None
        optional_with_default: str | None = None

``required_text`` must be present and cannot be ``None``. ``required_but_nullable`` must be present, but its value
may be a string or ``None``. ``optional_with_default`` may be omitted, and if it is omitted, 
Pydantic supplies a default value of ``None``.

These distinctions matter when designing the allowable set of responses. A field can be required to 
appear while still allowing an explicit ``null`` value, or it can be omitted entirely.

Constraining Values with ``Literal``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If only a small set of string values is valid, one can use either a ``Literal`` or an ``Enum``. 
The ``Literal`` can be written in-line but does not allow for reuse across the code base. 
For example: 

.. code-block:: python3

    from typing import Literal


    class ReviewedResponse(BaseModel):
        status: Literal["answered", "insufficient_evidence"]
        answer: str | None = None

In this case, if the ``status`` field is assigned the value ``"unknown"``, then validation will fail  
because it is not one of the two permitted status values.

Generating JSON Schema
^^^^^^^^^^^^^^^^^^^^^^

Pydantic can translate a model into JSON Schema:

.. code-block:: python3

    import json


    schema = EvidenceResponse.model_json_schema()
    print(json.dumps(schema, indent=2))

JSON Schema is a language-independent description of JSON data. It can describe objects, arrays, required fields,
permitted primitive types, and many other constraints. This gives us a method to bridge a type 
define in our Python application to another computer program, even one written in a different 
programming language. 

Limits on Pydantic Type Checking
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Suppose that this object passes validation:

.. code-block:: json

    {
      "answer": "P-B fell below 40 MPa after 500 hours of UV exposure.",
      "citations": [
        {"passage_id": "POLY-17#results"}
      ]
    }

What we know is that Pydantic has verified that ``answer`` is a string and that ``citations`` is a 
list containing an object of the required shape. But note that it has not 
established any number of additional checks, such as: 

* ``POLY-17#results`` exists in the permitted corpus
* the passage supports the claim
* the claim answers the user's question 
* the claim is true

Some of these properties can be checked by additional deterministic code. Others may require human judgment or
more sophisticated verification.

For example, citation existence can be checked exactly:

.. code-block:: python3

    VALID_PASSAGE_IDS = {
        "POLY-17#methods",
        "POLY-17#results",
        "POLY-17#limitations",
    }


    def find_unknown_citations(response: EvidenceResponse) -> list[str]:
        return [
            citation.passage_id
            for citation in response.citations
            if citation.passage_id not in VALID_PASSAGE_IDS
        ]

This validator can be used to check that the set of citations provided in a response 
actaully exist. But of course, it does not verify any of the items in the list above. 

.. admonition:: Exercise 3: Work with typed data

   1. Construct a valid ``EvidenceResponse`` for the conditioning question.
   2. Remove the ``answer`` field and inspect the resulting validation error.
   3. Change ``citations`` from a list into a string and inspect the error.
   4. Add an unexpected field and verify that ``extra="forbid"`` rejects it.
   5. Construct a response containing ``POLY-17#missing`` and run ``find_unknown_citations``.
   6. Explain why the final object can be valid Pydantic data while being invalid according to the corpus.


Part 4: Structured Responses
----------------------------

Three Different Guarantees
^^^^^^^^^^^^^^^^^^^^^^^^^^

The phrase **structured response** is sometimes used for several different mechanisms. We will 
adopt the following terminology to try and avoid ambiguity:

1. **Prompt-requested JSON:** The prompt asks the model to return JSON. The output may still contain prose,
   malformed JSON, or unexpected fields.
2. **JSON mode:** The inference service constrains the output to valid JSON, but not necessarily to a particular
   schema.
3. **Schema-constrained output:** The inference service constrains generation to a supported JSON Schema.

Pydantic validation can be applied after any of these. If the service supports schema-constrained output, a
Pydantic model may also be used to provide the schema before generation.

The official OpenAI documentation calls the third mechanism **Structured Outputs** and distinguishes it from
JSON mode: JSON mode ensures valid JSON, while Structured Outputs additionally enforces a supported schema.
OpenAI-compatible local servers may implement both, one, or neither mechanism.

A Minimal Approach to Maximize Portability
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The simplest and most portable approach is to include the schema requirements in the prompt, 
request JSON text, and then validate the returned text in the client application:

.. code-block:: python3

    import json


    schema_text = json.dumps(EvidenceResponse.model_json_schema(), indent=2)

    messages = [
        {
            "role": "system",
            "content": "Return only JSON matching the supplied schema.",
        },
        {
            "role": "user",
            "content": f"""
            REPORT:
            {POLYMER_CORPUS}

            QUESTION:
            How were the specimens conditioned before tensile testing?

            JSON SCHEMA:
            {schema_text}
            """.strip(),
        },
    ]

    raw_output = generate_text(messages, temperature=0.0)
    print(raw_output)

    try:
        typed_output = EvidenceResponse.model_validate_json(raw_output)
    except ValidationError as exc:
        print("The model did not return the required structure:")
        print(exc)
    else:
        print("The response has the required structure:")
        print(typed_output)

This does not guarantee that the model will produce valid JSON on its first attempt. 
To some extent, this limitation can be mitigated with the subsequent techniques.

Server-Enforced Structured Output
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When the inference service and model support schema-constrained output, the OpenAI Python client provides a
convenient ``parse`` interface:

.. code-block:: python3

    completion = client.chat.completions.parse(
        model=MODEL,
        messages=messages,
        response_format=EvidenceResponse,
    )

    typed_output = completion.choices[0].message.parsed

This example is not assumed to work on every OpenAI-compatible server.

An Intentionally Inadequate Type
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Now consider the unanswerable UV-exposure question. We could define:

.. code-block:: python3

    class ForcedUVAnswer(BaseModel):
        model_config = ConfigDict(extra="forbid")

        uv_exposure_hours: int
        citation: str

This type has no valid way to express that the experiment was not performed. It requires an integer and a
citation in every successful response.

Ask the model:

.. code-block:: python3

    forced_schema = json.dumps(ForcedUVAnswer.model_json_schema(), indent=2)

    forced_messages = [
        {
            "role": "system",
            "content": "Use only the report. Return only JSON matching the supplied schema.",
        },
        {
            "role": "user",
            "content": f"""
            REPORT:
            {POLYMER_CORPUS}

            QUESTION:
            After how many hours of UV exposure did P-B fall below 40 MPa?

            JSON SCHEMA:
            {forced_schema}
            """.strip(),
        },
    ]

    forced_raw = generate_text(forced_messages, temperature=0.0)
    print(forced_raw)

There are several possible outcomes:

* The model may fabricate an integer and citation that satisfy the requested structure.
* The model may violate the requested structure and abstain in prose.
* A schema-constrained server may produce a structurally valid object containing an unsupported value.
* The service may return a separate refusal or error outside the requested schema.

None of these possibilities changes the basic fact that the corpus does not contain a UV-exposure 
result.

A Type That Represents Insufficient Evidence
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The output type should represent both successful answers and expected failure conditions:

.. code-block:: python3

    class UVAnswer(BaseModel):
        model_config = ConfigDict(extra="forbid")

        status: Literal["answered", "insufficient_evidence"]
        uv_exposure_hours: int | None = None
        citations: list[str]
        missing_information: str | None = None

A justified answer could look like:

.. code-block:: json

    {
      "status": "answered",
      "uv_exposure_hours": 500,
      "citations": ["POLY-17#uv-results"],
      "missing_information": null
    }

An abstention could look like:

.. code-block:: json

    {
      "status": "insufficient_evidence",
      "uv_exposure_hours": null,
      "citations": ["POLY-17#limitations"],
      "missing_information": "The report states that no ultraviolet-aging experiment was performed."
    }

Only the second object is consistent with our fictional corpus.

Cross-Field Consistency
^^^^^^^^^^^^^^^^^^^^^^^

The ``UVAnswer`` model still permits combinations that do not make sense. For example, this object satisfies the
individual field types:

.. code-block:: json

    {
      "status": "insufficient_evidence",
      "uv_exposure_hours": 500,
      "citations": [],
      "missing_information": null
    }

The fields are individually well typed but mutually inconsistent. Ordinary Python can check the relationship:

.. code-block:: python3

    def check_uv_response(response: UVAnswer) -> list[str]:
        errors: list[str] = []

        if response.status == "answered":
            if response.uv_exposure_hours is None:
                errors.append("answered_response_missing_uv_exposure_hours")
            if not response.citations:
                errors.append("answered_response_missing_citations")

        if response.status == "insufficient_evidence":
            if response.uv_exposure_hours is not None:
                errors.append("abstention_must_not_claim_uv_exposure_hours")
            if not response.missing_information:
                errors.append("abstention_missing_explanation")

        errors.extend(
            f"unknown_citation:{citation}"
            for citation in response.citations
            if citation not in VALID_PASSAGE_IDS
        )

        return errors

This illustrates three layers of checking:

1. JSON parsing checks whether the text is syntactically valid JSON.
2. Pydantic checks field presence, primitive types, nesting, and declared constraints.
3. Application validators check relationships to the task, corpus, and execution state.

Later in the course, we will use distinct Pydantic types for different outcomes. For example, an agent may return
a tool-call decision, a clarification decision, or a final-response decision. Such a union can make more invalid
combinations unrepresentable, while ordinary validators enforce properties that depend on external evidence or
the recorded execution trace.

.. admonition:: Exercise 4

   1. Request a ``ForcedUVAnswer`` using the unanswerable UV question. Record whether the model fabricates a
      value, breaks the schema, or abstains.
   2. Repeat the request using the ``UVAnswer`` schema.
   3. Validate the returned JSON with ``UVAnswer.model_validate_json``.
   4. Run ``check_uv_response`` on the typed result.
   5. Explain which properties were checked by Pydantic and which required application-specific code.
   6. Does a response with an existing citation necessarily contain a supported claim? Explain.


Putting the Pieces Together
---------------------------

The complete data flow is now:

.. math::

    \text{typed app input}
    \rightarrow
    \text{HTTP request}
    \rightarrow
    \text{model generation}
    \rightarrow
    \text{response}


    \rightarrow
    \text{JSON parsing}
    \rightarrow
    \text{type validation}
    \rightarrow
    \text{app validation}

Each arrow crosses an interface at which something can go wrong:

* the request may be malformed
* the service may be unavailable or time out
* the model may generate unsupported content
* the response may be truncated
* the generated text may not be valid JSON
* the JSON may fail the declared schema
* a typed response may cite nonexistent evidence
* an existing citation may not support the associated claim.

This is why a language model should be treated as one component of a larger software system. The model proposes
an output. The surrounding program decides what structure is required, which checks can be performed, and whether
the output is acceptable for the next step.


Summary
-------

The central ideas of this reading are:

* OpenAI-compatible APIs provide a common family of HTTP request and response conventions, but implementations
  may differ.
* A successful API call establishes that inference occurred, but the generated content requires significant 
  validation. 
* A robust system must distinguish supported claims, contradictions, unsupported claims, and justified
  abstentions.
* Pydantic validates and converts untrusted data into typed Python objects or raises a validation error.
* JSON syntax, schema conformance, evidential support, and factual correctness are distinct properties.
* Asking an LLM for JSON in the prompt is weaker than server-enforced schema-constrained generation.
* Output types should represent expected failure states such as insufficient evidence.
* Deterministic application code can check some properties, such as the existence of citations 
  and cross-field consistency, even though it cannot automatically establish every factual claim.

These ideas will be useful with retrieval-augmented generation (RAG), in which an application 
retrieves evidence and places it in the model's context 
We'll build upon it further when we investigate agent architectures, where typed model 
decisions can request actions from external tools.


References and Further Reading
------------------------------

* `OpenAI: Structured model outputs <https://developers.openai.com/api/docs/guides/structured-outputs>`_
* `Pydantic: Models <https://pydantic.dev/docs/validation/latest/concepts/models/>`_
* `Pydantic: JSON Schema <https://pydantic.dev/docs/validation/latest/concepts/json_schema/>`_
* `NIST AI 600-1: Artificial Intelligence Risk Management Framework—Generative Artificial Intelligence Profile <https://doi.org/10.6028/NIST.AI.600-1>`_

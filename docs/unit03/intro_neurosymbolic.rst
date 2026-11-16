Neurosymbolic Architecture: A First Look 
=========================================

In this first lecture, we look at two application examples we have studied before: FormalLitQA, which is an example 
of a Question-Answer system leveraging retrieval augmented generation (RAG), and our Lab Equipment Management Agent 
software, which is an example of a bounded agentic application. We first discuss the limits of pure-Python JSON 
validation and then introduce a first neurosymbolic architecture pattern: the verified checker. We then show how 
to implement several of the components to realize this pattern in the FormalLitQA setting. 


By the end of this module, students should be able to: 

* Describe the basic components of a neurosymbolic architecture 
* Describe the verified checker pattern 
* Explain at a high level how the verified checker patten can be implemented in FormalLitQA and the Lab Agent software 
* Implement Lean types, a Lean checker function, and state a specification theorem in the FormalLitQA setting. 

Motivation: Limits of Structured JSON 
-------------------------------------

We have seen that we can leverage structured JSON to control and validate the shape of interactions between components 
of our system, including requests and responses to and from an LLM. Furthermore, we know how to use libraries like 
Pydantic to implement these methods in pure Python. Why, therefore, do we need to introduce Lean? What justifies 
introducing that complexity? 

As we have discussed before, there are two primary sources of limitations: runtime vs compile-time validation and 
finiteness limits on tests as compared with guarantees that can be established with a system like Lean. 

Runtime Versus Compile-time Validation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Python validation such as Pydantic model validation is a *runtime* activity. When an LLM returns a JSON object, 
Pydantic inspects that specific concrete instance, coerces types, checks constraints, and raises a validation error if 
the fields do not match the model definition. These checks are inherently:

* on concrete runtime values after generation has already occurred
* answer the question *Does this specific object, generated at time $t$, conform to this schema?* 
* offer no mechanism to reason about the set of all possible outputs the LLM *might* generate.

Finite Testing Versus Formal Guarantees 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Similarly, there is a fundamental limitation in the guarantees that can be produced from tests written using a framework like 
Pytest. The number of inputs checked is limited by the number of tests written, and in particular, can only ever cover 
a finite set of cases. Moreover, the cases that are covered tend to have the following limitations: 

* Tests tend to be written to cover the *anticipated* failure modes, but 
* Python catches errors after execution (or during pre-flight checks), meaning the system is fundamentally reactive. 
  It filters bad outputs if and when they appear as opposed to precluding them by construction.

Lean provides compile-time guarantees and the ability to write and prove theorems about infinite and/or 
arbitrary cases. When leveraging modern AI and LLMs for applications, these attributes are particularly appealing, 
as the power and capabilities of the models, as well as their unpredictability, increases the challenges related 
to reliability and robustness. 

An Initial Example: FormalLitQA 
-------------------------------

Let us recall the FormalLitQA application discussed earlier in the semester. The idea with Formal-Lit-QA is to answer 
questions using a highly technical and evolving corpus of research articles on a theoretical (or “formal”) topic area.
The topic is evolving, with new articles being published all the time, so the system leverages RAG to augment models 
that will not have been trained on the most recent results. 

The key points of RAG pipeline are as follows: 

* The RAG pipeline ingests theoretical articles with structured text (LaTeX) that allows it to parse chunks of 
  different types and identifying relationships between chunks. 
* Chunk types include: ``Definition``, ``ResultStatement``, ``Proof``, ``Conjecture``, ``AssumptionOrHypothesis``, 
  ``Example``, ``FigureOrTable``. 
* Chunks can also be related to other chunks. For example, a ``Proof`` can be related to a ``ResultStatement``
  through a ``Proves`` relation or through a ``ProofUsesResult`` relation, and a ``ResultStatement`` or a ``Definition``
  can be related to another ``ResultStatement`` or ``Definition`` through a ``References`` relation. 

The output of the pipeline is a set of chunks called a *manifest* and consists of a list of all the chunks and relations 
identified during the ETL process. 


When the user asks a question, the system first queries the manifest for relevant chunks. It then sends these chunks, 
together with the user's initial query, to the LLM. It asks for a structured response (a ``StructuredAnswer`` in the code) 
which includes a list of ``Claims``where each claim includes a reference to one or more chunks (i.e., *evidence*) 
that adhere to certain rules, such as:

* Every claim has a ``ClaimType`` which dictates the rules about the evidence that is required. The different ``ClaimType`` 
  include: ``Definition``, ``ResultStatement``, ``ProvedResult``, ``Dependency``, ``Conjecture``, and ``Explanation``. 
* The ``ClaimType`` is related to (and in some cases, the same as) the chunk types/evidence types, but they are not identical. Think of the 
  claim types as being the types of assertions the system will make in response to a question, while the chunk types are the types 
  of evidence that the system will use to support its claims. 

For example, a user might ask the following: 

    *What is the definition of a cyclic group?* 

The user is asking for a definition. In this case, the system should provide the definition and provide evidence in the form of a 
``Definition`` chunk. For example, 

.. code-block:: json 

    {
      "chunk_id": "arxiv_2512_09280/definition_0001",
      "paper_id": "arxiv_2512_09280",
      "chunk_type": "definition",
      "raw_content": "\\begin{def}[Cyclic Group]\nTLet $G$ be a group. The $G$ is cyclic if there exists $g\in G$ such that \forall x\in G, $x = g^n$ for some $n$.\n\\end{theorem}",
      "normalized_text": "Let G be a group. Then G is cyclic if there exists a g in G such that for all x in G, x = g^n for some n",
      "start_offset": 8677,
      "end_offset": 8773
    }

If instead the user asks a question like: 

  *State and prove the theorem about finite groups of prime order.* 

Then the system should return a claims of type ``ProvedResult`` with supporting evidence of types ``ResultStatement`` and ``Proof``, 
and the two chunks should be related by a ``Proves`` relation. 

Here is a list of rules we could like to implement about a ``StructuredAnswer``: 

1. Every ``Definition`` claim must include a ``Definition`` chunk. 
2. Every ``ResultStatement`` claim must include a ``ResultStatement`` chunk. 
3. Every ``ProvedResult`` claim must include a ``ResultStatement`` chunk and a ``Proof`` chunk, and the ``Proof`` chunk 
   must be related to the ``ResultStatement`` through a ``Proves`` relation. 

How should we go about verifying that our system adheres to these rules?

One option is to write Python tests, but as we have mentioned, this comes with limitations. By incorporating Lean 
into the execution system, we can verify properties using formal methods that come with stronger 

A Second Example: Verified Tool Calling in Agentic Applications
---------------------------------------------------------------

Recall that the Lab Equipment Agent software implemented a bounded agentic loop where the LLM was allowed to propose 
actions, including tool calls, to satisfy a user request. For example, a user might send a request such as: 

   *Reserve the tensile tester for my project tomorrow afternoon.*

The AI model might propose a tool call, such as ``search_lab_documents``, ``get_user_authorizations``, 
``get_resource_status``, ``reserve_resource``, etc. For each tool call proposal, the system performs a set of validations 
before deciding to execute the tool. Those could be roughly classified into the following buckets, in increasing order of complexity:

1. JSON structure validation 
2. Pydantic model validation 
3. Request object validation and action gate 

The third type, `action gate <../unit01/tools_and_agents.html#action-validation>`_, involved various rules we wanted 
the system to adhere to, such as: 

* *No identity substitution* -- any proposed tool call with a ``user_id`` argument must supply the identity from the 
  trusted request object as the value to the argument. 
* *Required authorization check* -- Before a ``reserve_resource`` tool call can be made, at least one authorization 
  call for the proposed ``user_id`` was checked.
* *Availability of resource* -- Before a ``reserve_resource`` tool call can be made, the resource's availability for the 
  proposed reservation time must be established based on the ``available`` field from a ``resource-status`` call. 

Just like in the FormalLitQA case, we could choose to implement these checks in pure Python with Pydantic validation, 
unit tests, and so on. But these will have the same limitations that we have mentioned previously. 

Instead, we can leverage Lean using an architecture that will be very similar to the FormalLitQA case. 

A Common Architecture: "The Verified Checker" Pattern 
-----------------------------------------------------

Here we introduce a high-level architecture that we will refer to as "the verified checker" pattern. This is not 
industry-standard terminology but it resembles closely related ideas from software security and safety engineering 
such as the *reference monitor* concept, originally conceived by James P. Anderson in 1972 as a foundational 
abstraction behind access control and security kernels. 

In security architecture, a reference monitor (see [1]), is an abstract machine that mediates all access between subjects (users/processes) 
and objects (resources/files) according to an explicit security policy. The implementation should satisfy three properties: 

1. *completenes mediation* --- all access attempts must go through the monitor. 
2. *tamperproof* --- the monitor and its policies must be isolated sso that the untrusted component cannot modify them. 
3. *assurance* --- The monitor must be small, simple and structured enough to be formally analyzed and proven to enforce 
   the policy correctly. 

The verified checker pattern implements this architecture as follows: 

1. Application code (in our case, in Python) accepts a user's request and passes it to an LLM using structured JSON. 
2. The LLM responds with a proposal or an answer, also in structured JSON, but this response should be considered untrusted 
   in the sense that the rules we desire of our system (such as the ones described above for FormalLitQA and Lab Agent)
   may be violated. 
3. The Python application sends the untrusted JSON to a *trusted, verified* kernel, written in Lean, that checks whether the 
   rules of the system have been violated. It returns a simple boolean value indicating whether the Python application is allowed 
   to proceed. 
4. The Python application only proceeds with the proposal or answer if it receives an affirmative reply from the Lean kernel. In 
   particular, it **does not** proceed under any error or failure cases, including parsing errors, process timeouts, etc. 

Thus, our Lean kernel plays the role of the reference monitor. This approach is depicted pictorial in the following diagram: 

.. figure:: ./images/verified_checker_arch.jpg
    :width: 800px
    :align: center

In order to implement this architecture, we must be able to do the following at runtime: 

1. Invoke a Lean program from Python with an untrusted JSON object. 
2. In Lean, attempts to parse the (untrusted) JSON object into Lean types, and handle any parsing errors as a failure. 
3. Implement the rules we want verified as an executable Lean function that returns ``True`` if and only if the rules are 
   satisfied. 

In addition to the runtime aspects above, we must also prove a theorem that asserts the correctness of part 3). A key point 
is that this theorem proving activity happens *independently of any runtime activity*, and the theorem itself and its proof 
are not part of the executable application. In particular, we can prove this theorem at any point in development (and before 
the production deployment of the application). 


FormalLitQA: Initial Implementation Details 
-------------------------------------------

Let us consider some of the implementation details for the FornamlLitQA application. Due to time constraints, this will not 
be a comprehensive treatment, but we hope to provide enough of the details to give you a representative picture of what is 
involved. 

Let us postpone the first aspect of calling Lean from Python for a moment and discuss the Lean types, the verifier function, 
and the theorem. We will return to calling Lean from Python at the end. 

Lean Types 
^^^^^^^^^^
Our goal here is to parse an untrusted JSON object into Lean types, so we must model the application's concepts with new 
Lean types. For the FormalLitQA application, we will thus need new types for the concepts of *chunk* and *evidence*. 

In the previous lectures, we saw that we can use ``inductive`` to define sum times and ``structure`` to define product types, 
and we even saw some specific examples for FormalLitQA. For instance, we can define a ``ChunkType`` like so: 

.. code-block:: lean 

  import Lake
  open Lean
  open Lake

  inductive ChunkType where
    | Definition
    | ResultStatement
    | Proof
    | Conjecture
    | AssumptionOrHypothesis
    | Example
    | Discussion
    | FigureOrTable
    | Unknown
    deriving ToJson, FromJson, Repr, DecidableEq, Inhabited


where in the last line we are asking Lean to derive the typeclass instances for various type classes such as ToJson, FromJson, 
etc. A chunk is then codified as follows: 

.. code-block:: lean 

  structure Chunk where
    chunkId : Nat
    chunkType : ChunkType
    deriving ToJson, FromJson, Repr, DecidableEq, Inhabited  

Similarly, the notion of a claim can be modeled like so 

.. code-block:: lean 

  inductive ClaimType where
    | Definition
    | ResultStatement
    | ProvedResult
    | Dependency
    | Conjecture
    | Explanatory
    deriving ToJson, FromJson, Repr, DecidableEq, Inhabited    

  structure Claim where
    claimId : Nat
    claimType : ClaimType
    evidence : List Chunk
    deriving ToJson, FromJson, Repr, DecidableEq, Inhabited

Note that a claim contains a claim type as well as a list of chunks for evidence. This puts us in a strong 
position to implement the rules we described above, such as 

  Rule 1: Every Definition claim must include a Definition chunk.

The Lean Checker 
^^^^^^^^^^^^^^^^

With the types implemented we can turn the third runtime component, the Lean checker. 
Fundamentally, the lean checker is an executable Lean function with the following signature: 

.. code-block:: lean 

    def verify : Json → Bool

Given a JSON object, it returns ``True`` if an only if the JSON conforms to the rules of our system. 

We saw in the previous lecture that we can define a Lean function, ``verify``, as follows: 

.. code-block:: lean 
  :linenos:

  def verify : Json → Bool := fun obj =>
    let claim? : Except _ Claim := fromJson? obj
    match claim? with
    | .ok v =>
        let claimTypeIsDefinition := v.claimType == .Definition
        let hasEvidenceChunk? := List.find? (fun x => x.chunkType == .Definition) v.evidence
        let hasEvidence := hasEvidenceChunk?.isSome
        claimTypeIsDefinition && hasEvidence
    | .error _ => false

Some notes on this implementation: 

* In line 1, we define a ``verify`` function with type ``Json → Bool``; the ``fun obj =>`` is Lean's lambda syntax that 
  binds ``obj`` to the incoming JSON object. 
* In line 2, we attempt to use ``fromJson?`` on the ``obj`` which returns a term of type ``Except Claim``. The function returns 
  an ``Except`` type because parsing into a ``Claim`` could fail. 
* In lines 3, 4 and 8, we are matching between the case of parsing into a ``Claim`` successfully (line 4) or failing to parse a 
  ``Claim`` (line 8). 
* In line 5, we are defining the ``claimTypeIsDefinition`` boolean, and at line 6 and 7 we are defining the ``hasEvidence`` 
  boolean to be the assertion that the claim is a definition, and the claim includes a chunk of type definition, respectively. 
* Finally, at line 7, we are returning the boolean value which is the conjunction of ``claimTypeIsDefinition`` and ``hasEvidence``. 

Taken together, it should be clear that this function implements rule 1. We can now turn to proving that is the case. 

An Initial Formal Specification and Verification 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Let us now turn to formally verifying that the implementation for the ``vierfy`` function above is correct. 

The first step is to define what it means for a definition claim to adhere to the rules. 

.. code-block:: lean 

  def validDefinition : Claim → Prop := fun c =>
    c.claimType = .Definition ∧
    ∃ (e : Chunk), e ∈ c.evidence ∧ e.chunkType = .Definition    

The ``validDefinition`` predicate states that a claim is a valid definition claim if it's type is a ``ClaimType.Definition`` and, 
among the list of evidence chunks, there exists some chunk whose chunkType is Definition. 

Note the signature: ``validDefinition : Claim → Prop := fun c``. This says that ``validDefinition`` is a function from ``Claim`` 
to ``Prop``. That is, given a claim term, it returns a proposition that is the mathematical statement that the claim is a valid 
definition. Recall that, by Curry-Howard, a term inhabiting this proposition is a proof that the proposition is true. 

This highlights a powerful pattern in neurosymbolic architectures: separation of *specification* and *implementation*. 

* ``verify`` is a computable function; it returns a ``Bool`` type and therefore can be compiled into an executable program. 
* ``validDefinition`` is a specification designed for formal reasoning. We can prove theorems that reference is separately 
  from the executable code. 

For example, we can state theorem, as we saw in the previous lecture. 

.. code-block:: lean 

    theorem verifyIsCorrect : ∀ (x : Json),
        verify x = true ↔ ∃ (c : Claim), fromJson? x = .ok c ∧ validDefinition c := by sorry     

We won't revisit the proof at this time, but let's make sure we understand each component of the statement. 

Bidirectional Theorem and Explaining the Mystery at the End of Last Lecture
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The theorem above is *bidirectional*, that is, an if and only if, and it first it may seem like only the forward implication 
is needed. That direction, in natural language, states: 

  *If x is a JSON object, and verify x is true, then there exists a claim, c, such that fromJson x = c and validDefinition c 
  is true.* 

On the surface, this would seem to be what we want. What does the other direction say? 

  *If x is a JSON object, and there exists some c such that fromJson x = c and validDefinition c is true. Then verify x is true.* 

In other words, this direction asserts that if a claim is valid then our verify function will recognize that to be the case. 
Do we need this second direction? 

Suppose I implemented ``verify`` like so: 

.. code-block:: lean 

    def verify : Json → Bool := fun _ => false

That is to say, for every JSON object no matter what I return False. Then the forward direction of the theorem would still 
be true! 

.. code-block:: lean 

    theorem verifyIsCorrect : ∀ (x : Json),
        verify x = true → ∃ (c : Claim), fromJson? x = .ok c ∧ validDefinition c := by sorry 

Indeed, we could say it is *vacuously true* to use terminology from a previous lecture because evidently there would be exactly 
zero JSON objects to check the conclusion against. Thus, we want both directions of the theorem to know that our ``verify`` 
function is both safe and correct in the sense that it permits all of the objects that it should. 

With that in mind, this "weird" theorem isn't so weird after all: 

.. code-block:: lean 

    theorem weird (c : Type) [Inhabited c] (BrowseFb : c → Prop) :
        ∃ (s : c), BrowseFb s → ∀ (x : c), BrowseFb x

All this says is that *there exists* some student, ``c``, such that, if ``c`` is browsing facebook, then every student 
is browsing facebook. There are just two cases: in case 1, every student is browsing facebook, and the result is trivial. 
In case 2, not every student is browsing facebook, so pick some student, call them :math:`T`, that is not browsing facebook. 
Then this implication ``BrowseFb T → ∀ (x : c), BrowseFb x`` is *vacuously true* because the left hand side is false. 

Calling Lean from Python 
^^^^^^^^^^^^^^^^^^^^^^^^

In order to have Lean validating the LLMs proposals and answers, our application must invoke Lean code from 
Python at run time. There are multiple ways to do this, and like all engineering designs, choosing an implementation 
requires considering choices and tradeoffs. For example: 

* The Lean program might be on the same computer as the Python application or it might be on different computers. 
* The performance and scalability requirements might be different for each of the Python and Lean components. 
* There might be security concerns around which programs are allowed to call Lean and how they should call it. 

None of this is new to you. A standard technique is to use a network protocol, such as TCP or HTTP, for communicating 
between two processes. You have seen this many times --- for example, when our Python application calls an inference 
service using HTTP or a database using TCP. 

As an initial implementation, we'll use a simpler approach: we'll invoke Lean from Python using a subprocess and communicate 
via standard in and out (stdin and stdout). The benefit of this approach is its simplicity, particularly on the Lean 
side --- we won't require a TCP stack or HTTP server that is constantly listening for requests and sending replies. 
The downside are the constraints it imposes, primarily, that the Lean program must reside on the same computer. This, in 
turn, imposes limitations on the scalability of the system. But rest assured that nothing about the overall architecture 
meaningfully must change in order to accommodate a more scalable implementation. 


An initial Lean implementation would resemble something like: 

.. code-block:: lean 

  open Lean

  def main : IO Unit := do
    let line ← (← IO.getStdin).getLine
    let allowed :=
        match Json.parse line with
        | .ok claim =>
            verify claim
        | .error _ => false
    -- dump the result to compressed JSON
    IO.println
        ((Json.mkObj [("allowed", toJson allowed)]).compress) 


Then, on the Python side, we use subprocess to invoke the Lean program. For example: 

.. code-block:: python 

    import json
    import subprocess

    def verify_claim_in_lean(claim_data: dict) -> bool:
        try:
            p = subprocess.run(
                ["./.lake/build/bin/checker"],
                input=json.dumps(proposal) + "\n",
                text=True,
                capture_output=True,
                timeout=2,
            )

            if p.returncode != 0:
                return False

            response = json.loads(p.stdout)
            return response.get("allowed") is True

        except (
            OSError,
            subprocess.TimeoutExpired,
            json.JSONDecodeError,
        ):
            return False    


A key point is that any kind of failure between Python and Lean, including parsing errors, failed processes, 
timeouts, etc., all result in the proposal being rejected.

Additional Resources 
---------------------

[1] Reference Monitors. Online: https://www.cs.cornell.edu/fbs/publications/chptr.enfMech.refMonitor.pdf 
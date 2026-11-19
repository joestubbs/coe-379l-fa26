Verified Tool Calling in Agentic Architectures 
==============================================

In this lecture, we continue the techniques and examples from the introduction to Neurosymbolic Architecture 
and look at some implementation details related to tool calling in agentic systems. We will see how to apply the 
verified checker patten to authorization policies for verifying tool calls in the Lab Agent Software system. Then, 
we will expand on some of general-purpose infrastructure needed to integrate Python and Lean into a single system. 

By the end of this lecture, students should be able to: 

* Understand the high-level approach to using the verified checker pattern for agentic tool calling applications. 
* Implement the verified checker for a subset of the functionality in the Lab Agent Software setting. 
* Extend the initial Lean types, specifications, and theorems for FormalLitQA to provide additional guarantees. 

Verified Tool Calling 
---------------------

Recall that in our Lab Agent software setting, the LLM proposes tool calls and our application must check rules 
associated with the proposal. Rules that we would like the system to implement include: 

* *No identity substitution* -- any proposed tool call with a ``user_id`` argument must supply the identity from the 
  trusted request object as the value to the argument. 
* *Required authorization check* -- Before a ``reserve_resource`` tool call can be made, at least one authorization 
  call for the proposed ``user_id`` was checked.
* *Availability of resource* -- Before a ``reserve_resource`` tool call can be made, the resource's availability for the 
  proposed reservation time must be established based on the ``available`` field from a ``resource-status`` call. 

Our approach will be very similar to the one we used for FormalLitQA. We will implement a verified kernel in Lean, 
and our Python code will invoke it at runtime. 

Verification in the Lab Agent: An Initial Implementation 
--------------------------------------------------------

To begin, we'll consider just a subset of the Lab Agent software implementation focused on the ``reserve_resource`` tool. We'll 
focus on verifying the following rules mentioned in the previous lecture 

1. *No identity substitution* -- any proposed tool call with a ``user_id`` argument must supply the identity from the 
   trusted request object as the value to the argument. 
2. *Required authorization check* -- Before a ``reserve_resource`` tool call can be made, at least one authorization 
   call for the proposed ``user_id`` was checked.
3. *Availability of resource* -- Before a ``reserve_resource`` tool call can be made, the resource's availability for the 
   proposed reservation time must be established based on the ``available`` field from a ``resource-status`` call. 

To this end, we'll model the system by including both a *proposal* as well as a *trusted context*, with the latter including 
both the trusted request information as well as the collection of prior tool calls and their results. The tool call 
collection will need to include a history of calls to both the ``check_authorization`` and the ``resource_status`` tools 
to handle rules 2 and 3, respectively. 

Lean Types 
^^^^^^^^^^

As before, we begin by modeling the Lean types. Let us begin with the trusted context. It will be a product type comprised 
of a few components. The first will be the trusted request object, which we define using just a single field: 

.. code-block:: lean 

  structure TrustedRequest where
    userId : String
    deriving Repr    

The ``userId`` field represents the authenticated user, e.g., ``jstubbs``. 

Next we define the collection of prior tool calls. For simplicity, we'll assume a prior two call is just one of the 
``check_authorization`` and the ``resource_status`` tools (there are other tools in the system, but these are the only 
ones we need to recognize to implement the rules above). Thus, a prior tool call will be an inductive type with just 
two constructors: 

.. code-block:: lean 

  inductive ToolCall where
    | authorizationChecked
        (userId : String) (authorized : Bool)
    | resourceStatus
        (resourceId : String) (slot : String)
        (available : Bool)
    deriving Repr, DecidableEq    

Here we are using ``inductive`` to define a sum type of product types. The ``ToolCall`` type itself is a sum type over 
the variants ``authorizationChecked`` and ``resourceStatus``, while each of those are in turn product types with required 
data (term) to construct them. 

The ``authorizationChecked`` variant comes with the data ``userId``, indicating which user was checked, and ``authorized``, 
indicating whether the check passed, while ``resourceStatus`` includes the ``resourceId`` tht was checked, the ``slot``
that was checked, and whether it was ``available``. 

For example, we can construct a tool call by specifying the variant and then the required additional fields, like so: 

.. code-block:: lean 

    def example_toolcall : ToolCall := .resourceStatus "uv-1" "tuesday-10am" true

Another option would be to use ``structure`` to define ``authorizationChecked`` and ``resourceStatus`` as standalone types. 
Should we have done that? It really depends --- do we want the ability to construct those outside of a ``ToolCall`` object? 
If not, then the approach above is preferred. 

We can then model a trusted context as a product of these: 

.. code-block:: lean 

  structure TrustedContext where
    request : TrustedRequest
    history : List ToolCall
    deriving Repr    

The ``history`` term is a ``List`` of ``ToolCall``'s because multiple tool calls could have been previously made (in fact, multiple 
calls will be required before ``reserve_resource`` can be called). 

Finally, we model a proposal from the LLM as follows: 

.. code-block:: lean 

  structure Proposal where
    userId : String
    resourceId : String
    slot : String
    deriving ToJson, FromJson, Repr, DecidableEq, Inhabited    

Here, we are making a simplification: a proposal in the sense above is just a proposal to call the ``reserve_resource`` 
tool. We're not considering any other tool call proposals at this time. Thus, the primary fields required are: 

1. ``userId`` -- the user who will reserve the resource
2. ``resourceId`` -- the resource to reserve 
3. ``slot`` -- the time slot of when to reserve the resource 

Thus, we might have a context like the following: 

.. code-block:: lean 

  def sampleContext : TrustedContext := {
    request := { userId := "jstubbs" }
    history := [
        .authorizationChecked "jstubbs" true,
        .resourceStatus "uv-1" "tuesday-10am" true
    ]
  }

This says that the user ``jstubbs`` is authenticated and there have been two tool calls previously. 

Specification 
^^^^^^^^^^^^^
Let us define what constitutes a valid proposal. Similar to the previous example, we roughly want a function that takes a 
proposal and returns a proposition that is the mathematical statement that the proposal is valid. But can we decide 
whether a proposal is valid in isolation? 

No, we also need the trusted context, because the validity of the proposal depends on the tool call history. Thus, our 
specification will have the type: 

.. code-block:: lean 

    def validProposal (ctx : TrustedContext) (p : Proposal) : Prop

What do we require for a proposal to be valid? We want to check the three rules above. Let's do them in order. 

The identity substitution rule simply states that the proposal's ``userId`` has to be the same as the ``userId`` 
in the trusted context. Since ``p`` is the proposal and ``ctx`` is the trusted context, this condition can 
be expressed mathematically as: 

.. code-block:: lean 

    p.userId = ctx.request.userId

What about rule 2? The rule states that the system must have made at least one authorization check for the proposed 
user. With the model we are using above, we can also check easily that the authorization check resulted in a success. 
Mathematically, we can represent this as: 

.. code-block:: lean 

  ToolCall.authorizationChecked p.userId true ∈ ctx.history

Note that we are passing ``p.userId`` and ``true`` as arguments to ``ToolCall.authorizationChecked``, and then 
we are requiring that to be an element of the ``ctx.history``. That is exactly the condition we want: tool call 
history should include an authorization check for the authenticated user, and it should have returned a result of ``true``. 

Lastly, we need to test for rule 3 which states that the tool call history should include a check that the resource 
is available for the specified slot. As with the implementation of rule 2, we simply need to pass data from the proposal 
into the tool call and check that it is in the ``history`` of the ``ctx``:

.. code-block:: lean 

    ToolCall.resourceStatus p.resourceId p.slot true ∈ ctx.history

We now have all the ingredients we need to build the specification. A proposal is valid if it adheres to all three 
rules simultaneously. Thus, we need to join the three mathematical statements with conjunction: 


.. code-block:: lean 

  def validProposal (ctx : TrustedContext) (p : Proposal) : Prop :=

    -- R1: No identity substitution
    p.userId = ctx.request.userId ∧

    -- R2: Successful authorization check exists
    ToolCall.authorizationChecked p.userId true ∈ ctx.history ∧

    -- R3: Successful availability check exists
    ToolCall.resourceStatus p.resourceId p.slot true ∈ ctx.history

A word on propositional conjunction (``∧``) and the boolean ``&&`` (and) operator: as a general rule, one should use 
the propositional conjunction (``∧``) when working with propositions like the one above. However, if you replace all of them 
with boolean and (``&&``), the code will still type check. That is because Lean is able to do some automatic coercion behind 
the scenes for you when the propositions are decidable.  

The Lean Checker 
^^^^^^^^^^^^^^^^
We have the types we need and we can now implement the executable Lean checker. Recall that we would like a function 
that accepts a JSON object and returns a ``bool`` type. But we'll also need access to the trusted context. This should 
be passed separately from the JSON object since the JSON represents the LLM response and the trusted context represents 
trusted application state. The signature for our ``verify`` function is thus: 

.. code-block:: lean 

    def verify (ctx : TrustedContext) (x : Json) : Bool

We can implement this function in two parts: one function that handles the JSON conversion and a second, more substantial 
function that deals with an actual proposal. Let's look at the latter first, since it is more interesting. The signature 
should be clear: 

.. code-block:: lean 

    def checkProposal (ctx : TrustedContext) (p : Proposal) : Bool

How shall we implement this function? We need to look at the proposal, ``p``, and check rules 1, 2 and 3. One option 
would be to implement a computable algorithm from scratch, using ``==``, ``&&``, searches through lists, etc., similar to how 
we approached the FornamlLitQA ``verify`` function. But instead, let't take a different approach. 

Computable Decision Values from ``Prop``: the ``decide`` tactic 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Lean allows us, in some cases, to compute boolean values directly from mathematical propositions using the 
``decide`` tactic. Indeed, if we look at the help for ``decide``, we see: 

.. code-block:: 

    Decidable.decide (p : Prop) [self : Decidable p] : Bool
    Converts a decidable proposition into a Bool.

    If p : Prop is decidable, then decide p : Bool is the Boolean value that is true if p is true and false if p is false.

We can see from the signature and the help text that ``decide`` take a ``p`` of type ``Prop`` which has ``Decidable`` 
and it returns a ``Bool``. For example, the following code: 

.. code-block:: lean 

  decide (p.userId = ctx.request.userId)    

converts the mathematical proposition ``p.userId = ctx.request.userId`` to a boolean value. 

Thus, we can implement ``checkProposal`` like so: 

.. code-block:: lean 

  def checkProposal (ctx : TrustedContext) (p : Proposal) : Bool :=

    -- Rule 1: No identity substitution
    decide (p.userId = ctx.request.userId) &&

    -- Rule 2: Successful authorization check exists
    decide (
        ToolCall.authorizationChecked p.userId true
        ∈ ctx.history
    ) &&

    -- Rule 3: Successful availability check exists
    decide (
        ToolCall.resourceStatus p.resourceId p.slot true
        ∈ ctx.history
    )

Notice the similarity with ``validProposal``. 

To complete the ``verify`` function, we only need to try and parse the JSON into a ``Proposal`` 
object and then invoke ``checkProposal``. The full implementation is as follows: 

.. code-block:: lean 

  def verify (ctx : TrustedContext) (x : Json) : Bool :=
    match (fromJson? x : Except String Proposal) with
    | .ok p    => checkProposal ctx p
    | .error _ => false


Verification 
^^^^^^^^^^^^
We're now ready to perform formal verification -- that is, state and prove a theorem that our checker (``verify``) 
adheres to our specification (``validProposal``). We can actually prove two theorems: a first stating that ``checkProposal``
is correct, and then a second stating that ``verify`` is correct. As before, we'll want a bidirectional implication
to ensure our checkers are both safe and correct in the sense of returning ``true`` for any valid proposal. 

For the theorem at the proposal level, the statement is remarkably simple because ``validProposal`` and ``checkPropsal`` 
have a very similar shape: 

.. code-block:: lean 

  theorem checkProposal_correct (ctx : TrustedContext) (p : Proposal) :
      checkProposal ctx p = true ↔ validProposal ctx p := by

The final theorem has a remarkably similar shape to our ``verifyIsCorrect`` theorem for FormalLitQA: 

.. code-block:: lean 

  theorem verifyIsCorrect (ctx : TrustedContext) (x : Json) :
    verify ctx x = true ↔ ∃ p : Proposal, fromJson? x = .ok p ∧ validProposal ctx p

In fact, the shape is identical with the exception of the insertion of the ``TrustedContext`` object and substituting 
``validProposal`` for ``validDefinition``. 

Extensions for FormalLitQA 
---------------------------
We have seen how to pull all the pieces together to implement an initial formally verified kernel for the FormalLitQA project, 
but there are many ways we can extend it. For one thing, our initial implementation only treated the definition claim type, and thus, 
we could implement additional rules for other claim types. 

But let's look at an even deeper issue. The chunks and their contents, including their types, were included in the LLM response. 
But should we rely on the LLM to accurately supply the information about a chunk? Absolutely not! 
For example, suppose that the LLM returns the following response: 

.. code-block:: json 

  {
    "claimId": 1,
    "claimType": "Definition",
    "evidence": [
        {"chunkId": 17, "chunkType": "Definition"}
    ]
  }

How do we know that the chunk with id ``17`` is really a definition chunk? How should we modify our approach to make the verification 
more robust? 

Lean Types 
^^^^^^^^^^

Recall that the manifest is the collection of all chunks and relations. The complete manifest can be implemented as a Python Pydantic 
type like so: 

.. code-block:: python 

    class Manifest(BaseModel):
        corpus_id: str
        generated_at_utc: str
        papers: list[Paper]
        chunks: list[Chunk]
        relations: list[Relation]

In Lean, we can implement a simplified version of the type: 

.. code-block:: lean 

  structure Manifest where
    chunks : List Chunk
    proves : List (Nat × Nat)  -- (result ID, proof ID)
    deriving ToJson, FromJson, Repr, Inhabited

Here, ``proves`` represents just one of the relation types, the relation between a ``ResultStatement`` chunk and a ``Proof`` 
chunk. Then, we can simplify the evidence structure within the ``Claim`` type to just include references to the manifest: 

.. code-block:: lean 

  structure Claim where
    claimId : Nat
    claimType : ClaimType
    evidence : List Nat        -- chunk IDs only
    deriving ToJson, FromJson, Repr, DecidableEq, Inhabited

To be clear, the ``Claim`` object no longer includes the chunk type associated with the chunks. The role of our verifier will 
be to first determine the type associated with a chunk, and then check that it has the right type for the asserted claim type. 

Specification 
^^^^^^^^^^^^^
Recall from the previous lecture that a good pattern is to define a Lean predicate that represents correct behavior, that is, 
a specification.

We can define what it means for a claim to cite a definition chunk from the manifest as follows:

.. code-block:: lean 

    def citesDefChunk
        (m : Manifest)
        (c : Claim) : Prop :=
      ∃ e ∈ m.chunks,
        e.chunkId ∈ c.evidence ∧
        e.chunkType = .Definition 

In natural language, the above says that a claim cites a definition chunk if there exists a chunk, ``e``, in the manifest, 
such that ``e`` has type ``Definition`` and ``e`` is among the claim's evidence. 

We can extend this predicate to handle different types of claims by parameterizing the chunk type that is required: 

.. code-block:: lean 

    def citesChunk
        (m : Manifest)
        (c : Claim)
        (kind : ChunkType) : Prop :=
      ∃ e ∈ m.chunks,
        e.chunkId ∈ c.evidence ∧
        e.chunkType = kind    

Here, ``kind`` is a parameter specifying the type of chunk that is required. The definition is identical to the previous one, 
just replacing the hard-coded ``.Definition`` with the parameter ``kind``. 

However, in order to get this definition to work for our intended purpose, we need one more technical modification. We need 
to replace the ``def`` with an ``abbrev``. Without going into the details, ``abbrev`` is very similar to ``def`` but it allows 
Lean to use them in its automated type class instance searches. So let's update ``citeChunk`` to be an ``abbrev``: 

.. In Lean, ordinary def declarations are generally semireducible. Lean can unfold them in many 
.. contexts, but typeclass synthesis deliberately avoids unfolding them during its search for instances.
.. An abbrev, on the other hand, is reducible, meaning typeclass synthesis can unfold its definition.

.. code-block:: lean 

    abbrev citesChunk
        (m : Manifest)
        (c : Claim)
        (kind : ChunkType) : Prop :=
      ∃ e ∈ m.chunks,
        e.chunkId ∈ c.evidence ∧
        e.chunkType = kind    


We can now define what it means for a claim of different types to be valid: 

.. code-block:: lean 

  def validClaim (m : Manifest) (c : Claim) : Prop :=
    match c.claimType with
    | .Definition =>
        citesChunk m c .Definition

    | .ResultStatement =>
        citesChunk m c .ResultStatement

    | .ProvedResult =>
        ∃ r ∈ m.chunks,
        ∃ p ∈ m.chunks,
            r.chunkType = .ResultStatement ∧
            p.chunkType = .Proof ∧
            r.chunkId ∈ c.evidence ∧
            p.chunkId ∈ c.evidence ∧
            (r.chunkId, p.chunkId) ∈ m.proves

  | _ => False    

This is our specification. 
As usual, we use ``match`` to handle the different cases. For ``Definition`` and ``ResultStatement`` claims, the ruls is 
essentially the same -- we simply use ``citesChunk`` to check that the manifest contains a chunk of that type with the same 
chunk id. 

But the ``ProvedResult`` type requires more. Not only do we require both a ``ResultStatment`` and a ``Proof`` chunk in the 
manifest whose id's are among those in the claim's evidence, but we also require that the ``Proof`` chunk is related to the 
``ResultStatement`` chunk through a ``proves`` relation. 

The Lean Checker 
^^^^^^^^^^^^^^^^
As in the earlier case, we need a computable function that takes a JSON object and returns a ``Bool``. In this expanded 
case, we will also require a ``Manifest`` input. The signature of our Lean checker will thus look like so: 

.. code-block:: lean 

    def verify (m : Manifest) (x : Json) : Bool

But first, I will implement a verifier function at the level of a claim. This will deviate slightly from the previous 
implementation, but it will allow us to separate the core policy of whether a claim is valid from the data exchange parsing.

Thus, the heart of our ``verify`` function will be the following: 

.. code-block:: lean 

  def verifyClaim (m : Manifest) (c : Claim) : Bool :=
    match c.claimType with

    | .Definition =>
        decide (citesChunk m c .Definition)

    | .ResultStatement =>
        decide (citesChunk m c .ResultStatement)

    | .ProvedResult =>
        decide (
            ∃ r ∈ m.chunks,
            ∃ p ∈ m.chunks,
            r.chunkType = .ResultStatement ∧
            p.chunkType = .Proof ∧
            r.chunkId ∈ c.evidence ∧
            p.chunkId ∈ c.evidence ∧
            (r.chunkId, p.chunkId) ∈ m.proves
        )

  | _ => false

What's going on here? It seems that we are using part of our specification (namely, the ``citesChunk``) within our 
computable function! Isn't that a problem? No, and in fact it is one of the powerful aspects of Lean: 
a logical specification can sometimes serve directly as the basis for an executable decision procedure. This is 
what is sometimes called *correct by construction*. 

How is it working? Remember that ``decide`` is a program which converts a "decidable proposition" into a boolean, that is, 
something that can be computed. Lean's ``Decidable`` mechanism can convert 

How do we deal with JSON? With ``verifyClaim`` in place, our ``verify`` function becomes a thin wrapper that simply 
has to handle parsing the JSON. This is nearly identical to the implementation of ``verify`` we implemented for 
the Lab Agent system. 

.. code-block:: lean 

  def verify (m : Manifest) (x : Json) : Bool :=
    match (fromJson? x : Except String Claim) with
    | .ok c => verifyClaim m c
    | .error _ => false


Verification 
^^^^^^^^^^^^^^

As we did in the Lab Agent example, we can proceed by giving two theorems. The first works at the ``Claim`` 
level and it very similar to ``checkProposal_correct``: 

.. code-block:: lean 

  theorem verifyClaim_correct (m : Manifest) (c : Claim) :
      verifyClaim m c = true ↔ validClaim m c

while the second one works at the level of JSON: 

.. code-block:: lean 

  theorem verifyIsCorrect (m : Manifest) (x : Json) :
    verify m x = true ↔ ∃ c : Claim, fromJson? x = .ok c ∧ validClaim m c


We can also look at some examples. 
Suppose we have the following simple manifest: 

.. code-block:: lean 

  def sampleManifest : Manifest := {
    chunks := [
        { chunkId := 17, chunkType := .ResultStatement },
        { chunkId := 92, chunkType := .Proof },
        { chunkId := 105, chunkType := .Discussion }
    ]
    proves := [(17, 92)]
  }

Consider the following claims: 

.. code-block:: lean

  def goodClaim : Claim := {
    claimId := 1
    claimType := .ProvedResult
    evidence := [17, 92]
  }

  def badClaim : Claim := {
    claimId := 2
    claimType := .ProvedResult
    evidence := [17, 105]
  }


Convince yourself of the correctness of the following: 

.. code-block:: lean 

  #eval verify sampleManifest (toJson goodClaim)  -- true
  #eval verify sampleManifest (toJson badClaim)   -- false

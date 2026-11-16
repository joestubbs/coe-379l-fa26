Verified Tool Calling in Agentic Architectures 
==============================================

In this lecture, we continue the techniques and examples from the introduction to Neurosymbolic Architecture 
and look at some implementation details related to tool calling in agentic systems. We will see how to apply the 
verified checker patten to authorization policies for verifying tool calls in the Lab Agent Software system. Then, 
we will expand on some of general-purpose infrastructure needed to integrate Python and Lean into a single system. 

By the end of this lecture, students should be able to: 


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
and our Python code will invoke it using 

Verification in the Lab Agent: An Initial Implementation 
--------------------------------------------------------

To begin, we'll consider a simplified implementation of the Lab Agent software where the system includes just 
two tools: 

Lean Types 
^^^^^^^^^^

The Lean Checker 
^^^^^^^^^^^^^^^^


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

Recall from the previous lecture that a good pattern is to define a Lean predicate that represents correct behavior, that is, 
a specification of 

We can define what it means for a claim to cite a definition chunk from the mainifest as follows:

.. code-block:: lean 

    def citesDefChunk
        (m : Manifest)
        (c : Claim) : Prop :=
      ∃ e ∈ m.chunks,
        e.chunkId ∈ c.evidence ∧
        e.chunkType = .Definition 

Or, we can extend this predicate to handle different types of claims by parameterizing the chunk type that is required: 

.. code-block:: lean 

    def citesChunk
        (m : Manifest)
        (c : Claim)
        (kind : ChunkType) : Prop :=
      ∃ e ∈ m.chunks,
        e.chunkId ∈ c.evidence ∧
        e.chunkType = kind    

So, for example, suppose we have the following simple manifest: 

.. code-block:: lean 

  def sampleManifest : Manifest := {
    chunks := [
        { chunkId := 17, chunkType := .ResultStatement },
        { chunkId := 92, chunkType := .Proof },
        { chunkId := 105, chunkType := .Discussion }
    ]
    proves := [(17, 92)]
  }

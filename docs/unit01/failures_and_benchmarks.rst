Failure Modes and Benchmarks for RAG Systems
=============================================

In the previous modules, we developed the basic components of a retrieval-augmented generation system: 
from source extraction, to retrieval and prompt construction. In this module, we focus on how we 
assess the quality and robustness of the system. 

There are many ways that the system might generate an incorrect answer for a given input, so evaluating 
only the final answer does not tell us much about where the system failed. Similarly, the system could 
have stumbled upon a correct answer without providing the appropriate evidence. Finally, due to the 
nature of generative AI models, correct behavior on a given question does not imply the system 
will behave correctly on additional questions, even questions that very similar. 

We therefore need to catalog the various types of failures that can occur and develop a set of 
evaluation cases with expected properties and metrics that isolate different stages of the system 
and test for different failure scenarios. 

By the end of this module, students should be able to:

* distinguish extraction, retrieval, generation, citation, and abstention failures
* explain why a plausible or even factually correct answer can still be unsupported
* describe the components of a reproducible benchmark case
* calculate ``Hit@k`` and ``Recall@k`` for retrieval results
* distinguish citation validity from claim support
* measure appropriate and inappropriate abstention behavior
* explain why requests involving live state or side effects require tools rather than retrieval alone


A RAG Failure at Multiple Levels 
--------------------------------

Consider the following question about the fictional polymer report used in the previous modules:

    *At baseline, did grade P-B pass the tensile-strength component of the defect rule?*

The corpus contains all the evidence needed to answer the question, but it requires combining 
information from two chunks. ``POLY-17#strength`` describes the ``P-B``'s tensile strength: 

.. code-block:: json

    {
      "chunk_id": "POLY-17#strength",
      "text": "At baseline, grade P-B had a mean tensile strength of 43.2 MPa."
    }

while ``POLY-17#defect-rule`` describes the tensile strength threshold for a specimen to be defective: 

.. code-block:: json

    {
      "chunk_id": "POLY-17#defect-rule",
      "text": "A specimen was labeled defective if its tensile strength was below 35 MPa or if inspection found visible voids."
    }

Now, suppose the system produces the following structured response to the question:

.. code-block:: json

    {
      "question": "At baseline, did grade P-B pass the tensile-strength component of the defect rule?",
      "retrieved_chunk_ids": [
        "POLY-17#strength",
        "POLY-17#conditioning"
      ],
      "response": {
        "answer": "Yes. P-B passed because its strength of 43.2 MPa exceeded the 40 MPa defect threshold.",
        "citations": ["POLY-17#strength"]
      }
    }

This structured response clearly labels the original question, the chunks that were fetched during retrieval, 
and the answer, together with the chunks that were cited. Moreover, answer sounds plausible, the cited chunk is indeed a chunk that 
was retrieved, and it is a valid chunk from the corpus. Nevertheless, the response is not acceptable.

What problems can you identify in the response? 

Diagnosis
^^^^^^^^^

From the structured response we can identify several different failures:

* The retriever failed to return ``POLY-17#defect-rule``, even though that record was in the index.
* The generator invented a threshold of 40 MPa. No retrieved passage contains that value.
* The chunk that was retrieved and cited (``POLY-17#strength``) supports the measured strength of 43.2 MPa, 
  but it does not support the claimed threshold or the comparison with that threshold.
* Based on the retrieved evidence alone, the model should not have concluded that P-B passed. It should
  have indicated that the criterion needed to make the comparison was missing.

The final yes/no conclusion happens to agree with the complete corpus: 43.2 MPa is above the actual
35 MPa threshold. however, the system arrived at the conclusion using an invented premise.

This distinction is central to responsible evaluation:

    *A factually correct answer is not necessarily properly supported by the cited evidence, and 
    a valid-looking citation does not necessarily provide supporting evidence for an answer.*

Failure Is Stage-Specific
-------------------------

As we know from the previous lectures, a RAG response is the result of several transformations across both the 
ingestion and retrieval subsystems:

.. math::

    \text{source}
    \rightarrow
    \text{extracted record}
    \rightarrow
    \text{retrieved evidence}
    \rightarrow
    \text{prompt context}

.. math:: 

    \rightarrow
    \text{generated response}
    \rightarrow
    \text{validated output}

A failure observed in the final answer may have originated at any earlier stage. To diagnosis a given failure, 
we therefore must inspect the various intermediate artifacts at each stage.

.. list-table::
   :header-rows: 1
   :widths: 18 36

   * - Stage
     - Intended property of behavior 
   * - Extraction
     - Relevant source content and provenance remain in tact.
   * - Retrieval
     - Evidence needed for the question appears sufficiently high in the ranked results.
   * - Context construction
     - Eligible evidence is placed in the prompt without losing identifiers or important qualifiers.
   * - Generation
     - Every substantive claim follows from the supplied evidence.
   * - Citation
     - Each citation resolves to retrieved evidence that supports the associated claim.
   * - Abstention
     - The system answers when evidence is sufficient and declines when it is insufficient.

Let us look at some examples of failures at each stage. 


.. Example failures at different stages: 

.. * Extraction --- a theorem is omitted, an equation is corrupted, columns are read in the wrong order, or the
..   source offsets point to the wrong passage.

.. * Retrieval --- The relevant chunk is absent from the top results, an obsolete version is selected, or required
..   related chunks are not expanded.

.. * Context Construction --- A retrieved chunk is truncated, deduplicated incorrectly, excluded by the token budget, or
..   presented without its source identifier.

.. * Generation --- The model invents a value, reverses a comparison, combines unrelated passages, or omits a
..   requested part of the answer.

.. * Citation --- A citation does not exist, was not retrieved, or exists but does not support the claim.

.. * Abstention --- It answers without necessary evidence or refuses a question that the corpus can answer. 

Extraction Failures
^^^^^^^^^^^^^^^^^^^

During extraction, raw source documents are parsed into structure knowledge base with the goal of retraining 
the meaningful structure from the original documents. Common examples of failures include:

* missing sections, tables, equations, or figure captions
* incorrect reading order in a multi-column PDF
* LaTeX commands removed in a way that changes mathematical meaning
* a proof separated from its theorem without preserving the relationship
* duplicate records created from headers and footers
* loss of the paper ID, version, source path, or offsets needed for provenance

If the relevant passage never enters the knowledge base, no retrieval algorithm can recover it.
Extraction must therefore be evaluated separately, for example, by comparing source documents against the
records produced by the pipeline.

Retrieval Failures
^^^^^^^^^^^^^^^^^^

A retrieval failure occurs when the required evidence to answer a question exists in the knowledge base, 
but is not made available to the LLM. There are several common types of retrieval failure that are worth 
defining: 

* *retrieval miss* --- no relevant record appears in the first :math:`k` results, where :math:`k` is the 
  number of results retrieved. 
* *partial retrieval* --- some, but not all, necessary records are returned
* *ranking failure* --- the relevant record is returned, but it is ranked too low to fit in the context budget
* *filtering failure* --- an invalid version or document type is included in the retrieval --- for example, if a question 
  asks about peer-reviewed publications and non-peer-reviewed results are returned --- or, similarly, an eligible one is
  excluded
* *relation failure* --- an initially retrieved record is present, but a related object that would be required 
  to answer the questions is missing. For example, a theorem statement is returned but supporting definitions, proofs,
  equations, etc., are not. 

Generation Failures
^^^^^^^^^^^^^^^^^^^

Generation failures occur even when adequate evidence is present in the prompt. Examples include:

* making a claim that contradicts the evidence contained within the returned chunks
* adding an unsupported detail to an otherwise correct answer
* incorrectly combining or synthesizing information across multiple chunks
* omitting a requested claim despite available evidence.

As you can see, hallucination is just one possible type of generation failure. Omissions, 
correct but uncited claims, may also make the response unsuitable.

Citation Failures
^^^^^^^^^^^^^^^^^

There are several requirements involving citations to be used in a final answer. 
The list below provides these requirements in order of increasing strength:

1. The cited identifier has the correct syntax.
2. The identifier exists in the corpus.
3. The record was retrieved during this run.
4. The cited record is attached to the correct claim.
5. The record actually supports that claim.

The first three properties can usually be checked deterministically, while the fourth and fifth 
usually require parsing the semantic meaning associated with a claim and a record. 
This usually not decidable in general. 

Abstention Failures
^^^^^^^^^^^^^^^^^^^

An *appropriate abstention* reports that the available evidence is insufficient. Two opposing failure
modes are important:

* *failure to abstain* --- the system answers even though the required evidence is unavailable
* *unnecessary abstention* --- the system abstains even though sufficient evidence is available

A system that abstains on every request avoids unsupported claims but of course is not useful. 
A benchmark must therefore contain both answerable and unanswerable cases.

Benchmarks
----------

A *benchmark* is a defined collection of evaluation cases, expected properties, and metrics. For RAG,
a case needs the a question and answer, but it also needs enough information to evaluate the individual 
components in isolation. 

An individual case within a benchmark should have the following:

* a unique identifier for the case 
* the question
* the obligations contained within the question that a complete answer must address
* the exact corpus version against which the question should be evaluated
* whether the corpus contains sufficient evidence
* the chunks judged to be relevant to the question and thus should be retrieved during retrieval
* the facts that should be distilled from the evidence chunks to address the question  
* any prohibited or contradictory conclusions that should be penalized in an answer 
* tags that label the capability or failure mode under test

As usual, we'll use Pydantic to model a benchmark case as a structured object with well-defined types. 
The following Pydantic model captures some of the information above:

.. code-block:: python

    from typing import Literal

    from pydantic import BaseModel, Field

    class BenchmarkCase(BaseModel):
        case_id: str
        question: str
        corpus_snapshot: str
        expected_mode: Literal["answer", "abstain"]
        relevant_chunk_ids: set[str] = Field(default_factory=set)
        required_facts: list[str] = Field(default_factory=list)
        tags: set[str] = Field(default_factory=set)

An example case is:

.. code-block:: python

    defect_case = BenchmarkCase(
        case_id="POLY-PUBLIC-002",
        question=(
            "What evidence establishes that grade P-B passed the "
            "tensile-strength component of the defect rule?"
        ),
        corpus_snapshot="polymer-report-v1",
        expected_mode="answer",
        relevant_chunk_ids={
            "POLY-17#strength",
            "POLY-17#defect-rule",
        },
        required_facts=[
            "P-B had a mean tensile strength of 43.2 MPa.",
            "Specimens below 35 MPa were labeled defective.",
            "43.2 MPa is above the stated defect threshold.",
        ],
        tags={"multiple_evidence_records", "numeric_comparison"},
    )

Ground Truth and Expected Properties
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The phrase *ground truth* should be used carefully for open-ended question-answer cases. There may be several
acceptable wordings and several evidence sets that support an answer. A single reference response is
therefore not a complete specification of correct behavior.

Whenever possible, specify properties or invariants of *all* correct answers. For instance: 

* which facts must appear
* which evidence may support each fact
* which conclusions are contradicted by the corpus
* whether answering or abstaining is expected
* which output fields and citations must be internally consistent

Some questions permit alternative evidence sets. For example, when asking about a theoretical area of mathematics, 
a result statement may directly answer the question while a proof and its conclusion may provide a less direct but 
still acceptable alternative answer. The descriptions of benchmark cases 
should ideally include such alternatives rather than pretending there is only one relevant chunk or 
possible acceptable answer.

Reproducibility Requires a Fixed Configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A benchmark result is meaningful only in relation to a specified, fixed experimental configuration. 
At a minimum, a benchmark evaluation experiment should record the versions and configurations of the 
major components and subsystems under test. For example: 

* corpus and manifest version
* parser and chunking version
* retrieval method and parameters (including configuration values, like :math:`k`)
* embedding and reranking models, if used
* language model and inference parameters
* prompt version
* validation and scoring version

Changing any of the above values, like the corpus version or the ``top_k`` value changes the experiment. Care must 
be taken when comparing results from different configurations, especially if the experiments differ in multiple 
dimensions. 

Metrics Are Property-Specific
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

No single number completely describes the performance of a RAG system, especially under an open-ended task such as 
question-answer. We use different metrics for evaluating different properties or components of the system:

.. list-table::
   :header-rows: 1
   :widths: 26 34 40

   * - Property
     - Example metric
     - Question answered by the metric
   * - Retrieval coverage
     - ``Hit@k``, ``Recall@k``
     - Did the generator receive the required evidence?
   * - Claim support
     - Supported-claim rate
     - Did the supplied evidence support the generated claims?
   * - Citation validity
     - Valid-citation rate
     - Did citations resolve to records retrieved during the run?
   * - Answerability decision
     - Abstention accuracy and error rates
     - Did the system answer and abstain in the appropriate cases?
   * - Completeness
     - Required-fact coverage
     - Did the answer address every required part of the question?

Retrieval Metrics: Hit@k and Recall@k
-------------------------------------

Let :math:`G_q` be the set of relevant chunk IDs for question :math:`q` (sometimes called the "gold chunks"), 
and let :math:`R_k(q)` be the first :math:`k` retrieved chunk IDs.

The ``Hit@k`` metric is defined to be 1 when at least one relevant record appears in the first :math:`k` results and 
0 otherwise:

.. math::

    \operatorname{Hit@k}(q)
    =
    \begin{cases}
      1 & \text{if } G_q \cap R_k(q) \neq \varnothing \\
      0 & \text{otherwise.}
    \end{cases}

The ``Recall@k`` metric measures the fraction of relevant records found:

.. math::

    \operatorname{Recall@k}(q)
    =
    \frac{|G_q \cap R_k(q)|}{|G_q|}

Note that ``Recall@k`` and ``Hit@k`` coincide when a case has only one relevant record. 
They differ when an answer requires multiple records. For example, if the system returns one of 
two relevant chunks, its hit is 1 but its recall is 0.5. 

Small Retrieval Benchmark
^^^^^^^^^^^^^^^^^^^^^^^^^

We'll use the following example retrieval results to demonstrate the metrics above. 

.. code-block:: python

    RETRIEVAL_CASES = [
        BenchmarkCase(
            case_id="POLY-PUBLIC-001",
            question="How were specimens prepared before tensile testing?",
            corpus_snapshot="polymer-report-v1",
            expected_mode="answer",
            relevant_chunk_ids={"POLY-17#conditioning"},
            required_facts=[
                "Specimens were conditioned at 23 degrees Celsius, "
                "50 percent relative humidity, for 48 hours."
            ],
            tags={"single_evidence_record"},
        ),
        BenchmarkCase(
            case_id="POLY-PUBLIC-002",
            question=(
                "What evidence establishes that grade P-B passed the "
                "tensile-strength component of the defect rule?"
            ),
            corpus_snapshot="polymer-report-v1",
            expected_mode="answer",
            relevant_chunk_ids={
                "POLY-17#strength",
                "POLY-17#defect-rule",
            },
            required_facts=[
                "P-B had a mean tensile strength of 43.2 MPa.",
                "Specimens below 35 MPa were labeled defective.",
            ],
            tags={"multiple_evidence_records"},
        ),
        BenchmarkCase(
            case_id="POLY-PUBLIC-003",
            question=(
                "Have researchers tested how outdoor sunlight changes "
                "the material over time?"
            ),
            corpus_snapshot="polymer-report-v1",
            expected_mode="answer",
            relevant_chunk_ids={"POLY-17#limitations"},
            required_facts=[
                "The study did not perform ultraviolet-aging experiments."
            ],
            tags={"paraphrase", "negative_evidence"},
        ),
    ]

    SAVED_RETRIEVAL_RESULTS = {
        "POLY-PUBLIC-001": [
            "POLY-17#conditioning",
            "POLY-17#strength",
            "POLY-17#materials",
        ],
        "POLY-PUBLIC-002": [
            "POLY-17#strength",
            "POLY-17#conclusion",
            "POLY-17#materials",
        ],
        "POLY-PUBLIC-003": [],
    }

Before executing the next cell, calculate ``Hit@3`` and ``Recall@3`` for each case by hand.

.. code-block:: python

    from statistics import mean

    def hit_at_k(
        retrieved_ids: list[str],
        relevant_ids: set[str],
        k: int,
    ) -> float:
        top_k = set(retrieved_ids[:k])
        return float(bool(top_k & relevant_ids))

    def recall_at_k(
        retrieved_ids: list[str],
        relevant_ids: set[str],
        k: int,
    ) -> float:
        if not relevant_ids:
            raise ValueError("Recall@k is undefined without relevant records.")

        top_k = set(retrieved_ids[:k])
        return len(top_k & relevant_ids) / len(relevant_ids)

    per_case_metrics = []

    for case in RETRIEVAL_CASES:
        retrieved = SAVED_RETRIEVAL_RESULTS[case.case_id]
        hit = hit_at_k(retrieved, case.relevant_chunk_ids, k=3)
        recall = recall_at_k(retrieved, case.relevant_chunk_ids, k=3)
        per_case_metrics.append((case.case_id, hit, recall))
        print(case.case_id, "hit@3=", hit, "recall@3=", recall)

    print(
        "mean hit@3=",
        mean(item[1] for item in per_case_metrics),
    )
    print(
        "mean recall@3=",
        mean(item[2] for item in per_case_metrics),
    )

You should see results like the following: 

.. list-table::
   :header-rows: 1
   :widths: 36 20 20 24

   * - Case
     - ``Hit@3``
     - ``Recall@3``
     - Interpretation
   * - ``POLY-PUBLIC-001``
     - 1
     - 1.0
     - The required conditioning passage was retrieved.
   * - ``POLY-PUBLIC-002``
     - 1
     - 0.5
     - The strength was retrieved, but the defect rule was missing.
   * - ``POLY-PUBLIC-003``
     - 0
     - 0.0
     - Vocabulary mismatch caused a complete retrieval miss.

The mean ``Hit@3`` is approximately 0.67, while mean ``Recall@3`` is 0.50. Hit rate alone hides the
partial failure in the second case.

Interpreting k
^^^^^^^^^^^^^^

Increasing :math:`k` often increases retrieval recall, but it usually comes with a cost:

* more passages consume more context-window space
* irrelevant passages can distract the LLM
* redundant chunks can crowd out the important evidence
* reranking and generation become more expensive (more iterations and more tokens to process)

Keep in mind that the ultimate goal is not to maximize :math:`k`. Rather, it is to provide a high-quality 
answers to questions, and to that end, the retrieve must retrieve sufficient, 
relevant evidence within the system's latency and context window budget.

Evidence, Citation Validity, and Abstention
-------------------------------------------

Retrieval metrics answer whether evidence was made available. The next step is to establish the extent to which 
the generated responses use the evidence correctly.

Three answer-level properties address this, and each should be evaluated separately:

* *claim support* --- whether the cited evidence entails or justifies the claim
* *citation validity* --- whether the citation resolves to an existing record that was retrieved during
  this run
* *answerability decision* --- whether the system answered or abstained appropriately

Citation validity can be checked in a straight-forward way: 

.. code-block:: python

    def invalid_citations(
        cited_ids: set[str],
        retrieved_ids: set[str],
    ) -> set[str]:
        return cited_ids - retrieved_ids

This check simply says that any citations that were not retrieved by the retriever are invalid. 

Claim Support Usually Requires Determining Semantic Meaning 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Recall the ``POLY-17#strength`` chunk which described ``P-B``'s tensile strength:

.. code-block:: json

    {
      "chunk_id": "POLY-17#strength",
      "text": "At baseline, grade P-B had a mean tensile strength of 43.2 MPa."
    }


Consider the following example claims made using the ``POLY-17#strength`` chunk as the citation. 
If this chunk was retrieved, then it is a valid citation in all cases, but in which cases does it 
actually support the claim? How do you know? 

.. list-table::
   :header-rows: 1
   :widths: 62 18 20

   * - Claim
     - Citation valid?
     - Claim supported?
   * - P-B had a baseline mean tensile strength of 43.2 MPa.
     - Yes
     - Yes
   * - The defect threshold was 40 MPa.
     - Yes
     - No
   * - P-B passed the defect rule.
     - Yes
     - Not by this passage alone

Only the first claim is fully supported by ``POLY-17#strength`` -- it doesn't say anything about the 
defect threshold, and thus, it can't be used by itself to claim that ``P-B`` passed. 

But note that it would be difficult to determine these programmatically, as that would require parsing the 
semantic meaning of the natural language. 

In practice, humans often annotate the the benchmark cases with the claims that are supported by the evidence. 
In some cases, a task-specific rule can be used. More recently, the use of LLM's to 
evaluate whether the evidence supports the claims. However, care must be taken here, because the LLM used to
judge can also make mistakes. 


Evaluating Abstention
^^^^^^^^^^^^^^^^^^^^^

When evaluating abstention, there are essentially two cases --- either the system contains the necessary evidence 
to answer the question or it doesn't. 

Thus, we can evaluate abstention using something resembling a confusion matrix: 

.. list-table::
   :header-rows: 1
   :widths: 28 36 36

   * - Expected behavior
     - System answers
     - System abstains
   * - Sufficient evidence 
     - Correct decision; evaluate answer quality next
     - Unnecessary abstention
   * - Insufficient evidence
     - Failure to abstain
     - Appropriate abstention

Note that the decision can be correct even when the answer itself is wrong, even completely wrong. 
Conversely, an answer can be factually correct by chance despite a failure to retrieve sufficient evidence. 

A Small Judged Result Set
^^^^^^^^^^^^^^^^^^^^^^^^^

We'll add two additional cases to the previous ``RETRIEVAL_CASES`` above: 


.. code-block:: python3

    PUBLIC_CASES = {
        case.case_id: case
        for case in [
            *RETRIEVAL_CASES,
            BenchmarkCase(
                case_id="POLY-PUBLIC-004",
                question="Who was the lead author of the polymer study?",
                corpus_snapshot="polymer-report-v1",
                expected_mode="abstain",
                relevant_chunk_ids=set(),
                required_facts=[],
                tags={"insufficient_evidence", "abstention"},
            ),
            BenchmarkCase(
                case_id="POLY-PUBLIC-005",
                question=(
                    "What was grade P-B's baseline mean tensile strength?"
                ),
                corpus_snapshot="polymer-report-v1",
                expected_mode="answer",
                relevant_chunk_ids={"POLY-17#strength"},
                required_facts=[
                    "Grade P-B had a baseline mean tensile strength of 43.2 MPa."
                ],
                tags={
                    "single_evidence_record",
                    "unnecessary_abstention",
                },
            ),
        ]
    }


The following records represent evaluations made after inspecting each response and its retrieved evidence:

* ``POLY-PUBLIC-001`` is completely supported by a single chunk, which was retrieved. 
* ``POLY-PUBLIC-002`` is completely supported by two chunks, but only one was retrieved. 
* ``POLY-PUBLIC-004`` asks for the lead author, which is absent from the corpus
* ``POLY-PUBLIC-005`` asks for P-B's baseline strength, which is directly available. The former should
  produce an abstention; the latter should not.

.. code-block:: python

    class JudgedResponse(BaseModel):
        case_id: str
        expected_mode: Literal["answer", "abstain"]
        actual_mode: Literal["answer", "abstain"]
        claim_support: list[bool] = Field(default_factory=list)
        citation_validity: list[bool] = Field(default_factory=list)

    JUDGED_RESULTS = [
        JudgedResponse(
            case_id="POLY-PUBLIC-001",
            expected_mode="answer",
            actual_mode="answer",
            claim_support=[True],
            citation_validity=[True],
        ),
        JudgedResponse(
            case_id="POLY-PUBLIC-002",
            expected_mode="answer",
            actual_mode="answer",
            # The measured strength is supported, but the invented threshold is not.
            claim_support=[True, False],
            citation_validity=[True],
        ),
        JudgedResponse(
            case_id="POLY-PUBLIC-003",
            expected_mode="answer",
            actual_mode="abstain",
            # The retriever returned no evidence, so no claims or citations
            # were produced.
            claim_support=[],
            citation_validity=[],
        ),
        JudgedResponse(
            case_id="POLY-PUBLIC-004",
            expected_mode="abstain",
            actual_mode="abstain",
            claim_support=[],
            citation_validity=[],
        ),
        JudgedResponse(
            case_id="POLY-PUBLIC-005",
            expected_mode="answer",
            actual_mode="abstain",
            claim_support=[],
            citation_validity=[],
        ),
    ]

We can aggregate the labels while retaining separate metrics:

.. code-block:: python

    def fraction_true(values: list[bool]) -> float | None:
        if not values:
            return None
        return sum(values) / len(values)

    all_claim_labels = [
        label
        for result in JUDGED_RESULTS
        for label in result.claim_support
    ]
    all_citation_labels = [
        label
        for result in JUDGED_RESULTS
        for label in result.citation_validity
    ]
    answerability_decisions = [
        result.expected_mode == result.actual_mode
        for result in JUDGED_RESULTS
    ]

    print("supported-claim rate:", fraction_true(all_claim_labels))
    print("valid-citation rate:", fraction_true(all_citation_labels))
    print(
        "answerability-decision accuracy:",
        fraction_true(answerability_decisions),
    )

For these example judgments, the valid-citation rate is 1.0, the
supported-claim rate is approximately 0.67, and answerability-decision
accuracy is 0.60. Reporting only citation validity would conceal both the
unsupported threshold claim and the two unnecessary abstentions.

Formal-Lit-QA Public Cases and Initial Results
----------------------------------------------

Formal-Lit-QA is a system whose goal is to answer questions from a specified theoretical research-literature corpus, 
report the supporting passages, and abstain when that corpus does not provide sufficient evidence. The system leverages 
RAG over a corpus of articles from the arXiv whose package includes a LaTeX project. Because LaTeX is structured, 
the RAG ingestion system is capable of parsing chunks of different types and identifying relationships between 
chunks. For example, we saw an example of a ``result_statement`` chunk in the Intro to RAG module:

.. code-block:: json

    {
      "chunk_id": "arxiv_2512_09280/result_statement_0001",
      "paper_id": "arxiv_2512_09280",
      "chunk_type": "result_statement",
      "raw_content": "\\begin{theorem}[Newman's Lemma]\nTermination and local confluence imply confluence.\n\\end{theorem}",
      "normalized_text": "Termination and local confluence imply confluence.",
      "start_offset": 8677,
      "end_offset": 8773
    }


Any benchmark to evaluate Formal-Lit-QA's performance should include several qualitatively different goals.

.. list-table::
   :header-rows: 1
   :widths: 22 31 25 22

   * - Case type
     - Example question
     - Expected evidence
     - Principal failure tested
   * - Definition
     - How does the literature define local confluence?
     - Definition chunk from the target paper
     - Wrong evidence type or incomplete definition
   * - Result statement
     - State Newman's Lemma as given in the literature.
     - Result-statement chunk
     - Hallucinated conditions or wrong theorem
   * - Proof
     - What is the main argument used to prove the Newman's Lemma?
     - Proof chunk plus its relation to the result
     - Statement retrieved without proof evidence or vice versa 
   * - Multiple evidence records
     - Compare the assumptions of two related results...
     - Both result statements and all necessary definitions
     - Partial retrieval or incorrect synthesis
   * - Insufficient evidence
     - Does the corpus prove the converse of Newman's Lemma?
     - No adequate supporting result
     - Failure to abstain

For example, a concrete result-statement case can refer to the previous chunk record:

.. code-block:: python

    newman_case = BenchmarkCase(
        case_id="FLQ-PUBLIC-001",
        question="State Newman's Lemma as given in the literature.",
        corpus_snapshot="formal-lit-qa-pilot-v1",
        expected_mode="answer",
        relevant_chunk_ids={
            "arxiv_2512_09280/result_statement_0001"
        },
        required_facts=[
            "Termination and local confluence imply confluence."
        ],
        tags={"result_statement", "single_evidence_record"},
    )


Why Some Requests Require Actions and Tools
-------------------------------------------

RAG retrieves information from an existing knowledge source, which is useful for question-answer tasks. 
But some tasks require current external state or ask the system to change the world. Consider the following 
examples: 

.. list-table::
   :header-rows: 1
   :widths: 42 26 32

   * - Request
     - Needed capability
     - Is document retrieval alone is sufficient?
   * - What qualification is required to use the tensile tester?
     - Policy retrieval
     - Yes: the answer is contained in a relatively static policy corpus.
   * - Am I currently authorized to use the tensile tester?
     - Authorization lookup tool
     - No: the answer depends on private, changing user state and an authorization policy service
   * - Is the tensile tester available Friday afternoon?
     - Resource-status or scheduling tool
     - No: availability changes over time and must be queried from a scheduling service 
   * - Reserve the tensile tester for Friday afternoon.
     - Mutating reservation tool
     - No: the request requires modifying state, not merely an answer.

A language model can generate text claiming that a reservation was created, but it is not able to 
actually reserve the tool in the reservation system. Thus, our application will need to be able to 
make calls to the reservation system and create or modify existing reservations to make the LLM's 
statement true.

The next architecture we will consider will therefore extend the RAG component to include arbitrary 
tool calling: 

.. math::

    \text{request}
    \rightarrow
    \text{decision}
    \rightarrow
    \text{tool call}
    \rightarrow
    \text{observation}
    \rightarrow
    \text{updated state or final response}

This creates new failure modes: invalid tool arguments, unauthorized actions, tool errors, false claims
about side effects, and loops that fail to terminate. The same lesson from RAG still applies: evaluation
must inspect the execution trace, not only the final prose.

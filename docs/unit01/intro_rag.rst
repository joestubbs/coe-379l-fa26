Introduction to Retrieval Augmented Generation (RAG) and Structured Knowledge Pipelines
========================================================================================

In this module we introduce Retrieval Augmented Generation (RAG), a technique for providing a
foundation model with relevant external information at inference time. We will examine the complete
data flow, starting from source documents to the final returned answer, discuss why it is important 
for provenance to be maintained across the data flow, and build a small end-to-end retrieval system.
Finally, we will introduce Formal-Lit-QA, the
running example that we will develop and evaluate over the next several lectures.

By the end of this module, students should be able to:

* explain why retrieval is useful even when using a large foundation model
* distinguish retrieval from retrieval-augmented generation
* identify the ingestion-time and query-time stages of a RAG system
* explain the roles of chunks, metadata, relations, and provenance
* implement a small lexical retriever and inspect its results
* state the Formal-Lit-QA problem and its desired behavior

We will use the same OpenAI-compatible chat-completions endpoint introduced in the previous module and the reading.
The following helper accepts a complete list of messages so that later examples can insert retrieved
evidence into the prompt.

.. code-block:: python

    import os

    from openai import OpenAI

    BASE_URL = os.environ["TACC_LLM_BASE_URL"]
    TAPIS_JWT = os.environ["TAPIS_JWT"]
    MODEL = os.environ["TACC_LLM_MODEL"]

    client = OpenAI(
        base_url=BASE_URL,
        api_key=TAPIS_JWT,
    )

    def generate_text_rsp(
        messages: list[dict[str, str]],
        *,
        model: str = MODEL,
        temperature: float = 0.0,
        max_tokens: int = 300,
    ):
        completion = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        content = completion.choices[0].message.content
        if content is None:
            raise RuntimeError("The inference service returned no message content.")

        return content, completion

    def ask_model(question, *, temperature: float = 0.0) -> str:
        messages = [
            {
                "role": "user",
                "content": question,
            }
        ]
        answer, rsp= generate_text_rsp(
            messages,
            temperature=temperature,
            max_tokens=4000,
        )
        return answer, rsp.usage.total_tokens        


Motivation for Retrieval Augmented Generation 
---------------------------------------------

Recall from the previous module we established the following about foundation models: 

1. A foundation model generates output from its learned parameters and current context. 
2. Once training completes, the model's parameters are typically fixed and not updated. In 
   particular, sending an inference request does not result in the parameters getting 
   updated. 
3. Its parameters cannot be directly inspected like a database of facts.
4. The models responses are ultimately based on its training data and can be outdated, 
   unsupported by the available evidence, or flat out wrong. 


These observations lead to several problems related to reliability:

.. list-table::
   :header-rows: 1
   :widths: 28 36 36

   * - Situation
     - Why parameters are insufficient
     - Possible external source
   * - A recent election or publication
     - The event may postdate the training data.
     - A current, authoritative record
   * - Detailed API behavior
     - The model may have seen incomplete or obsolete documentation.
     - Versioned technical documentation
   * - A user's private resources
     - The information was never public training data.
     - An authenticated service or database
   * - A scientific claim
     - A plausible answers could be derived from data seen in training 
       but these could not be grounded in hard evidence.
     - A passage from the specified literature corpus

For example, a model cannot derive the current contents of a private account from its parameters:

.. code-block:: python

    ask_model("How many private Tapis systems can I currently access?")

An appropriate response is to say that the model lacks access. If our application is authorized to
query the relevant Tapis service, however, it could retrieve the current information and place it in
the model's context.

Similarly, models by themselves are not general-purpose applications: 

.. code-block:: python3 

   ask_model("What day is today?", model="Llama-4-Maverick-17B-128E-Instruct")

   --> "I'm not able to tell you what day it is today because I don't have access to a 
   calendar or clock and I'm not able to look up the current date. However, I can 
   guide you on how you might be able to find out. You can check your phone, computer, 
   or a wall calendar to see the current date."



Retrieval and RAG
^^^^^^^^^^^^^^^^^

*Retrieval* is the process of selecting relevant records from an external collection. A search engine
can perform retrieval without using a language model.

*Retrieval-augmented generation* combines retrieval with generation from an LLM. The application retrieves
evidence for a particular user query, constructs a prompt containing that evidence, and asks a model
to generate a response from it.

Retrieval can complement a model with:

* information absent from its training data
* information that changes over time
* private or domain-specific information
* evidence that a user can inspect

RAG is an inference-time technique. It does not ordinarily modify the model's parameters, and it is
not a substitute for training or fine-tuning. It also does not guarantee correctness: the retriever
may select poor evidence, and the generator may ignore or misinterpret good evidence.



The Basic RAG Pipeline 
----------------------

A RAG system normally contains two subsystems that execute independently from each other 
but are designed to be integrated. We'll refer to these two subsystems as 
*ingestion* and *retrieval*. 

Ingestion 
^^^^^^^^^
During ingestion, source documents of various kinds are processed into a structured knowledge database
or corpus. 

The high-level data flow in the Ingestion system could be depicted as follows: 

.. math:: 

    \text{documents}
    \rightarrow
    \text{extraction}
    \rightarrow
    \text{normalization and chunking}
    \rightarrow
    \text{recrods}
    \rightarrow
    \text{search index}

The resulting *index* is a data structure that supports efficient search. Depending on the retrieval
method, an index might store different kinds of data structures, including: 

* token statistics
* dense vectors 
* text/document snippets and associated metadata 

It could also store a combination of several of these. 

Query-time Retrieval 
^^^^^^^^^^^^^^^^^^^^

When a user asks a question, the application uses the previously constructed index:


.. math:: 

    \text{question}
    \rightarrow
    \text{retrieval}
    \rightarrow
    \text{selected chunks}
    \rightarrow
    \text{prompt construction}
    \rightarrow
    \text{generation}
    \rightarrow
    \text{validation and response}

The model does not have a way to query the index directly. Instead, application code executes retrieval, 
decides how many results to include in the prompt, formats the results, invokes the model, and checks the response. 
These software components are part of the behavior of the RAG system.

The two data flows (ingestion and retrieval) execute independently, but they must be designed together. 
A retriever can only filter by attributes that were stored as part of the ingestion process. 


ETL for Knowledge Extraction 
-----------------------------
Extract-Transform-Load (ETL) is a common data engineering pattern for constructing a centralized 
repository of refined data from disparate sources. It defines three primary steps: 

* *Extract* --- read in raw text, tables, metadata and other content from various sources. 
* *Transform* --- clean and normalize the extracted content into common data structures. 
* *Load* --- place the resulting records into a searchable index. 

An important aspect of ETL is that preserves the meaningful structures in the source documents. 
For example, an ETL pipeline might preserve section headings, paragraph boundaries, tables and figures, 
theorem names, equations, version information, sources and their identifiers, etc. 

Chunks, Metadata, Relations, and Provenance 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
A *chunk* is a retrievable unit of content. Breaking a long document into focused chunks lets the
retriever select a small amount of relevant evidence rather than placing the entire corpus in the
prompt.

For example, suppose we have a large corpus of papers from the arXiv on theoretical 
computer science. If we want to build a knowledge base of the content, 
a simplified chunk record might look like this:

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
    
The fields play different roles:

* ``chunk_id`` is the unique identifier for the chunk. 
* ``paper_id`` is the unique identifier for the arXiv paper containing the chunk. 
* ``chunk_type`` classifies the type of chunk, in this case a result statement. Other types might 
  include definition, proof, equation, discussion, etc. 
* ``raw_content`` is the actual content from the paper source, in this case, a snippet of 
  LaTeX. 
* ``normalized_text`` is the representation of ``raw_content`` used by retrieval. Normalization may remove 
  presentation-specific markup while preserving the mathematical and/or semantic meaning of the passage.
  Various techniques might be used to normalize the text. 
* ``start_offset`` and ``end_offset`` are the start and end locations within the source file 
  where the ``raw_content`` occurs. 

The term *provenance* refers to the documented origin and history of an asset as it moves 
through various transformations and is usually represented by several fields. 
*Provenance* in this context is the relationship between a chunk and its original source. 
Fields such as ``paper_id``, ``raw_content``, ``normalized_text``
``start_offset``, and ``end_offset`` help to trace the origins of the original and final 
versions of this chunk. The corresponding paper record can provide additional
information such as the source file, arXiv version, title, and authors.
Those fields are important for ensuring a reference to a specific 
chunk is accurate. 


Choosing Chunk Boundaries
^^^^^^^^^^^^^^^^^^^^^^^^^
Chunking is an engineering decision with tradeoffs, for example: 

* very small chunks may lose too much surrounding context to be meaningful or informative. 
* very large chunks may contain excessive, redundant or irrelevant material. 
* overlapping chunks can provide continuity but also introduce redundancy/duplication. 

There is no universally correct chunk size. The right choice depends on requirements of the 
application and various constraints, including: 

* the structure of the sources 
* the kinds of questions that will be asked 
* the retriever that will be used 
* the model's context limit

and others. 


Demo: A Minimal Retriever
-------------------------

In this section we will start to build some intuition about RAG through a simple demonstration. 
This will also give us an opportunity to introduce some of the key concepts, such as term-based 
retrieval. 

For this demo, we will use a small fictional collection of passages
from a polymer study. To keep the code focused on retrieval, each record
contains only its chunk identifier and normalized text. A production record
would also contain the classification and provenance fields described above.

.. code-block:: python

    CHUNKS = [
        {
            "chunk_id": "POLY-17#conditioning",
            "normalized_text": (
                "Before tensile testing, specimens were conditioned at "
                "23 degrees Celsius and 50 percent relative humidity for "
                "48 hours."
            ),
        },
        {
            "chunk_id": "POLY-17#materials",
            "normalized_text": (
                "The study compared polymer grades P-A, P-B, and P-C "
                "manufactured on the same extrusion line."
            ),
        },
        {
            "chunk_id": "POLY-17#strength",
            "normalized_text": (
                "At baseline, grade P-B had a mean tensile strength "
                "of 43.2 MPa."
            ),
        },
        {
            "chunk_id": "POLY-17#defect-rule",
            "normalized_text": (
                "A specimen was labeled defective if its tensile strength "
                "was below 35 MPa or if inspection found visible voids."
            ),
        },
        {
            "chunk_id": "POLY-17#limitations",
            "normalized_text": (
                "The study did not perform ultraviolet-aging experiments, "
                "so it reports no measurements after UV exposure."
            ),
        },
    ]


A First Term-Based Retriever
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We will begin with a simple form of *term-based retrieval*. This is also
called *lexical retrieval*. The word lexical means that the retriever
compares the words or tokens appearing in the question with the words or
tokens appearing in each chunk.

For example, the question

    How were the specimens prepared before tensile testing?

shares the terms ``specimens`` and ``tensile testing`` with the conditioning
chunk. These shared terms provide evidence that the chunk may be relevant.

Term-based retrieval does not initially understand meaning in the same way
a person does. If the question and passage express the same idea using
different words, the retriever may fail to recognize the relationship.

Term-Frequency-inverse Document Frequency (TF--IDF)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
To construct our small retriever, we will represent each chunk using
*term frequency--inverse document frequency*, usually abbreviated TF--IDF.

TF--IDF assigns weights using two main ideas:

* A term appearing in a chunk may help characterize that chunk.
* A term appearing in almost every chunk is less useful for distinguishing
  one chunk from another.

The result is a numerical vector for every chunk. Each vector position
corresponds to a term or phrase in the corpus, and the value represents
the importance of that term to the chunk.

We will use ``TfidfVectorizer`` from scikit-learn to perform this
transformation. Although scikit-learn is a machine-learning library, we
are not training a question-answering model here. The vectorizer is being
used as a convenient feature-extraction and indexing component.

When we call ``fit_transform``:

1. ``fit`` discovers the vocabulary and calculates the corpus-level term
   statistics needed for TF--IDF
2. ``transform`` converts each chunk into a vector using that vocabulary
3. the resulting matrix contains one row per chunk and one column per
   vocabulary feature

.. code-block:: python

    import numpy as np
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity

    chunk_texts = [
        chunk["normalized_text"]
        for chunk in CHUNKS
    ]

    vectorizer = TfidfVectorizer(
        lowercase=True,
        stop_words="english",
        ngram_range=(1, 2),
    )

    chunk_matrix = vectorizer.fit_transform(chunk_texts)

``chunk_matrix`` is a sparse matrix. It is called sparse because most
chunks contain only a small fraction of the corpus vocabulary, so most
entries in each row are zero.

To retrieve passages for a question, we:

1. transform the question using the same vocabulary
2. compare its vector with each chunk vector
3. rank chunks by their similarity to the question

We use cosine similarity for the comparison. A larger cosine-similarity
score indicates that the query and chunk have more strongly weighted
features in common.

.. code-block:: python

    def retrieve(
        query: str,
        k: int = 3,
        minimum_score: float = 0.0,
    ) -> list[dict]:
        query_vector = vectorizer.transform([query])
        scores = cosine_similarity(
            query_vector,
            chunk_matrix,
        ).ravel()

        ranked_indices = np.argsort(scores)[::-1]

        results = []

        for index in ranked_indices:
            score = float(scores[index])

            if score <= minimum_score:
                continue

            results.append(
                {
                    **CHUNKS[index],
                    "score": score,
                }
            )

            if len(results) == k:
                break

        return results


    def show_results(query: str, k: int = 3) -> None:
        results = retrieve(query, k=k)

        print(f"QUERY: {query}")

        if not results:
            print("  No positive-scoring chunks were found.")
            return

        for result in results:
            print(
                f"  {result['score']:.3f}  "
                f"{result['chunk_id']}"
            )
            print(f"         {result['normalized_text']}")


Before executing each query, predict which chunks should be returned.

.. code-block:: python

    show_results(
        "How were the specimens prepared before tensile testing?"
    )

    show_results(
        "What threshold was used to label a specimen defective?"
    )

    show_results(
        "Which chamber model was used for UV aging?"
    )

Retrieval Failure
^^^^^^^^^^^^^^^^^

Term-based retrieval works well when the question and relevant passage
share the exact same important terminology. Consider a differently worded question:

.. code-block:: python

    show_results(
        "Have researchers tested how outdoor sunlight changes "
        "the material over time?"
    )

A person can recognize that outdoor sunlight exposure is related to
ultraviolet aging. The TF--IDF retriever may return no result, however,
because the question and the limitations passage share no important
terms.

The relevant evidence exists in the corpus, but this particular retrieval
method does not find it. This is a retrieval failure rather than a
generation failure. In the next lecture, we will examine dense retrieval,
which attempts to match passages using learned semantic representations,
and hybrid retrieval, which combines term-based and semantic search.


Formal-Lit-QA: A First Look 
----------------------------

We will use the Formal-Lit-QA system to motivate and illustrate the concepts of the next several 
lectures. The idea with Formal-Lit-QA is to answer questions using a highly technical and evolving 
corpus of research articles on a theoretical (or "formal") topic area. A key point here is that 
the topic is evolving regularly, with many new papers being added on a weekly basis. 
Thus, even a recently trained model will not have seen the most recent results during 
training. 

We can define the system's task precisely as follows: 

    *Given a question and a specified literature corpus, the system should produce an answer 
    supported by passages from that corpus, cite the supporting passages, and indicate when the corpus 
    does not contain sufficient evidence to answer the question.*

We will use structured responses that distinguish four different types of outputs from the system: 

1. the answer, represented as a set of *claims*
2. the retrieved evidence, represented as a set of *chunks*
3. for each chunk, a chunk identifier and source metadata needed to resolve the chunk back to a citation in the corpus. 
4. an indication of whether sufficient evidence was found to answer the question

In the following diagram, three distinct phases are depicted: 1) the training phase, which results in a 
trained model that can be deployed and used for inference; 2) the knowledge extraction pipeline, 
performed when the corpus is built or updated, and which 
results in an index which can be searched efficiently; and 3) the Question-Answer runtime, which 
leverages the trained model, the knowledge base, and a retriever. The retriever retrieves relevant facts from the index and 
the application loads them into the prompt before returning the generated response to the user. 

.. figure:: ./images/Q-A-Arch-overview-train-retrieval.png 
    :width: 800px
    :align: center

    An initial architecture

Where Can the System Fail?
^^^^^^^^^^^^^^^^^^^^^^^^^^

Even this relatively simple system has several separable failure types at different 
points within the architecture:

* *ingestion failure* --- relevant source content is lost or malformed
* *retrieval failure* --- the index contains the evidence, but it is not selected
* *context-construction failure* --- the correct chunk is retrieved but omitted, truncated, or
  mislabeled in the prompt
* *generation failure* --- the prompt contains adequate evidence, but the answer contradicts or
  overstates it
* *validation failure* --- an unsupported claim or nonexistent citation is allowed into the final
  response.



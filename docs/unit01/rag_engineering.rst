RAG Engineering
===============

The previous module introduced the end-to-end RAG data flow. This module examines the engineering
decisions inside that data flow: how heterogeneous sources become a common record format, how several
retrieval methods produce ranked candidates, how ranked lists can be combined, and how retrieval can
be evaluated independently of answer generation.

By the end of this module, students should be able to:

* explain why different source formats require different extraction strategies
* map heterogeneous documents into a common, provenance-preserving chunk schema
* describe lexical, dense, and hybrid retrieval and their tradeoffs
* implement reciprocal-rank fusion over two ranked result lists
* distinguish candidate retrieval from reranking and context construction
* calculate ``Recall@k`` and reciprocal rank for a small retrieval benchmark



Parsing Documents into Structured Records
-----------------------------------------

Recall that the goal with the ingestion phase is to parse source documents of various kinds into a 
structured knowledge base. Ideally, ingestion would leverage a generic abstraction that can be used 
for a wide variety of source document types. The retriever and the question-answering layers of the 
application would not need to be concerned with different source document types. 

A common architecture therefore uses a family of
source adapters followed by a shared intermediate representation:

.. math::

    \text{PDF, HTML, Markdown, TeX, OCR}
    \rightarrow
    \text{format-specific adapters}
    \rightarrow
    \text{common records}
    \rightarrow
    \text{indexes}

Source adapters should preserve meaningful structure rather than returning only a single flat string.
Different formats present different challenges:

* PDF stores positioned layout elements, so extracted text may have incorrect reading order, missing
  columns, or detached captions.
* HTML contains semantic content alongside navigation, advertisements, scripts, and presentation
  elements.
* Markdown and TeX expose structure explicitly, but their syntax is complex and must be parsed using a parser 
  rather than removed with a few heuristics (e.g., regular expressions).
* Scanned, hand-written documents require optical character recognition (OCR), which introduces recognition errors
  and may require layout analysis.
* Tables, equations, figures, footnotes, and code blocks may require representations different from
  ordinary paragraphs.


Production-grade parsing is a substantial engineering effort. General-purpose projects include
`Docling <https://github.com/docling-project/docling>`_ and
`Apache Tika <https://tika.apache.org/>`_. TeX-specific options include
`LaTeXML <https://math.nist.gov/~BMiller/LaTeXML/>`_ and
`pylatexenc <https://github.com/phfaist/pylatexenc>`_. 

In this course, we will focus on the high-level interface design that parsers should adhere to 
in order to satisfy the requirements of the larger application. 


A Common Chunk Schema
^^^^^^^^^^^^^^^^^^^^^

A well-defined schema for a chunk in the system provides the interface between extraction and retrieval. Pydantic models 
make the interface explicit and allows for validating records before they enter an index.

.. code-block:: python

    from typing import Literal

    from pydantic import BaseModel, Field

    class Chunk(BaseModel):
        chunk_id: str
        document_id: str
        document_version: int = Field(ge=1)
        source_uri: str
        source_type: Literal["markdown", "html", "pdf", "tex", "ocr"]
        section_path: list[str] = Field(default_factory=list)
        ordinal: int = Field(ge=0)
        text: str = Field(min_length=1)
        content_hash: str
        metadata: dict[str, str | int | float | bool | None] = Field(
            default_factory=dict
        )

Several fields that may look redundant serve different purposes:

* ``chunk_id`` provides a unique identifier for a single chunk, i.e., a single retrievable unit.
* ``document_version`` identifies the source document version from which it was extracted.
* ``ordinal`` preserves source order and helps reconstruct neighboring context.
* ``content_hash`` can be used to detect whether the normalized content changed.
* ``source_uri`` and ``section_path`` can be used to resolve a chunk to its source document as part of, 
  for example, a validation step. 

It is important that the identifiers like ``chunk_id``be *stable*, that is, not changing throughout 
the entire lifetime of the application. For example, a chunk identifier based only on array position may change
whenever a preceding paragraph is inserted. A chunk identifier based only on the content hash changes
whenever a typo is corrected. A production system may therefore maintain both a stable logical ID and
a version-specific content hash.

A Minimal Structure-Aware Parser
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Let's consider an initial example parser for handling Markdown documents. 
The following parser splits a small Markdown document at headings. It is intentionally
simple, but it illustrates two important principles: retain section structure and construct validated
records conforming to the schema.

.. code-block:: python

    import hashlib
    import re

    HEADING = re.compile(r"^(#{1,6})\s+(.+?)\s*$")

    def slug(text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
        return normalized or "section"

    def chunk_markdown_sections(
        document_id: str,
        version: int,
        source_uri: str,
        markdown: str,
    ) -> list[Chunk]:
        chunks: list[Chunk] = []
        section_path: list[str] = []
        body: list[str] = []document_id
        ordinal = 0

        def flush() -> None:
            nonlocal body, ordinal
            text = "\n".join(body).strip()
            body = []
            if not text:
                return

            title = section_path[-1] if section_path else "preamble"
            digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
            chunks.append(
                Chunk(
                    chunk_id=f"{document_id}#{slug(title)}-{ordinal:03d}",
                    document_id=document_id,
                    document_version=version,
                    source_uri=source_uri,
                    source_type="markdown",
                    section_path=section_path.copy(),
                    ordinal=ordinal,
                    text=text,
                    content_hash=digest,
                )
            )
            ordinal += 1

        for line in markdown.splitlines():
            match = HEADING.match(line)
            if match:
                flush()
                level = len(match.group(1))
                title = match.group(2)
                section_path = section_path[: level - 1] + [title]
            else:
                body.append(line)

        flush()
        return chunks

The ``HEADING`` regular expression is doing the work of identifying headers. Let's break it down:

* The initial ``^`` matches the start of a line/start of string
* The ``(#{1,6})`` matches between 1 and 6 ``#`` characters in a row and captures them as a group (group 1).
* ``\s+`` matches any number of white space characters after the ``#`` characters 
* ``(.+?)`` matches 1 or more of any character other than newline and captures them as a group (group 2)
* ``\s*`` matches and consumes 0 or more white space characters 
* ``$`` asserts an end of line/end of string. 

Note that the length of the group 1 string is the heading level (i.e., ``#`` is level 1, ``##`` is level 2, 
``###`` is level 3, etc.), while group 2 itself is the actual heading title. 


We can try it on an example document with two section headers: 

.. code-block:: python

    sample_document = """
    # Tapis Documentation

    Tapis is an API platform for secure, distributed, reproducible, research computing. 

    ## TACC-hosted Tapis Instance

    While open source and deployed at multiple institutions, the primary Tapis installation is hosted at TACC. 
    """

    parsed = chunk_markdown_sections(
        document_id="TAP-101",
        version=2,
        source_uri="corpus/TAP-101.md",
        markdown=sample_document,
    )

    for chunk in parsed:
        print(chunk.chunk_id, chunk.section_path, chunk.text)


.. note:: 

  This example is just for demonstration purposes and is not able to parse arbitrary Markdown. In particular, the
  regular expression above does not identify various Markdown structures, such as code blocks, embedded HTML, 
  or even all edge cases associated with heading parsing.


Ranking in Retrieval Algorithms 
--------------------------------

The job of a retriever is to take an input query and match it to a set of records. How many records should 
the retriever return? Often times, the number of records to be used depends on the application and context. 
Therefore, a standard approach is to simply return a ranking of records, with the most relevant records 
(according to the retriever) appearing first. 

Lexical Retrieval 
-----------------

Lexical retrieval, also called sparse retrieval, is a search method that matches queries to documents 
based on the tokens or keywords they have in common. The term 
*sparse* here refers to the vector representation used where each token in the vocabulary is mapped to a 
unique dimension. Thus, a vector representing a chunk is very high dimensional, but must entries in the vector 
are 0. 

We were introduced last time to the TF--IDF (term frequency--inverse document frequency). It used two 
ideas to rank records for a specific query: 

* A term appearing in a record may help characterize that chunk.
* The more common a term appears in the set of recrods, the less useful it is for distinguishing
  one record from another.

The BM25 algorithm adds adds two additional components: *term-frequency saturation* and 
*document-length normalization*. 

* term-frequency saturation is the idea that very common words should not dominate the score
* document length normalization is the idea that longer records will have more words and thus more matches, so they 
  should be penalized for their extra length.

A common form is:

.. math::

    \operatorname{BM25}(q,d) =
    \sum_{t \in q}
    \operatorname{IDF}(t)
    \frac{f(t,d)(k_1+1)}
         {f(t,d) + k_1\left(1-b+b\frac{|d|}{\operatorname{avgdl}}\right)}

Here, :math:`f(t,d)` is the frequency of term :math:`t` in document :math:`d`, :math:`|d|` is the
document length, and :math:`k_1` and :math:`b` control saturation and length normalization. Students do
not need to memorize the formula; the important point is that repeating a term ten times does not make
a document ten times as relevant.

To make lexical retrieval go fast, an *inverted index* is typically used. The idea is that since each document 
or chunk contains a relatively small number of tokens, the system maintains a lookup table of keywords -> documents. 
At query time, the engine can score likely candidates rather than scan every document.


The following TF--IDF implementation is sufficient for our small corpus:

.. code-block:: python

    import numpy as np
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity

    sparse_vectorizer = TfidfVectorizer(
        lowercase=True,
        stop_words="english",
        ngram_range=(1, 2),
        token_pattern=r"(?u)\b[\w#.-]+\b",
    )
    sparse_matrix = sparse_vectorizer.fit_transform(
        chunk["text"] for chunk in CHUNKS
    )

    def sparse_search(query: str, k: int = 3) -> list[dict]:
        query_vector = sparse_vectorizer.transform([query])
        scores = cosine_similarity(query_vector, sparse_matrix).ravel()
        order = np.argsort(scores)[::-1]
        return [
            {**CHUNKS[index], "score": float(scores[index])}
            for index in order[:k]
            if scores[index] > 0
        ]


Lexical retrieval is especially good at exact term matching which can be particularly important in cases 
such as: error messages, theorem numbers and other identifiers as well as any string where spelling matters. 

On the other hand, lexical retrieval is of limited use when attempting to match synonyms or different forms of 
a specified vocabulary. Spelling mistakes, punctuation and other variations in the input could reduce its 
effectiveness. 


Dense Retrieval 
---------------

By contrast, a dense retriever maps both queries and chunks into a lower-dimensional embedding space using an 
embedding model. It then ranks chunks using a similarity measure such as cosine similarity:

.. math::

    \operatorname{cosine}(q,d) =
    \frac{q \cdot d}{\lVert q \rVert\lVert d \rVert}

The embedding model used in dense retrieval ideally would have been trained to learn statistical relationships 
among expressions. For this reason, dense retrieval can match a paraphrase even when the query and the relevant 
passage share few exact words.

The ``sentence-transformers`` Python library is part of the ecosystem maintained by HuggingFace and provides 
powerful tools for dense vector embeddings for text and images. 

The code below uses ``sentence-transformers`` to provide a basic dense search implementation:

.. code-block:: python

    from sentence_transformers import SentenceTransformer

    embedding_model = SentenceTransformer(
        "sentence-transformers/all-MiniLM-L6-v2"
    )
    dense_matrix = embedding_model.encode(
        [chunk["text"] for chunk in CHUNKS],
        normalize_embeddings=True,
    )

    def dense_search(query: str, k: int = 3) -> list[dict]:
        query_vector = embedding_model.encode(
            [query],
            normalize_embeddings=True,
        )[0]
        scores = dense_matrix @ query_vector
        order = np.argsort(scores)[::-1]
        return [
            {**CHUNKS[index], "score": float(scores[index])}
            for index in order[:k]
        ]

In the code above we perform a matrix-vector multiplication between the encoded chunks and the query. 
This is fine for a small example, but for large collections, this would be inefficient. 
Instead, a vector index uses exact or approximate nearest-neighbor search. 
But the underlying interface to the rest of the application would remain the same: a given input query 
produces a ranked candidate list.

Dense retrieval has different tradeoffs from lexical retrieval:

.. list-table::
   :header-rows: 1
   :widths: 24 38 38

   * - Method
     - Often strong when
     - Often weak when
   * - Lexical
     - Exact terms, identifiers, quotations, rare names, and transparent matching matter.
     - Query and passage express the same idea with different vocabulary.
   * - Dense
     - Paraphrases and semantic similarity matter.
     - Exact identifiers or subtle negation and qualifiers determine relevance.


Note also that the performance of dense retrieval depends greatly on the embedding model and how well the given 
domain is represented by it. A general embedding model may not represent a highly-specialized domain very 
well. For example, an embedding model trained on popular news articles and books may not have strong representation for 
specialized research in biology, mathematics, chemistry or engineering. 


Hybrid Retrieval
----------------

In some sense, sparse and dense retrieval have complementary strengths and weaknesses. It is natural, then, 
to consider a hybrid system that combines both. The basic idea is to conduct the sparse and dense retrievals 
separately in parallel, each producing a ranking, and then combine the rankings in some way to produce a 
single ranking. 

One robust method is called *reciprocal-rank fusion* (RRF). Suppose we have a set of :math:`R` lists 
of rankings. Intuitively, in RRF we score a record :math:`d` by summing the reciprocals of its rankings 
in each of the :math:`R` lists: 

.. math::

    \operatorname{RRF}(d) =
    \sum_{r \in R}
    \frac{1}{K + \operatorname{rank}_r(d)}

Here, :math:`\operatorname{rank}_r(d)` is :math:`d`'s ranking in the :math:`r^{th}` list 
and :math:`K` is a configurable constant that controls how strongly the highest ranks are rewarded. 
The lower the :math:`K`, the more the highest ranks are rewarded (or, said differently, the more lower ranks 
are punished), and in practice it is commonly set near 60. 

Note that RRF combines ranks rather than raw scores, avoiding the need to compare a BM25 score directly with
a cosine-similarity score.

.. code-block:: python

    from collections import defaultdict

    def reciprocal_rank_fusion(
        rankings: list[list[dict]],
        rrf_k: int = 60,
        limit: int = 5,
    ) -> list[dict]:
        fused_scores: dict[str, float] = defaultdict(float)
        records: dict[str, dict] = {}

        for ranking in rankings:
            for rank, result in enumerate(ranking, start=1):
                chunk_id = result["chunk_id"]
                records[chunk_id] = result
                fused_scores[chunk_id] += 1.0 / (rrf_k + rank)

        ordered_ids = sorted(
            fused_scores,
            key=fused_scores.get,
            reverse=True,
        )
        return [
            {**records[chunk_id], "score": fused_scores[chunk_id]}
            for chunk_id in ordered_ids[:limit]
        ]

    question = "Why can computation not continue forever?"
    sparse_results = sparse_search(question, k=5)

    # A saved dense ranking keeps the fusion exercise runnable even when the
    # optional embedding model is not installed on a student's machine.
    example_dense_results = [
        {**CHUNKS[3], "score": 0.84},
        {**CHUNKS[4], "score": 0.53},
        {**CHUNKS[5], "score": 0.41},
    ]

    hybrid_results = reciprocal_rank_fusion(
        [sparse_results, example_dense_results],
        limit=3,
    )

    for result in hybrid_results:
        print(f"{result['score']:.4f}  {result['chunk_id']}")

The ``limit`` argument controls the number of fused candidates retained.
If the optional embedding model is available, replace ``example_dense_results`` with
``dense_search(question, k=5)`` and compare the fused ranking.


.. .. figure:: ./images/Hybrid-search.png 
..     :width: 800px
..     :align: center

..     An example hybrid-retrieval architecture

.. Test 

Metadata Filters and Relation Expansion
---------------------------------------

Similarity is not the only source of relevance. Application constraints may require filtering by
document version, date, author, access permission, or source type. When possible, mandatory filters
should be enforced as part of retrieval rather than merely described in a prompt.

Relations can add context that similarity search alone misses. Formal-Lit-QA might connect a theorem to
its proof, a use of notation to its definition, or an erratum to the original result.

.. code-block:: python

    RELATIONS = {
        "TYP-101#type-safety": [
            "TYP-101#progress",
            "TYP-101#preservation",
        ]
    }

    def expand_related(results: list[dict]) -> list[dict]:
        by_id = {chunk["chunk_id"]: chunk for chunk in CHUNKS}
        ordered_ids = [result["chunk_id"] for result in results]

        for result in results:
            for related_id in RELATIONS.get(result["chunk_id"], []):
                if related_id not in ordered_ids:
                    ordered_ids.append(related_id)

        return [by_id[chunk_id] for chunk_id in ordered_ids]

Relation expansion should be deliberate and bounded. Expanding every neighbor in a dense relation graph
can overflow the prompt with redundant or irrelevant context.

Constructing the Prompt 
-----------------------

Obtaining the highest-ranked records from the retriever is only one aspect of building the prompt that will 
be supplied to the LLM. Constructing the prompt will usually also involve the following: 

* enforcing privacy and other access-controls
* removing exact or near duplicates
* use relations to expand the matched records to include related records
* fit the full record set within a defined context window budget
* preserve chunk identifiers and source metadata
* treat chunk content as untrusted data

The last point matters because a source document may contain text such as “ignore previous instructions.”
Such text belongs to the corpus but the application must take care when adding it to a system prompt.


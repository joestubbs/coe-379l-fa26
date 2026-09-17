Introduction to Retrieval Augmented Generation (RAG) and Structured Knowledge Pipelines
========================================================================================

In this module we introduce Retrieval Augmented Generation (RAG) a method for improving a 
model's ability to provide more context-specific and accurate information about topics it may not 
have seen in its training distribution. We will discuss the basic architecture of a RAG ETL pipeline 
and the types of retrieval algorithms that are commonly used. Finally, we will introduce an 
illustrative project, called Formal-Lit-QA, which we will develop and improve throughout the 
semester. 

By the end of this module, students should be able to: 

* explain why retrieval is useful even when using large foundation models 
* identify the major stages of a RAG pipeline 
* explain why provenance must be maintained through the ETL process 
* understand the Formal-Lit-QA problem statement and desired system behavior. 

We'll illustrate some of the examples using the following Python code that we introduced 
last time. 

.. code-block:: python 


    import os 
    import requests 

    MODEL = "MiniMax-M2.7"
    BASE_URL = "https://ai.tejas.tacc.utexas.edu/v1" 
    API_KEY = os.environ.get("API_KEY")

    def ask_model_question(question: str,  url: str = BASE_URL, model: str = MODEL):
        """
        This function implements chat completion endpoint using only requests.
        """
        url = f"{url}/chat/completions"
        headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": model,
            "messages": [
                {"role": "system", "content": "You are a helpful assistant."},
                {
                    "role": "user",
                    "content": f"Answer the following question. Question: {question}",
                },
            ],
        }
        r = requests.post(url, json=data, headers=headers)
        r.raise_for_status()
        return r.json()['choices'][0]['message']['content']


Motivation for Retrieval Augmented Generation 
---------------------------------------------

Recall from the previous module we established the following about foundation models: 

1. A foundation model generates output from its parameters and current context. 
2. Once training completes, the model's parameters are typically frozen and not updated. 
3. Its parameters are not like a database of facts and the responses they produce can be  
   unreliable.
4. The model is mostly opaque and "reasoning" behind the responses cannot easily be discerned. 

Despite the powerful nature of many foundation models, they have some fundamental limitations. 
For one thing, they are really only built to predict the subsequent sequence of text. They are 
not general-purpose applications: 

.. code-block:: python3 

   ask_model_question("What day is today?", model="Llama-4-Maverick-17B-128E-Instruct")

   --> "I'm not able to tell you what day it is today because I don't have access to a 
   calendar or clock and I'm not able to look up the current date. However, I can 
   guide you on how you might be able to find out. You can check your phone, computer, 
   or a wall calendar to see the current date."


Second, their autoregressive next-token prediction behavior is based only on their training data. 
If you ask them a question about something that was not in their training data, they 
have no way of generating the answer. 

For example, Meta lists the training or knowledge cutoff date for teh the Llama-4-Maverick model 
as August 31, 2024; you can find this on the `model card <https://developer.meta.com/ai/docs/model-cards-and-prompt-formats/llama4/>`_. 

But that means if we ask it a question about an event that occurred after that date, it won't 
know about it. 

.. code-block:: python3 

    ask_model_question("Who won the 2024 US presidential election?", model="Llama-4-Maverick-17B-128E-Instruct")

    -> The 2024 US presidential election has not yet occurred. It is scheduled to take place on November 5, 2024. 
    Therefore, there is no winner to report at this time.'

Even for topics that the model's see during training, results can be unreliable. 
For example, my group has been developing a project called Tapis, an HTTP API platform for research computing. 
Llama 4 saw information about Tapis in its training data, and it can answer a general question 
reasonably well:

.. code-block:: python3: 

  ask_model_question("What is the Tapis API? ", model="Llama-4-Maverick-17B-128E-Instruct")

  --> The Tapis API, formerly known as the iPlant Collaborative API, is a RESTful API that provides a unified 
  interface to a variety of cyberinfrastructure resources. It is designed to support scientific research and 
  discovery by providing a simple, standardized way to access and manage various types of data, computational 
  resources, and services.

  The Tapis API is part of the Tapis framework, which is an open-source, community-driven project that 
  aims to provide a comprehensive platform for scientific research and discovery. The Tapis 
  framework includes a range of components, including the Tapis API, that work together to provide a 
  robust and scalable platform for managing and analyzing large datasets, executing computational workflows, 
  and more.


But when asked a more detailed question, the results are less reliable: 

.. code-block:: python3: 

    ask_model_question("How do I use the Tapis python library to generate a JWT?", model="Llama-4-Maverick-17B-128E-Instruct")

    --> 

    To generate a JWT (JSON Web Token) using the Tapis Python library, you will first need to ensure that you 
    have the Tapis library installed. If you haven't installed it yet, you can do so using pip:

    ```bash
    pip install tapis-python
    ```

    However, it seems there might be a confusion or a need for clarification because the specific 
    library named `tapis-python` is not a widely recognized or standard library for interacting with 
    Tapis (formerly known as Aware IM or other systems named Tapis). Assuming you're referring to 
    a library related to Tapis, a cyberinfrastructure platform, I'll provide a general approach to 
    generating a JWT, which typically involves using a library like `requests` for making HTTP 
    requests to the authentication service or using a specific SDK if available.

    For Tapis specifically, if you're using the Tapis V3 API, you would typically interact with it 
    using the `tapis3-python` client or directly making HTTP requests.

    Here's a simplified example of how you might generate a JWT using the Tapis Python client 
    (`tapis3-python`), assuming that's the correct library you're referring to:

    1. **Install the Tapis3 Python Client**

    First, ensure you have the correct client installed. You can install it via pip:

    ```bash
    pip install tapis3-python
    ```

    2. **Generate a JWT**

    To generate a JWT, you typically need to authenticate with the Tapis service. Here's a simplified example:

    ```python
    from tapis3_client import Tapis

    # Initialize the Tapis client
    tapis = Tapis(
        base_url='https://your.tapis.instance.url',
        username='your_username',
        password='your_password'
    )

    try:
        # Authenticate and get a JWT token
        tapis.get_tokens()
        jwt_token = tapis.access_token.access_token
        
        print("JWT Token:", jwt_token)
    except Exception as e:
        print("Failed to obtain JWT:", str(e))
    ```

    In this example, replace `'https://your.tapis.instance.url'`, `'your_username'`, and `'your_password'` 
    with your actual Tapis instance URL, username, and password.

    This code snippet initializes a Tapis client, authenticates using your credentials, and retrieves a 
    JWT token, which is then printed out.

    If you're directly using an authentication service or a different library, the process might vary. 
    Always refer to the specific documentation of the library or service you're interacting with for 
    the most accurate and up-to-date instructions.

And of course, an AI model can never know the answers to questions 

  .. code-block:: python3 

    ask_model_question("How many private Tapis systems do I have access toT?", model="Llama-4-Maverick-17B-128E-Instruct")

    --> "I don't have access to your personal information or specific details about your access 
    to private Tapis systems. To determine the number of private Tapis systems you have access to, 
    I recommend checking your account settings or contacting the relevant support team directly. 
    They should be able to provide you with the most accurate and up-to-date information."


RAG is a method for attempting to overcome these shortcomings by providing information to the model directly 
in the prompt that is relevant to the input. 

We will use *retrieval* to complement the model with the following:

* information absent from model training
* information that changes over time
* private or domain-specific information
* evidence that users must be able to inspect

The goal with RAG is to provide high-quality evidence to the model to improve the quality of the 
results. A key point is that RAG retrieves information for **each user query** and injects it 
**as part of the prompt**. 
RAG is not a training or fine-tuning procedure. It does not change the models weights. 
Additionally, RAG does not guarantee that the model will use the supplied evidence correctly or be free of 
hallucinations. 

The Basic RAG Pipeline 
----------------------

Broadly, RAG is comprised of two separate subsystems: an Ingestion system and a Retrieval system. These 
two systems execute independently from each other, but they must be designed together. 

Ingestion 
^^^^^^^^^
During ingestion, source documents of various kinds are processed into a structured knowledge database. 
The high-level algorithm is as follows: 

.. math:: 

    \text{documents}
    \rightarrow
    \text{extraction}
    \rightarrow
    \text{transformation}
    \rightarrow
    \text{chunks}
    \rightarrow
    \text{index}

Here, the ultimate goal is an *index*, i.e., a data structure of knowledge that supports efficient search.

Retrieval 
^^^^^^^^^^

When developing an AI application that processes a user's input, we leverage the pre-built index from the 
previous phase on each request. The high-level algorithm can be depicted as follows: 

.. math:: 

    \text{question}
    \rightarrow
    \text{retrieval}
    \rightarrow
    \text{selected chunks}
    \rightarrow
    \text{prompt}
    \rightarrow
    \text{answer}



ETL for Knowledge Extraction 
-----------------------------
Extract-Transform-Load (ETL) is a common paradigm in data science and machine learning to generate a centralized 
repository of refined data from disparate sources. It defines three primary steps: 

* *Extract* --- read in raw text, tables, metadata and other data from various sources. 
* *Transform* --- clean and normalize the extracted content into a common set of data structures. 
* *Load* --- place the resulting records into a searchable index. 

An important aspect of ETL is that preserves and even enhances the meaningful structures in the source documents. 
For example, an ETL pipeline might preserve section headings, paragraph boundaries, tables and figures, 
version information, sources and their identifiers, etc. 

Chunks, Metadata, Relations, and Provenance 
--------------------------------------------
A standard technique involves *chunking*, that is, creating individual records of content of different types. 
By breaking up larger documents into chunks, the resulting knowledge base contains focused records with 
specific content that can be fetched when needed. 

What exactly to include in an individual chunk including how large to make it is an engineering design choice 
that comes with tradeoffs. For example: 

* very small chunks may lose too much surrounding context to be meaningful or informative. 
* very large chunks may contain excessive, redundant or irrelevant material. 
* overlapping chunks can provide continuity but also introduce redundancy/duplication. 

As always in software engineering, understanding the application's requirements is essential for 
making a good design choice. Some requirement types and implications include: 

* How large is the context window for the LLM? How many retrieved chunks can we fit into the window? 
* For the given corpus of documents, what chunk size would result in chunks with 

*Provenance* in this context is the relationship between a passage or chunk and its original source. 

Formal-Lit-QA: A First Look 
----------------------------

We will motivate and illustrate the concepts of the next several lectures with a specific system which 
we will refer to as Formal-Lit-QA, for formal literature question answer. The goal for the system is 
to allow users to ask questions about a highly specialized research domain, and one that is constantly 
evolving with new papers. 

We can define the system's task precisely as follows: 

    *Given a question and a specified literature corpus, the system should produce an answer supported by passages 
    from that corpus, cite the supporting passages, and indicate when the corpus does not contain 
    sufficient evidence.*

We will use structured responses that distinguish four different types of outputs from the system: 

1. the answer, as a set of *claims*
2. the retrieved evidence, as a set of *chunks*
3. for each chunk, a structured reference to the index which ultimately maps back to a citation in the corpus. 
4. an indication of whether insufficient evidence was found to answer the question. 

In the following diagram, three distinct phases are depicted: 1) the training phase, which results in a 
trained model that can be deployed and used for inference; 2) the knowledge extraction pipeline, which 
results in a knowledge base which can be searched efficiently; and 3) the Question-Answer runtime, which 
leverages the trained model and a retriever. The retriever retrieves relevant facts from the index and 
the application loads them into the prompt before returning the generated response to the user. 

.. figure:: ./images/Q-A-Arch-overview-train-retrieval.png 
    :width: 800px
    :align: center

    An initial architecture

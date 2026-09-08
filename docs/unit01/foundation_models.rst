Foundation Models 
=================
In this module we introduce foudnation models, focusing primarily on large language models (LLMs). 
We will discuss the basic development lifecycle of foundation models, including data collection 
and curation, architecture and training objectives, pre-training, post-training, and evaluation. 
We will distinguish training from inference and describe foundation model inference services, including 
HTTP APIs and the "Open AI compatible" specification. We then discuss several fundamental concepts related to 
integrating foundation models in applications, including prompting, sampling and controls, and 
hallucinations. 

By the end of this module, students should be able to: 

1. Describe the basic development lifecycle of a foundation model and 
   understand the difference between training and inference for foundation models
2. Understand the mechanics of using an HTTP inference server for a foundation model and describe 
   the OpenAI-compatible HTTP specification. 
3. Use basic techniques for prompting and recognize a well-formed prompt from a poorly formed one. 
4. Describe hallucinations   


Introduction to Foundation Models 
----------------------------------

So far, the models we have considered have largely been focused on an individual task;
for example, a model that could predict the tensile strength of a polymer or a CNN that could classify 
the article of clothing contained in a 28x28 grey-scale image. The model architecture and the dataset 
used to train the model were both designed with only a single task in mind. 

Foundation models, which have emerged only recently, say within the last 6 or 7 years, are fundamentally different. 
They are models that have been trained on a wide variety of data 
and at such a sufficient scale that they can be adapted or applied to many different tasks.

A foundation model is not necessarily a language model. Foundation models can operate on text, images, 
audio, biological sequences, scientific data, or combinations of several modalities. In this module though, 
we will focus primarily on large language models (LLMs).

A key aspect of foundation models is that they can be specialized for a variety of different tasks. 
Rather than training an independent model from scratch for sentiment analysis, summarization, 
question answering, and code generation, developers begin with a broadly trainied foundation model 
and adapt or prompt it for different tasks.

We should distinguish the following concepts: 

* Foundation model --- consisting primarily of its architecture and learned parameters.
* Inference service --- which loads and executes the model after it has been trained. 
* AI application --- which supplies prompts, retrieves data, calls tools, validates outputs, and presents results.

An important point is that a powerful model does not by itself constitute a reliable application. 

Development lifecycle
----------------------

Broadly, the development of a foundation model follows the following simplified lifecycle:

.. math:: 

    \text{data}
    \rightarrow
    \text{architecture and objective}
    \rightarrow
    \text{pretraining}
    \rightarrow
    \text{post-training}
    \rightarrow
    \text{evaluation}
    \rightarrow
    \text{deployment}

In practice, these stages overlap and are repeated. 

Data Collection and Curation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Training begins with a collection of data. For a language model, this may include web pages, 
books, articles, code, technical documents, conversations, and other text sources.

Adding more data does not always improve the training set, and usually a series of curation 
steps are performed. Curation may include:

* removing exact and near duplicates
* filtering corrupted or low-quality content
* balancing domains and languages
* tracking provenance and licensing
* reducing private or sensitive information
* detecting evaluation-data contamination
* applying safety and policy filters

The dataset and distribution used to train the model strongly shapes its behavior. For example, if a domain, 
language, demographic group, or style is poorly represented, the trained model may perform poorly on it.
Data curation is thus an important part of model design. 

Information regarding the sources and volumes of data used to train foundation models varies drastically 
across the industry. In some cases, the datasets used are completely open and available for inspection, 
while in other cases, no public information is available. For example, the last OpenAI model we have 
any public information on is GPT-3 and nothing is known about what the Claude 3 family of models were 
trained on, to the best of our knowledge. 

The following list of large sources of texts have been used to train LLMs:  

* Common Crawl: An open repository of web crawl data maintained by the non-profit of the same name. 
  The Feb/March 2024 crawl contains 3.16 billion pages and is over 90 TB compressed. [5]
* Colossal Clean Crawl Corpus (C4): a filtered/cleaned up version of the Common Crawl 
* WebText: Introduced by OpenAI in the GPT-3 paper [4], it analyzed and scraped outbound Reddit links deemed to 
  be of high quality and then applied some filtering/post-processing (e.g., deduplication) to clean it up. 
  About 8M documents in total, 40GB of text. 
* Wikipedia: About 60M pages, 22GB compressed. 
* GitHub code repositories: details seem to be somewhat unclear as to what exactly has been used. 


Architecture and Training Objectives 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
To the best of our knowledge, most foundation language models are based on the transformer architecture, 
though there are certainly other architectures that have been used, such as State Space Models or 
Diffusion Models. 

Even within the transformer architecture, designing a new foundation model involves making a number 
of architectural choices, including: 

* parameter count -- Total number of trainable parameters in the model 
* context length -- The maximum size (number of tokens) of a single input
* hidden dimension -- The embedding dimension and, equivalently, the size of the input dimension of the feed-forward 
  network. 
* number of layers -- Total number of layers 
* attention mechanism -- Variants including masked/not masked (encoder/decoder), number of heads, etc. 

Additionally, a training objective must be chosen. For example, a decoder-only language model (masked attention) 
commonly uses *autoregressive next-token prediction* as the objective function. Autoregressive next-token 
prediction is a framework where a language model predicts the single most likely next token in a 
sequence given all previous tokens, feeding its own previous outputs back in as inputs for subsequent steps.
This method is a self-supervised learning method because the targets are constructed automatically from the 
data. 

Pre-training 
^^^^^^^^^^^^
During pretraining, the model processes an enormous numbers of token sequences. 
The process is similar to the the ANNs we have studied: input tokens are passed through the network to produce 
predictions, a loss measuring the prediction error is computed, and an optimizer updates the parameters.
The final result is sometimes referred to as a *base model*. A base language model has learned statistical 
patterns from a massive amount of text, but it likely lacks a number of desirable capabilities such as 
following instructions, mathematical reasoning and planning, etc. 

To the best of our knowledge, decoder-only models that leverage autoregressive next-token prediction have emerged 
as the dominant architecture for base foundation language models. The reason is that they can be trained on a 
massive amount of data using a very simple mechanism: predict the next token in the sequence. 

Post-training 
^^^^^^^^^^^^^
The goal of post-training is to enhance a base model with additional capabilities, and different techniques 
are used to accomplish different goals. Examples include: 

* Supervised fine-tuning on instruction-response examples to improve, for example, the model's instruction-following 
  capabilities. 
* Reinforcement leaning with verifiable rewards (RLVR) to improve the model's code generation, schema use (g.e., in 
  tool calling) and mathematical reasoning capabilities. 
* Reinforcement learning with human feedback (RLHF) to align the model for open-ended, subjective, or taste-based tasks.
* Domain-specific fine-tuning to gain expertise in a particular domain. 

For example, when prompted with the input: 

  "Write a Python function that implements binary search"

a base model might reply with 

  "with a docstring and typed parameters"

because the model is literally just trying to complete the sequence. Post-training techniques, such as 
supervised fine-tuning, can train the model to recognize instructions and provide appropriate responses. 

Evaluation 
^^^^^^^^^^
Ideally, evaluation should occur throughout development and deployment of a model. *Benchmarks* are an 
important mechanism by which a model's capabilities are evaluated. 

A benchmark is a standardized set of data, tasks, and metrics used to evaluate and compare 
model performance under controlled conditions. We've already seen one example of a benchmark -- the MNIST 
dataset. This benchmark has been considered "solved" for many years, as we have had AI models that could 
achieve high accuracy on MNIST for some time. But there are literally thousands of academic benchmarks 
across a wide range od domains and tasks. 

While benchmarks often receive a lot of the attension, there are many other important aspects to evaluation 
beyond benchmarks, including: 

* Latency and throughput measurements 
* Memory and power consumption 
* Robustness to prompt variation 
* Bias and fairness assessments 
* Behavior on adversarial inputs 

Inference and HTTP APIs 
-----------------------

It's important to emphasize that training a foundation model is a massive undertaking requiring months of 
time and enormous computing budgets. During training, a model is shown data with known targets, predictions 
are made, loss is computed, and the model parameters are updated. 

Once a model's training is completed, the model's parameter values are frozen and the model is deployed 
to be used on new samples. Applying a model to a new input is called *inference* and it is fundamentally 
distinct from training. During inference, the model receives a new input, the input is passed through the 
layers, and an output (prediction) is produced. Changing the input may change the output, but it does 
not change the model's parameters. 

Inference Server 
^^^^^^^^^^^^^^^^
The concept of an *inference server* has gained traction in the ML community. The idea is to wrap the 
trained ML model in a lightweight server that can be executed over the network. Commonly, this is done 
either as an HTTP 1.x/REST API or an HTTP 2/gRPC server. 

For example, a REST API inference server for the model we developed to classify images with clothes objects 
may have the following endpoints: 

+---------------------------------+------------+---------------------------------------------+
| **Route**                       | **Method** | **What it should do**                       |
+---------------------------------+------------+---------------------------------------------+
| ``/models/clothes/v1``          | GET        | Return basic information about v1 of model  |
+---------------------------------+------------+---------------------------------------------+
| ``/models/clothes/v1``          | POST       | Classify clothes object in image payload    |
|                                 |            | using version 1 (v1) of the model.          |
+---------------------------------+------------+---------------------------------------------+

When a client makes an HTTP POST request to ``/models/clothes/v1`` they send an image as part of the 
payload. The inference server must:

1. Retrieve the image out of the request payload. 
2. Perform any preprocessing necessary on the image byte stream. 
3. Apply the model to the processed image data to get a classification result. 
4. Package the classification result into a convenient data structure (e.g., JSON).
5. Send a response with the classification data structure included as the message body.  

As you can see, we have encoded both the kind of model ("clothes") as well as the version ("v1") into 
our URL structure. This means that if we developed another model, we could easily add it to our 
inference server. We could also easily add a new version of 
the clothes model and serve both at the same time. 

There are a number of advantages to using an inference server architecture, many of which are just the 
advantages enjoyed by all HTTP/microservice architectures: 

1. *Framework agnostic:* Regardless of which ML framework your model is developed in, it can be packaged 
   into an inference server. With that said, some solutions are framework-specific. In fact, one of the 
   solutions we'll look at is Tensorflow Serving, which serves Tensorflow models (and other kinds of 
   *servables*). 
2. *Language agnostic API:* Components of the application can interact easily with the inference server, 
   regardless of the programming language they are written in, because all modern languages have an HTTP 
   client. 
3. *Scalability:* Multiple components of the application can interact with the model inference server, 
   even from different computers. Additionally, multiple instances of the inference server itself can 
   be deployed to increase the throughput of inferences. 
4. *Plug-and-play and model chaining:* The concept of *plug-and-play* for ML models is the idea or goal
   of enabling different models to be "plugged" into an application with little to no code changes to 
   the rest of the application. In order to achieve this, different models that perform the same (or similar)
   task must conform to a common interface. An HTTP interface is one possible mechanism. Similarly, 
   *model chaining* is the idea that we can feed outputs of one model as inputs to another model. For example,
   we may have one model that finds language characters in an image and another model that translates 
   words from one language to another (for example, 
   `Google image translate <https://support.google.com/translate/answer/6142483?hl=en&co=GENIE.Platform%3DDesktop>`_). 
   If individual models use HTTP requests and responses, the responses from one model can be easily fed into 
   as a request to the next model. 
5. *Versioning:* There are multiple, intuitive ways to version a model inference server. One which was suggested 
   above is to use the URL to encode the version. These methods will be familiar to most developers, as REST 
   APIs (and HTTP services more generally) have become common in cloud computing. 


The "OpenAI-Compatible" HTTP API
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
The company OpenAI, makers of ChatGPT, were one of the first to release inference services as an HTTP API, and 
the popularity of their products has led to the industry adopting it as a de facto standard for LLM inference.
In other words, an "OpenAI-compatible" API is an HTTP API that mimics the URL paths, post body parameters, 
query parameters, and structured responses of the official OpenAI API. 

The primary endpoints of an OpenAI-compatible HTTP API are as follows:

* ``/v1/chat/completions``: For conversational AI interactions. To send a new chat, POST a JSON request with parameters including: 

    1. ``messages``, as an array, with each message a JSON dictionary containing a ``content`` and a ``role`` attribute. Note that, 
       according to the OpenAI Documentation (see `Message roles and instruction following <https://platform.openai.com/docs/guides/text#message-roles-and-instruction-following>`_) 
       the role attribute is used to provide instructions to the model with different levels of authority. 
    2. ``model``, as a string, representing the id of the model to use. 
    3. (Optional) ``temperature``, as a float, controlling the randomness of the generated response; typically between 0 and 2, with lower 
       values indicating more determinism. 
    4. Additional optional arguments.. 

  The server will send a JSON reply with the following fields: 

    1. ``id``, as a string, a unique identifier for the request.
    2. ``object``, as a string, representing the type of object returned (usually ``chat.completion``)
    3. ``created``, as in int (Unix epoch) for the time when the response was generated. 
    4. ``choices``, as an array, where each object represents a possible response generated by the model. Additionally, for each 
       object in ``choices``, there will be a ``message`` object which contains a ``content`` object with the actual contents of the message. 
    5. ``usage``, as an object, containing information about the tokens used in the request. 

* ``/v1/embeddings``: For generating vector representations of text.
* ``/v1/models``: For listing available models.

For example, an HTTP request to the ``/v1/chat/completions`` endpoint might include a POST message body 
like the following: 

.. code-block:: python3 

    {
    "model": "course-model",
    "messages": [
        {
        "role": "system",
        "content": "Answer as a scientific teaching assistant."
        },
        {
        "role": "user",
        "content": "Explain self-attention in two sentences."
        }
    ],
    "temperature": 0.2,
    "max_tokens": 150
    }


and the HTTP response might look like: 

.. code-block:: python3 

    {
    "choices": [
        {
        "message": {
            "role": "assistant",
            "content": "Self-attention allows..."
        }
        }
    ]
    }    


Chat Templates 
^^^^^^^^^^^^^^
We know from our study of transformers that a model doesn't have a concept of "roles", "messages", etc. It 
merely takes an input string of tokens and returns a probability distribution predicting the next most likely 
token from the vocabulary. How then does an LLM process a request like the one above? 

The idea is to use a structured formatting rule to convert a list of structured conversational 
messages into a single, raw text string. This is sometimes called a *chat template* and typically 
makes use of special control characters, such as ``<|start_header_id|>`` and ``<|end_header_id|>``
(used by Llama 3) or ``[INST]`` and ``[/INST]`` used by Mistral. Note that the control characters 
must be part of the training data and training process (including the tokenizer, embedding, etc) 
and using different chat templates/control characters from the one the model was trained on will 
typically result in poor performance. 


Streaming Responses
^^^^^^^^^^^^^^^^^^^^

An important aspect of an LLM inference server is *streaming responses*. With streaming, the server 
sends partial or incremental parts of the response as the tokens are computed. This allows the 
client to receive the initial output more quickly than when not using streaming. 

Prompting 
---------

A prompt is the input supplied to the model for the current inference request. In a chat interface, 
it may contain several messages with different roles.

Prompt engineering, the  has become an entire area of study, and we will devote a substantial amount of the 
semester to studying how we can construct inputs so as to improve various aspects of the systems we build 
with AI. 

Our goal will be to construct prompts that make the objective or task and the associated constraints as 
precise an explicit as possible. Even with free-form prose, we can already see a difference between 
the quality of responses for a prompt like: 

  Tell me about the paper

versus 

  Using only the supplied abstract, identify the paper's primary contribution and one stated limitation. 
  If the abstract does not state a limitation, say that the available evidence is insufficient.

The second prompt defines the permitted evidence, the requested claims, the desired abstention behavior and 
the response scope. One of our goals this semester will be to make these as mathematically precise as possible. 

Decoding Strategies and Controls 
--------------------------------
We have seen that the output of an LLM is a probability distribution, i.e., a logit or score for 
every token in the vocabulary which softmax converts to a probability distribution. Thus, we must 
have a procedure to generate a sequence of output tokens. This is sometimes called the *decoding  
strategy* or *decoding procedure*. Some decoding procedures are deterministic while others are not. 

Deterministic Decoding Strategies: Greedy Decoding
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
These algorithms always pick the exact same sequence of tokens for a given prompt. An example is 
greedy decoding: this selected the highest-probability token at every step. 
It is fast and simple, but can cause the model to get stuck in repetitive 
loops or miss globally higher-probability sequences.


Sampling and Temperature
^^^^^^^^^^^^^^^^^^^^^^^^
Instead of a deterministic algorithm, we can use sampling. Sampling from a probability distribution 
involves use of a random number generator to select a token based on the associated probabilities. 
It is non-deterministic by design. Usually a sampling procedure, such as Top-:math:`k` sampling, 
is used to filter the distribution (in the case of Top-:math:`k`, only the :math:`k` most likely tokens 
from the distribution are selected from).

Temperature changes the shape of the probability distribution.
It essentially adjusts the "flatness" of the probability distribution before sampling by dividing 
the logits by some value, :math:`T`. A higher value of :math:`T > 1` squashes the distribution to make 
the more rare tokens closer to the more common tokens. Thus, a higher value of :math:`T` translates 
into more randomness. 

.. note::

    In the OpenAI-compatible API, it is common for a temperature of 0 to serve as a switch to 
    turn off sampling altogether and turn on a deterministic mechanism such as greedy decoding. 


Response Length and Stopping Controls 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
How many tokens should the model return? There are several factors and the client has some control. 
Typically, the length of the generated response depends on the following: 

* maximum output tokens --- this is a parameter set by the client, for example, ``max_tokens`` in 
  the ``/v1/chat/completions`` and ``max_completion_tokens`` in the newer ``/v1/responses`` endpoint. 
* End-of-sequence tokens --- anguage models emit a special control token, such as ``<|endoftext|>`` or 
  ``<|eot_id|>``, when they decide a response or sentence is complete. When such a token is returned, 
  the response is finished regardless of id the maximum output tokens has been hit. 
* The maximum context window size --- The max context window length controls not just the total input length but 
  the total *combined* length of the input and output. The reason is because generating the next token 
  requires the entire input and output tokens generated thus far. 
* Compute resources, particularly memory  

Hallucinations 
---------------
The term *hallucination* has become commonly used by the AI community. 
In this course, we will define *hallucination* to mean content generated by an AI system that is presented as 
supported or factual but is unsupported by the available evidence, inconsistent with that evidence, or fabricated.

Note that this includes output that directly contradicts provided source documents or examples in the context 
window (sometimes called *intrinsic hallucination*) as well as output, such as claims or citations, that cannot 
be verified to exist in an external source (sometimes called *extrinsic hallucination*).

Common examples of hallucinations 

* Inventing the title of a paper or other aspects of a citation 
* Answering a question in a way that contradicts the evidence provided in the context 
* Referring to a plausible but non-existent API field in a generated request 

Understanding the source of hallucinations and how to mitigate them is of vital importance 
an active area of research. Current research focuses on the different sources of hallucination 
corresponding to each of the three major phases of the model lifecycle: 

* Pre-training --- pre-training datasets contain false claims, satire, out-of-date facts, and 
  contradictory information; additionally, some facts occur rarely in the training distribution. 
  The maximum likelihood next token objective does not reward correctness. 
* Post-training or fine-tuning --- broadly, fine-tuning mechanisms do not always incentivize correctness. 
  For example, in RLHF, answers that are more confident, articulate, and well-structured may be preferred 
  over those that are more correct. With supervised fine-tuning for domain expertise, a model may be 
  trained on highly specialized question-answer pairs which exceeds its pre-training knowledge base. 
  This could condition the model to generate plausible-sounding answers even when it lacks the necessary 
  underlying factual foundation to make such claims.
* Inference and decoding --- Due to the sequential nature of token generation, a single single misinformed 
  or low-probability token early in generation distorts the attention context for all subsequent steps, 
  compounding errors further down the sequence. Moreover, strategies like sampling with temperature 
  introduce variance to increase creativity at the increased risk of additional hallucinations. 

A central question we wish to tackle this semester is how can we reduce hallucination and to what extent 
can we give formal proofs of correctness of our mitigation strategies?

Some strategies we will explore: 

* Supplying relevant factual evidence that we retrieve from a curated knowledge base as part of the prompt. 
* Allowing, and even encouraging, the system to abstain from answering when the necessary factual evidence 
  is not available. 
* Requiring factual evidence to support claims, and requiring explicit references (i.e., citations) to the 
  the evidence. 
* Deterministically checking that explicit references are valid. 
* Deterministically validating some claims using symbolic tools. 

It is important to underscore that none of these techniques automatically guarantees factual correctness. 
In fact, there are known theoretical limits on the extent to which hallucinations can be eliminated. 
For example, if we view the LLM as a finite-state machine over a bounded 
context length and vocabulary, results show that the hallucination problem has the 
worst computational complexity (i.e., NP-hard). Even worse, if we take the view that the LLM is a process 
that generates sequences over an unbounded domain, then by Rice's theorem one can show that hallucination is 
fundamentally undecidable. 
However, like all good heuristics, these mitigation strategies, when designed well, can greatly reduce the 
likelihood of certain kinds of hallucinations, as we will see.

Preview: Structured Responses 
-----------------------------

One of the key strategies we will use to reduce hallucination and improve reliability is the concept 
of *structured responses*. Instead of asking the LLM to generate free-form text, we require that it 
return a response conforming to some schema. For example, we could require a JSON object conforming to 
a JSONSchema. 

For example, in response to an input like "How many polymer grades were used in the experiment?", 
an LLM might return a JSON object like follows:  

.. code-block:: python3 

    {
    "answer": "The experiment used three polymer grades.",
    "citations": [
        "paper_04#results_02"
    ],
    "confidence": "medium"
    }    

Structured responses will allow us check for required versus optional fields, the types of 
each field, and so on. Moreover, with sufficient structure, we will be able to validate aspects 
of the response using deterministic tools. 

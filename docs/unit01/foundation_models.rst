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

1. 


Introduction to Foundation Models 
----------------------------------

So far, the models we have considered have largely been focused on an individual task;
for example, a model that could predict the tensile strength of a polymer or a CNN that could classify 
the article of clothing contained in a 28x28 grey-scale image. The model architecture and the dataset 
used to train the model were both designed with only a single task in mind. 

Foundation models, which have emerged only recently, within the last 6 or 7 years are fundamentally different. 
They are models that have been trained on a wide variety of data 
and at such a sufficient scale that they can be adapted or applied to many different tasks.

A foundation model is not necessarily a language model. Foundation models can operate on text, images, 
audio, biological sequences, scientific data, or combinations of several modalities. In this module though, 
we will focus primarily on large language models (LLMs).

A key aspect of foundation models is that they can be specialized for a variety of different tasks. 
Rather than training an independent model from scratch for sentiment analysis, summarization, 
question answering, and code generation, developers begin with a broadly training foundation model 
and adapt or prompt it for different tasks.

We should distinguish the following concepts: 

* Foundation model --- consisting primarily of its architecture and learned parameters;
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
Model developers choose an architecture comprised of a number of aspects including:

* parameter count -- Total number of trainable parameters in the model 
* context length -- The maximum size (number of tokens) of a single input
* hidden dimension -- The embedding dimension and, equivalently, the size of the input dimension of the feed-forward 
  network. 
* number of layers -- Total number of layers 
* attention mechanism -- Variants including masked/not masked (encoder/decoder), number of heads, etc. 

They also choose a training objective. For example, a decoder-only language model (masked attention) 
commonly uses *autoregressive next-token prediction* as the objective function. Autoregressive next-token 
prediction is a framework where a language model predicts the single most likely next token in a 
sequence given all previous tokens, feeding its own previous outputs back in as inputs for subsequent steps.
This method is a self-supervised learning method because the targets are constructed automatically from the 
data. 


Inference and HTTP APIs 
-----------------------


Prompting 
---------

Sampling and Controls 
---------------------

Hallucinations 
---------------

Preview: Structured Responses 
-----------------------------


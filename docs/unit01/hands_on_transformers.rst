Hands-On Transformers 
======================
In this module we look more closely at the ``transformers`` library and the HuggingFace Hub to get 
some hands-on experience working with some transformer models. 




Introduction to Pipelines 
-------------------------
As we mentioned briefly in the previous module, ``pipeline`` objects from the transformers library 
are basic abstractions that simplify interactions with large models. We'll look at the steps 
of a pipeline in more detail momentarily, but first let's see some basic examples.  

The simplest way to create a pipeline is to use the ``pipeline`` function and pass a specific 
task type. For example, we can create a pipeline by specifying text generation 
task type, ``text-generation``:

.. code-block:: python3

    from transformers import pipeline
    gen = pipeline("text-generation")

This bit of code first looks up the default model for this task type and checks whether that model 
has already been downloaded to your huggingface cache directory. If not, it downloads it to the 
cache directory and then instantiates the model. 

(Note that, by default, the huggingface cache directory is ``~/.cache/huggingface``, but you can 
change that by setting the ``$HF_HOME`` environment variable). 

.. note:: 

    The default model for the ``text-generation`` task type is pretty large and may take 
    a few moments to download. 


We can now pass it some input and directly get some output: 

.. code-block:: python3 

    gen("How was your day?")
    -> [{'generated_text': 'How was your day?  I had a pretty good one.  It was nice to get out of the 
    house and meet some new people.  I went to the 4th annual “The Green” event and it was really neat.  
    It was an environmental fair with vendors and booths and live music and lots of fun stuff for the kids.  
    It was a good way to spend a Saturday.  I hope I can go again next year.\n\nI also went to the local 
    farmers market with my daughter.  She was able to buy fresh produce and support local farmers.  
    She was really excited to have fresh veggies to cook with.  She’s learning about nutrition and healthy 
    eating at school, so this was a great way for her to learn by doing.  She was able to pick out her own f
    ruits and veggies and even make some healthy snacks.  She’s really taking to it and is getting excited 
    about cooking and meal planning.  That’s one of the things I’m most proud of, helping my kids develop 
    healthy eating habits.\n\nHow about you?  Did you do anything fun this weekend?  Did you support local 
    businesses or do something that promotes sustainability?  I’d love to hear about 
    it.\n\n#4thannualthegreen #environmentalfair #farms'}]

When we instantiated our pipeline, we got a message: 

.. code-block:: python3 

    No model was supplied, defaulted to HuggingFaceTB/SmolLM3-3B and revision a07cc9a.
    Using a pipeline without specifying a model name and revision in production is not recommended.
    Loading weights: 100%|████████████████████████████████████████████████████████████| 326/326 [00:00<00:00, 4231.15it/s]

In general it is better practice to set the model when invoking the ``pipeline``. For example, 

.. code-block:: python3 

    generator = pipeline(task="text-generation", model="distilbert/distilgpt2")
    result = generator("Artificial intelligence will", max_new_tokens=30,)
    print(result[0]["generated_text"])


We can pass it multiple inputs as well, as a Python list: 

.. code-block:: python3 

    results = generator(["Hello, my name is Joe", "Today was great because"])
    results 
    -> [[{'generated_text': 'Hello, my name is Joe Martin.\u202a\n\n\n\nMy name is Joe Martin.\u202a\n\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe Martin.\u202a\nMy name is Joe'}],
        [{'generated_text': 'Today was great because I was able to get a glimpse of how the new Star Wars characters are. This was the first time that a new character has appeared in my life.'}]]


The transformers library includes many recognized tasks with default models. There are task types 
from each of the following areas:

* Computer Vision, including text-to-image, image-to-text, and image-to-image tasks.
* Natural Language Processing, including sentiment analysis, language translation and question answering
  tasks. 
* Audio processing, including text-to-speech, audio classification and speech recognition tasks. 
* Multimodal, including document question and answering (i.e., answering questions on a visual document) 
  and visual question and answering (answering open-ended questions based on an image). 

More information is available on the HuggingFace documentation site, 
`here <https://huggingface.co/tasks>`_ ([2]). For a complete list of valid task definition 
strings, see the 
`pipeline API reference <https://huggingface.co/docs/transformers/en/main_classes/pipelines#transformers.pipeline.task>`_.

As we have seen, some tasks do not have a default model. Moreovew, some tasks, such as language translation,  
do not have a dedicated task type. Instead, only a more general task type is supported. For example, 
for a model that can translate English to Spanish, the task type is text generation. 

For these, we need to pass a specific model to use. Let's see how we can explore the HuggingFace
Hub to find such a model. 

HuggingFace Hub 
---------------

There are many models for English to Spanish translation available from the transformers 
library. How do we go about finding them? One option is to use the HuggingFace Hub to search 
for models by task. The transformers library can utilize any of the publicly available models on 
the hub. 

1. Navigate to the HuggingFace website, `here <https://huggingface.co/>`_. 
2. Click Models to browse and search for models. As of the time of this writing there are 
   over 3 million models on the hub, and that number is growing rapidly. As a point of reference, 
   in the Spring of 2025 when we taught this course there were 1.6 million model on the hub.  
3. Click to filter by task type; we would like to search for models that can perform the 
   "Translation" task type, so we click that. 
4. Next, select the "Languages" filter tab to filter by languages. We are interested in English to 
   Spanish, so we select those. 

.. figure:: ./images/HF_Hub_1.png
    :width: 700px
    :align: center

    The models associated with the "Translation" task type. 

This should filter the list of models down to around 857 models. We can see the task associated with 
each of the models ("Translation" in this case) as well as the number of downloads, 
and the number of hearts. By clicking a model, we can see more information about it. 

.. figure:: ./images/HFH-en-sp.png
    :width: 700px
    :align: center

    Translation models that include English and Spanish. 

Let's select the ``facebook/nllb-200-distilled-600M`` model. By clicking it we are taken to the main 
page for the model. There we can see the *model card* for the model. A model card is an idea that 
is gaining traction in the ML community. It is a separate file that accompanies the model and provides 
additional metadata about it. On HuggingFace, model cards are always captured in markdown, contained 
in a file called README.md.

.. figure:: ./images/HF_Hub_mc.png
    :width: 700px
    :align: center

    The model card for the the ``facebook/nllb-200-distilled-600M`` model. 

This particular model card includes information such as the number of parameters, intended use,
and the performance 
of the model on different *benchmarks*. More about benchmarks in a future lecture. 

On the Files and Versions tab, we can see the actual physical files associated with the model. On 
the HuggingFace Hub, models are just git repositories containing files. Note that the actual 
serialized model has been made available for pytorch (the ``pytorch_model.bin`` file) and there 
is information about the tokenizer it uses (the ``tokenizer_config.json`` file).
We also see the README.md file which is the model's model card.  

.. figure:: ./images/HF_Hub_files.png
    :width: 700px
    :align: center

    The git repository of files for the the ``facebook/nllb-200-distilled-600M`` model. 

.. .. Working With Model IDs
.. .. ^^^^^^^^^^^^^^^^^^^^^^^

.. .. Let's use this model in some code. We can use the same ``pipeline()`` function as before, 
.. .. but this time we'll use the ``model=`` argument to specify the model we want to use. Models on the 
.. .. HuggingFace Hub have ids similar to docker container images, where a namespace indicates the user 
.. .. or organization that created and owns the model. The namespace precedes the name of the model itself. 
.. .. Note that, also like DockerHub, some models do not have a namespace. These are models that are 
.. .. maintained by HuggingFace itself, as opposed to the community. For example, 
.. .. ``distilbert-base-uncased`` is a model ID without a namespace while 
.. .. ``google-bert/bert-base-uncased`` is a model ID associated with the ``google-bert`` 
.. .. `organization <https://huggingface.co/google-bert>`_.

.. .. When there is a namespace, the namespace and the model name are separated by a ``/`` character, 
.. .. as in ``<name_space>/<model_name>`` (this is the same as on the Docker Hub). 
.. .. In our langauge translation model example above, ``facebook`` is the namespace and 
.. .. ``nllb-200-distilled-600M`` is the model name. The ``facebook`` namespace is owned by 
.. .. AI at Meta, see 
.. .. `here <https://huggingface.co/facebook>`_ for more details. 


.. .. code-block:: python3 

..     en_sp_translator = pipeline(model="facebook/nllb-200-distilled-600M")
..     # we need to set the src_lang and tgt_lang, if we don't we'll get an error
..     en_sp_translator("Hello, my name is Joe.", src_lang="en", tgt_lang="es")
..     -> [{'translation_text': 'Hola, mi nombre es Joe.'}]

.. Note the use of the ``src_lang`` and ``tgt_lang`` parameters. What happens if you don't supply those? 
.. Why do you think those might be required? 

.. And we don't need to restrict ourselves to text tasks. We can use computer vision models just 
.. as easily with the ``pipeline()`` function. Let's see an example of the "image-to-text" task. 

.. .. note::

..     In order to use the image models, you will need to install the ``pillow`` package, i.e., 
..     ``! pip install pillow``. You will then need to restart your kernel. 

.. .. code-block:: python3 

..     # create a pipeline with the default model for the task 
..     image_to_text = pipeline('image-to-text')

..     # use the model on an image; in this case we can simply pass it the path to a file
..     image_to_text("../data/panda.jpeg")
..     -> [{'generated_text': 'a large black and white teddy bear sitting on a tree branch '}]


.. .. figure:: ./images/image-to-text-panda.png
..     :width: 700px
..     :align: center

..     The panda.jpeg image passed to the image_to_text pipeline. 

.. A nice reminder that models are not perfect! 


Model Architectures and Checkpoints
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

HuggingFace distinguishes model *architectures* from *checkpoints*; the former represents 
the structure of the model (e.g., how many layers, how many trainable parameters, etc.) 
while the latter includes both the architecture and the trained parameters (i.e., weights). 
For example, BERT is a model architecture while ``google-bert/bert-base-uncased`` is a model 
checkpoint. Note that when we say *model*, we usually mean a model checkpoint, but sometimes 
there can be ambiguity. 

Components of a Pipeline
------------------------
In general, the following
steps must be taken to perform inference with a model on some input text: 

1. Convert the raw text to tokens (i.e., *input ids*) using a *tokenizer*.
2. Apply the model to the input ids to produce *logits*, that is, raw numeric values.  
3. Post-process the outputs of the model to produce probabilities (e.g., through the application 
   of *softmax*) and then class labels. 

These high-level steps are depicted in the diagram below: 

.. figure:: ./images/HF_pipeline.png 
    :width: 500px
    :align: center

    The basic components of a pipeline. 
    (Image credit: HuggingFace NLP Course: Behind the Pipeline [1])

Each step involves multiple complexities that we will explain. We will begin with the tokenizer. 


Tokenizers
----------
As mentioned above, the tokenizer converts raw text to a series of (integer) token ids. There 
are various methods for implementing tokenizers. Just like any other data preprocessing method, it is 
critical that the exact steps used to tokenize the text for training are also used for 
inference. Thus, in general, we associate a specific tokenizer to each model version/checkpoint. 

We'll work with the ``bert-base-uncased`` model checkpoint to illustrate the concepts. This model is 
the BERT base model introduced in the 2018 paper 
`BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding <https://arxiv.org/abs/1810.04805>`_.
You can read more about the model from its model card, `here <https://huggingface.co/google-bert/bert-base-uncased>`_.

The transformers library provides the ``AutoTokenizer`` class to simplify loading the tokenziers 
associated with a model. Specifically, the ``from_pretrained()`` method can be used to load the 
tokenizer in one command: 

.. code-block:: python3 

    from transformers import AutoTokenizer
    checkpoint = "bert-base-uncased"
    tokenizer = AutoTokenizer.from_pretrained(checkpoint)

The transformers class has instantiated a tokenizer that 
we can immediately use on a sentence to get a sense of how it works: 

.. code-block:: python3 

    d = tokenizer("The food was good, not bad at all.")
    print(d)
    ->
    {'input_ids': [101, 1996, 2833, 2001, 2204, 1010, 2025, 2919, 2012, 2035, 1012, 102], 
     'token_type_ids': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
     'attention_mask': [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    }

A dictionary is returned with three keys; ``input_ids`` are the tokens returned for our input sentence. 
We'll discuss the other keys in a minute. We can also turn the IDs back to tokens; we use the 
``convert_ids_to_tokens()`` method to do that:

.. code-block:: python3 

    tokenizer.convert_ids_to_tokens(d['input_ids'])
    ->
    ['[CLS]',
    'the',
    'food',
    'was',
    'good',
    ',',
    'not',
    'bad',
    'at',
    'all',
    '.',
    '[SEP]']    

We see that in addition to handling the words and punctuation, two "special" tokens were inserted:
the ``[CLS]`` and ``[SEP]`` tokens. If we look at the 
`Training Procedure <https://huggingface.co/google-bert/bert-base-uncased#training-procedure>`_ 
section on the model card, we see that the model was trained in part on the following task: 
given two sentences, sentence A and sentence B, predict whether sentence A and B correspond to 
two consecutive sentences in the original text. The model was shown a mix of both consecutive
sentences and sentences that were not consecutive as part of training. In order to structure the 
input, the special ``[CLS]`` and ``[SEP]`` tokens were inserted, as follows: 

.. code-block:: bash 

    [CLS] Sentence A [SEP] Sentence B [SEP]

The tokenizer allows us to mimic this procedure --- we simply pass a pair of sentences as 
individual arguments to the tokenizer: 

.. code-block:: python3 

    d2 = tokenizer("The food was good, not bad at all.", "The food was bad, not good at all.")
    print(d2) 
    -> 
    {'input_ids': [101, 1996, 2833, 2001, 2204, 1010, 2025, 2919, 2012, 2035, 1012, 102, 
                        1996, 2833, 2001, 2919, 1010, 2025, 2204, 2012, 2035, 1012, 102], 
     'token_type_ids': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], 
     'attention_mask': [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    }

You are probably speculating that the separators have been inserted between the sentences based on those 
token id's at the beginning and end of the ``input_ids`` lists. We can confirm 
it by using the ``convert_ids_to_tokens()`` function:

.. code-block:: python3 

    tokenizer.convert_ids_to_tokens(d2['input_ids'])
    ->
    ['[CLS]',
    'the',
    'food',
    'was',
    'good',
    ',',
    'not',
    'bad',
    'at',
    'all',
    '.',
    '[SEP]',
    'the',
    'food',
    'was',
    'bad',
    ',',
    'not',
    'good',
    'at',
    'all',
    '.',
    '[SEP]']

This explains the ``token_type_ids`` as well --- the type tracks whether the token belonged to the 
first sentence (value 0) or the second (value 1). 

Batching Inputs 
^^^^^^^^^^^^^^^
In addition to accepting *two different* input arguments, as in the example above, the tokenizer objects can 
also accept *batches* of inputs, provided as a single list argument. For example: 

.. code-block:: python3 

    tokenizer(["The food was good, not bad at all.", "The food was bad, not good at all."])
    ->
    {'input_ids': [[101, 1996, 2833, 2001, 2204, 1010, 2025, 2919, 2012, 2035, 1012, 102], 
                   [101, 1996, 2833, 2001, 2919, 1010, 2025, 2204, 2012, 2035, 1012, 102]], 
     'token_type_ids': [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]], 
     'attention_mask': [[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]]}    

Notice how, in this case, ``the token_type_ids``   all have value 0. That is because fundamentally we are using 
a different API when we pass a *single* Python list argument: we are using the batch API. 


Returning Tensors 
^^^^^^^^^^^^^^^^^

The ``input_ids`` object is very close to the type of object that can be fed directly into the 
model, but we need to make two small changes to it first; those are: 

1. We need to return tensor objects, in one of the supported deep learning frameworks, such as 
   Pytorch or TensorFlow. 
2. We need to pad the list of ``input_ids`` with an extra dimension, because the model object 
   presents a batch API. 

We can accomplish both of these by using the ``return_tensors`` argument, passing a string representing 
the framework we want returned, with ``"pt"`` for Pytorch, ``"tf"`` for TensorFlow, etc. 

.. code-block:: python3 

    d = tokenizer("The food was good, not bad at all", return_tensors="pt")
    tensors = d['input_ids']
    print(type(tensors), tensors.shape) 
    print(tensors)
    -> <class 'torch.Tensor'> torch.Size([1, 11])
    -> tensor([[ 101, 1996, 2833, 2001, 2204, 1010, 2025, 2919, 2012, 2035,  102]])
       

Note the 2-dimensions, both in the shape and the output of the ``tensors`` object itself --- 
there are double open and closed brackets (i.e., ``[[`` and ``]]``).

Returning Tensors from the Batch API and Using Padding 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Just as in the example above, we can ask for tensors to be returned when using the batch API of the 
tokenizer via the same ``return_tensors`` parameter. However, we have to be careful; if the inputs are 
different sizes, we can run into issues. Let's look at the following example: 

.. code-block:: python3 

    tokenizer(["The food was good", "The food was bad, not good at all."], return_tensors='pt')
    
If we try to execute the code above, we get the following exception: 

.. code-block:: bash 

    -> ValueError: Unable to create tensor, you should probably activate truncation and/or padding...

The issue is that our transformer model, like all ANNs, require rectangular inputs, but since the inputs 
are different length, we get an issue trying to convert to a (rectangular) tensor. 

We can get around this problem by passing ``padding=True``; e.g., 

.. code-block:: python3 

    tokenizer(["The food was good", "The food was bad, not good at all."], return_tensors='pt', padding=True)
    -> 
    {'input_ids': tensor([[ 101, 1996, 2833, 2001, 2204,  102,    0,    0,    0,    0,    0,    0],
                          [ 101, 1996, 2833, 2001, 2919, 1010, 2025, 2204, 2012, 2035, 1012,  102]]), 
     'token_type_ids': tensor([[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]), 
     'attention_mask': tensor([[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
                               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]])}
    

What's happened here is that transformers has adding *padding*, i.e., a special token, to the first, shorter 
input to make it have the same length as the second input --- note the 0s at the end of the first tensor in the 
``input_ids`` object. We can also see the actual tokens used 

.. code-block:: python3 

    d3 = tokenizer(["The food was good", "The food was bad, not good at all."], padding=True)
    tokenizer.convert_ids_to_tokens(d3['input_ids'][0])
    -> 
    ['[CLS]',
    'the',
    'food',
    'was',
    'good',
    '[SEP]',
    '[PAD]',
    '[PAD]',
    '[PAD]',
    '[PAD]',
    '[PAD]',
    '[PAD]']


Finally, this also explains the last object returned, the ``attention_mask``. This object encodes which 
elements of the ``input_ids`` vector should be ignored (or "masked") when fed through the network. We do not 
want the padding tokens to be interpreted as part of the original input data so we mask them from the model.

If we look back at the output above, we see the mask has a 0 in each of the elements where the original 
input vector had a padding token. 

.. code-block:: python3

    {'input_ids': tensor([[ 101, 1996, 2833, 2001, 2204,  102,    0,    0,    0,    0,    0,    0],
                          [ 101, 1996, 2833, 2001, 2919, 1010, 2025, 2204, 2012, 2035, 1012,  102]]), 
    'attention_mask': tensor([[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
                              [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]])}


Let's capture the tensors in an object for later use: 

.. code-block:: python3 

    d4 = tokenizer(["The food was good", "The food was bad, not good at all."], return_tensors='pt', padding=True)
    tensors = d4['input_ids']


Models from Checkpoints and Language Embeddings 
------------------------------------------------

The tensors we computed in the previous section can be fed directly into the model associated with 
the original ``checkpoint``. We use the ``AutoModel`` class and the ``from_pretrained()`` method, 
analogous to how we instantiated the tokenizer: 

.. code-block:: python3 

    from transformers import AutoModel
    model = AutoModel.from_pretrained(checkpoint)

    # feed our tensors example directly into the model 
    model(tensors)
    
We get a ``BaseModelOutput`` object which includes a large set of tensors:

.. code-block:: shell 

    BaseModelOutputWithPoolingAndCrossAttentions(last_hidden_state=tensor([[[-0.0231, -0.0906, -0.2436,  ..., -0.1892,  0.3635,  0.2982],
            [-0.2885, -0.8670, -0.8317,  ..., -0.1848,  0.9399,  0.2939],
            [ 0.0991, -0.4587,  0.3661,  ..., -0.0423, -0.0259,  0.0489],
            ...,
            [-1.2494, -0.4512, -0.0637,  ...,  0.2568,  0.7048, -0.2646],
            [ 0.5333,  0.0407, -0.4287,  ...,  0.4020, -0.3481, -0.4612],
            [ 0.5275,  0.2445,  0.0053,  ...,  0.3517, -0.5527, -0.3193]]],
        grad_fn=<NativeLayerNormBackward0>), pooler_output=tensor([[-8.9383e-01, -4.4092e-01, -9.1071e-01,  7.6117e-01,  6.6928e-01,
            -4.6003e-02,  9.2318e-01,  2.5568e-01, -8.2578e-01, -9.9998e-01,    
    . . .

We can also apply the ``embeddings.word_embeddings()`` method of the model directly to our
tokens to see the language embeddings: 

.. code-block:: python3 

    print(model.embeddings.word_embeddings(tensors))
    -> 
    tensor([[[ 0.0136, -0.0265, -0.0235,  ...,  0.0087,  0.0071,  0.0151],
         [-0.0446,  0.0061, -0.0022,  ..., -0.0363, -0.0004, -0.0306],
         [-0.0179, -0.0035, -0.0022,  ..., -0.0005,  0.0112, -0.0379],
         ...,
         [-0.0546,  0.0065, -0.0213,  ...,  0.0427,  0.0057, -0.0381],
         [-0.0207, -0.0020, -0.0118,  ...,  0.0128,  0.0200,  0.0259],
         [-0.0145, -0.0100,  0.0060,  ..., -0.0250,  0.0046, -0.0015]]],
       grad_fn=<EmbeddingBackward0>)

At this point we have performed the first two steps of the inference process. We need to post-process the output, 
and for that we need to discuss different model heads. 

Model Heads and Post-processing
--------------------------------

When we used ``AutoModel.from_pretrained()``, we loaded the base model which produces, for each input, an output 
vector of relatively high dimension, called the *hidden states* or the *features* for the input. We can think 
of this output as the associated "features" of the input, computed from the model's "understanding" of the 
structure of language. 

But we cannot use these features directly in any NLP task. For that, we need to supply an extra layer to the 
model, called a *head*, for the specific task we are interested in. The inputs to the head will be the outputs 
of the base model, i.e., the output of the last hidden layer.

We can get the shape of an output using the output's ``last_hidden_state`` attribute, like so: 

.. code-block:: python3 

    inputs = tokenizer("The food was good, not bad at all.", return_tensors="pt")['input_ids']
    output = model(inputs)
    output.last_hidden_state.shape
    -> torch.Size([1, 12, 768])

The dimensions returned are as follows:

* *batch size* -- how many inputs were processed at a time; (in our case, 1 sentence).
* *sequence length* -- the length of the numerical representation of the sequence. 
* *hidden size* -- the vector dimension of the hidden state. 

Instead of using the ``AutoModel`` class to load the base model, we can use a different class to load a model 
checkpoint with a specific task head. 
For example, we can use the ``AutoModelForSequenceClassification`` class to load the same BERT model 
checkpoint but with a classification task head added. 

.. code-block:: python3 

    from transformers import AutoModelForSequenceClassification
    model = AutoModelForSequenceClassification.from_pretrained(checkpoint)

If we run the code above, we get a note: 

.. code-block:: bash 

    - MISSING:	those params were newly initialized because missing from the checkpoint. 
    Consider training on your downstream task.

This warning is telling us that our base checkpoint did not include such a task head, so transformers initialized 
a random one. Thus, we should not expect good performance from this model. Instead we should fine-tune the 
model using a labeled dataset. We'll look at that next time. 

Instead, let's load a different checkpoint from the HuggingFace Hub, one that has already been fine-tuned with  
a classification head. We'll use the ``distilbert-base-uncased-finetuned-sst-2-english`` checkpoint; you 
can read more about it 
`here <https://huggingface.co/distilbert/distilbert-base-uncased-finetuned-sst-2-english>`_.


.. code-block:: python3 

    # use the fine-tuned checkpoint 
    checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"
    
    # load the tokenizer 
    tokenizer = AutoTokenizer.from_pretrained(checkpoint)
    
    # tokenize the input
    inputs = tokenizer("The food was good, not bad at all.", return_tensors="pt")['input_ids']
    
    # load the model from the checkpoint
    model2 = AutoModelForSequenceClassification.from_pretrained(checkpoint)
    
    # compute the output using the new model
    outputs = model2(inputs)    
    -> SequenceClassifierOutput(loss=None, logits=tensor([[-3.9782,  4.3248]], grad_fn=<AddmmBackward0>), 
        hidden_states=None, attentions=None)

Note that we are reinitializing the ``tokenizer`` object associated with the new checkpoint, and 
we are recomputing the inputs based on that tokenizer. This is strictly speaking important, as each 
model could in theory use a different tokenizer. 

We see that the output is now a ``SequenceClassifierOutput``, which has a ``logits`` attribute with a shape: 

.. code-block:: python3 

    outputs.logits.shape
    -> torch.Size([1, 2])

    outputs.logits
    -> tensor([[-3.9782,  4.3248]], grad_fn=<AddmmBackward0>)

Note that these are not probabilities but the raw outputs from the model; to convert them to probabilities, we 
need to normalize them with the softmax function. We can use the pytorch or tensorflow. Below we use pytorch 
since we had previously asked for pytorch tensors: 

.. code-block:: python3 

    import torch
    predictions = torch.nn.functional.softmax(outputs.logits, dim=-1)
    print(predictions)    
    -> tensor([[2.4772e-04, 9.9975e-01]], grad_fn=<SoftmaxBackward0>)

These are the probabilities of the labels the model is predicting for our sentence. We can use the model's
``config.id2label`` attribute to see the labels it is using: 

.. code-block:: python3 

    model2.config.id2label
    -> {0: 'NEGATIVE', 1: 'POSITIVE'}

Thus, we see that the model has classified the sentence as positive with 99.97% confidence. We can wrap this up 
into a simple post-processing function that is batch-ready, as follows: 

.. code-block:: python3 

    def get_prediction(logits):
        results = []
        predictions = torch.nn.functional.softmax(logits, dim=-1)
        for p in range(len(predictions)):
            if predictions[p][0] > predictions[p][1]:
                results.append(model2.config.id2label[0])
            else:
                results.append(model2.config.id2label[1])
        return results

**Exercise.** Let's bring everything together in a single coding exercise. The goal here is to call the 
entire, end-to-end process on a set of inputs. We'll break it down into a series of 5 steps. 
Try coding up the following:

1. Create a Python list of 5 or 6 input sentences to try the model on. 
2. Tokenize the inputs, making sure to generate tensors that can be passed to the model. (Hint: which API are you 
   using from the tokenizer? Do you need to do anything special to get input_ids that can be passed to the model?)
3. Pass the tokens output in step 2 to the model to get the raw logits. 
4. Pass the logits returned from the model in step 3 to our post-processing function, defined above, to produce 
   the predictions for each sentence. 
5. Display the predictions. 


**Solution.** Here is a solution. 


.. code-block:: python3 

    # a list of inputs to try our model on
    inputs = ["I am happy", "I am sad", "This is good", "This is bad", "I enjoyed the pizza", "I am worried about the exam"]

    # tokenize the inputs; we'll need to use padding here, and we'll just grab the input_ids object
    tokens = tokenizer(inputs, return_tensors="pt", padding=True)['input_ids']

    # pass the tokens through the model
    outputs = model2(tokens)

    # get predictions from our model outputs using the post-processing function
    predictions = get_prediction(outputs.logits)

    # print the prediction
    for i in range(len(inputs)):
        print(f"Sentence: {inputs[i]}; prediction: {predictions[i]}");


Instantiating Models and Tokenizers 
------------------------------------

One final comment: in some cases the ``pipeline`` constructor does not use the correct tokenizer 
when instantiating the model. For example, look what happens with the following code: 

.. code-block:: python3

    from transformers import pipeline 
    model_name = "Helsinki-NLP/opus-mt-en-es"
    translator = pipeline(task="text-generation", model=model_name)

The instantiation works fine, but what happens when we try to use it? 

.. code-block:: python3 
    translator("Hello, my name is Joe")
    --> [{'generated_text': 'Hello, my name is Joe SO SO SO SO SO SO SO SO EI SO SO SO EI SO...'}]

The results are not correct at all! The transforms library has not used the correct tokenizer for 
this model. 

Instead, we can first create the correct tokenizer and then use that to process the text 
directly before passing it into the model. The key point is that we use ``AutoTokenizer`` to 
let HFH derive the correct tokenizer for this model based on its metadata 
(specifically, the `config.json <https://huggingface.co/Helsinki-NLP/opus-mt-en-es/blob/main/config.json?utm_source=chatgpt.com>`_). Similarly, we use ``AutoModelForSeq2SeqLM`` 
to instantiate the model object from the name. 
Also, we use ``model.generate()`` directly instead of 
the ``pipeline`` object. The code is a little more complicated, but it produces the correct results: 

.. code-block:: python3 

    from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

    model_name = "Helsinki-NLP/opus-mt-en-es"

    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_name)

    inputs = tokenizer(
        "Hello, my name is Joe.",
        return_tensors="pt",
    )

    output_ids = model.generate(**inputs)

    translation = tokenizer.decode(
        output_ids[0],
        skip_special_tokens=True,
    )

    print(translation)

    --> Hola, mi nombre es Joe.




Additional References 
---------------------
1. HuggingFace NLP Course. Chapter 2: Behind the Pipeline. https://huggingface.co/learn/nlp-course/chapter2/2
2. HuggingFace Tasks. https://huggingface.co/tasks

.. Hands-On 
.. ---------

.. We'll use the ``transformers`` library to illustrate some of the above concepts with concrete examples. 
.. The ``transformers`` library was developed by HuggingFace, a company that is building an open source, 
.. collaborative platform for AI. 

.. Tokenizers 
.. ^^^^^^^^^^

.. We'll begin by illustrating a tokenizer. As mentioned above, the tokenizer converts raw 
.. text to a series of (integer) token ids. There are various methods for implementing tokenizers, but 
.. it is critical that the exact steps used to tokenize the text for training a model are also used for 
.. inference. Thus, in general, we associate a specific tokenizer to each model version.

.. The ``transformers`` library provides the ``AutoTokenizer`` class for automatically instantiating
.. the correct tokenizer for a given model. In the code below, we instantiate a tokenizer associated 
.. with the GPT-2 model. This is just for illustration purposes, but note that you can replace the 
.. ``gpt2`` string with any valid model id from HuggingFace. 

.. .. code-bloc:: python3

..     from transformers import AutoTokenizer
..     model_name = "gpt2"
..     tokenizer = AutoTokenizer.from_pretrained(model_name)

.. We can use ``tokenizer`` to tokenize any piece of text: 

.. .. code-block:: python3 

..     text = "Tokenization breaks text into subword units!"
..     ids = tokenizer(text)
..     print(ids["input_ids"])
..     --> [30642, 1634, 9457, 2420, 656, 850, 4775, 4991, 0]

.. We can also convert the IDs back to text: 

.. .. code-block:: python3 

..     tokens = tokenizer.convert_ids_to_tokens(ids["input_ids"])
..     print(tokens)
..     --> ['Token', 'ization', 'Ġbreaks', 'Ġtext', 'Ġinto', 'Ġsub', 'word', 'Ġunits', '!']

.. Note how certain words are broken down into multiple tokens. What do you think is the 
.. meaning of the ``Ġ`` character? 


.. Language Embedding 
.. ^^^^^^^^^^^^^^^^^^^
.. Next we compute the language embedding for some token IDs. In this case, we need the actual 
.. model because the language embedding is one of the components of the trained model. 
.. We'll use the ``AutoModel.from_pretrained`` constructor from ``transformers`` to automatically 
.. instantiate a model from the its model ID. As we mentioned before, it is crucial that use the 
.. same tokenizer that was used to train the model. 


.. .. code-block:: python3 

..     import torch
..     from transformers import AutoTokenizer, AutoModel
..     import torch.nn.functional as F

..     # Load tokenizer and model 
..     model_name = "gpt2"
..     tokenizer = AutoTokenizer.from_pretrained(model_name)
..     model = AutoModel.from_pretrained(model_name)

..     # Extract just the embedding matrix, i.e., the W_E above 
..     embedding_matrix = model.wte.weight

.. With the embedding matrix extracted, we can write a short function to compute the embeddings
.. of a given word. We use the ``tokenizer.encode`` with ``return_tensors`` just to ensure the 
.. token_ids are returned wrapped 

.. .. code-block:: python3 

..     # function to compute the embedding of a word 
..     def get_word_embedding(word: str) -> torch.Tensor:
..         input_ids = tokenizer.encode(word, return_tensors="pt")
..         # Retrieve vector from matrix: shape [1, 768]
..         vector = embedding_matrix[input_ids[0, 0]]
..         return vector

.. Let's try our function with some examples. Note that we are encoding the words 
.. with a single space at the beginning. 

.. .. code-block:: python3 

..     # try with some examples: 
..     # NOTE: we add a space at the beginning. What happens if we remove this?
..     king_emb = get_word_embedding(" king")
..     queen_emb = get_word_embedding(" queen")
..     phone_emb = get_word_embedding(" phone")

..     # compute and print cosine similarities 
..     sim_king_queen = F.cosine_similarity(king_emb, queen_emb, dim=0).item()
..     sim_king_phone = F.cosine_similarity(king_emb, phone_emb, dim=0).item()
..     sim_queen_phone = F.cosine_similarity(queen_emb, phone_emb, dim=0).item()

..     # print results 
..     # 3. Print Results
..     print("--- Cosine Similarities ---")
..     print(f"king  <-> queen : {sim_king_queen:.4f}  (High Similarity / Small Angle)")
..     print(f"king  <-> phone : {sim_king_phone:.4f}  (Low Similarity / Large Angle)")
..     print(f"queen  <-> phone : {sim_queen_phone:.4f}  (Low Similarity / Large Angle)")

.. You should see outputs similar to the following: 

.. .. code-block:: python3 

..     --- Cosine Similarities ---
..     king  <-> queen : 0.6573  (High Similarity / Small Angle)
..     king  <-> phone : 0.2040  (Low Similarity / Large Angle)
..     queen  <-> phone : 0.1695  (Low Similarity / Large Angle)    

.. If we change the input words by removing the leading space (i.e., use "king" instead of " king", etc.), then 
.. the similarities between all of the words goes down, for example: 

.. .. code-block:: python3 

..     king_emb = get_word_embedding("king")
..     queen_emb = get_word_embedding("queen")
..     phone_emb = get_word_embedding("phone")

..     # compute and print cosine similarities
..     sim_king_queen = F.cosine_similarity(king_emb, queen_emb, dim=0).item()
..     sim_king_phone = F.cosine_similarity(king_emb, phone_emb, dim=0).item()
..     sim_queen_phone = F.cosine_similarity(queen_emb, phone_emb, dim=0).item()

..     print("--- Cosine Similarities ---")
..     print(f"king  <-> queen : {sim_king_queen:.4f}  (High Similarity / Small Angle)")
..     print(f"king  <-> phone : {sim_king_phone:.4f}  (Low Similarity / Large Angle)")
..     print(f"queen  <-> phone : {sim_queen_phone:.4f}  (Low Similarity / Large Angle)")

..     --> 
..     --- Cosine Similarities ---
..     king  <-> queen : 0.2666  (High Similarity / Small Angle)
..     king  <-> phone : 0.2873  (Low Similarity / Large Angle)
..     queen  <-> phone : 0.1791  (Low Similarity / Large Angle)

.. This is likely due to the token frequency of " king" and " queen" in the training dataset as compared 
.. to that of the same tokens without a space. 

.. Attention 
.. ^^^^^^^^^

.. Let's look at an example of attention. To begin, we'll load the tokenizer and model using ``transformers``. 

.. .. code-block:: python3 

..     import torch
..     from transformers import AutoTokenizer, AutoModel

..     tokenizer = AutoTokenizer.from_pretrained("gpt2")
..     model = AutoModel.from_pretrained("gpt2", output_attentions=True)
..     model.eval()

.. Let's compute a simple example. We'll use the sentence *"Bank approved the loan"* and look 
.. at the attentions for the word *loan*. 

.. .. code-block:: python3 

..     text = "Bank approved the loan"
..     inputs = tokenizer(text, return_tensors="pt")

..     with torch.no_grad():
..         outputs = model(**inputs)

..     # Extract final layer attention and average across heads
..     last_layer_attentions = outputs.attentions[-1][0]
..     mean_attention = last_layer_attentions.mean(dim=0)

..     # Format tokens
..     tokens = tokenizer.convert_ids_to_tokens(inputs["input_ids"][0])
..     tokens = [t.replace("Ġ", "") for t in tokens]

..     # Print attention distribution when processing 'loan'
..     target_idx = tokens.index("loan")
..     print(f"Attention weights when processing '{tokens[target_idx]}':\n")

..     for i, token in enumerate(tokens[:target_idx + 1]):
..         weight = mean_attention[target_idx, i].item()
..         print(f"  -> '{token:<8}': {weight:.4f}")    
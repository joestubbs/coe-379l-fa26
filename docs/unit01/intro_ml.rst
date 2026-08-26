Introduction to Machine Learning
================================

In this module, we introduce the basic vocabulary and mathematical abstractions that 
make up machine learning. 

By the end of this module, students should be able to:

1. Understand at high level the 3 primary paradigms in ML and distinguish 
   supervised, unsupervised, and reinforcement-learning problems.
2. Identify observations, features, labels, predictions, parameters, and hyperparameters. 
3. Distinguish regression from classification.
4. Describe model training as parameter selection that reduces a loss. 
5. Recognize the basic computational form of an artificial neuron. 

What is Machine Learning?
-------------------------

Machine Learning (ML) is a field of Computer Science and Artificial Intelligence (AI) that develops 
algorithms to analyze and infer patterns in data.

The idea is that algorithms can discover patterns in existing datasets, and these patterns can 
be encoded in a model which can then by applied to new data. 

There are many examples of ML models. Here are just a few to give you a flavor:

1. Given a string of text, predict the next word. 
2. Given an image, determine if it contains a human face. 
3. Given an image of a home or building from the aftermath of a storm, classify the damage done 
   to the structure as "none", "small", or "large".
4. Given a text description of an image, generate an image that "matches" the description. 
5. Given details about a real estate property, such as address, square footage, number of rooms, 
   etc., predict its market value. 
6. Given an image of a crop, determine if the crop has a disease; similarly, determine if the crop
   requires irrigation. 


At a high level, the process is something like:

1. Find or collect raw data about the process or function.
2. Prepare the data for model training or fitting. 
3. Train the model using some of the prepared data. 
4. Validate the model using some of the prepared data. 
5. Deploy the model to analyze new data samples.

The Primary Learning Paradigms 
-------------------------------

We can categorize the primary paradigms that have historically been used in ML into three classes based 
on the type of feedback signal used to train the model:

1. *Supervised learning* ---  The dataset is labeled with “correct” values prior to doing the learning.
2. *Unsupervised learning* --- The dataset used for training does not contain no correct labels; 
   the learning algorithm must infer patterns 
3. *Reinforcement learning* --- The model "learns" through trial and error to optimize a “rewards” function.

There is also a fourth paradigm that has emerged recently called *self-supervised learning*. It is a kind of 
hydrid between supervised and unsupervised learning where an automated method generates its own labels 
from raw, unlabeled data before training the model. Various tricks are used to "label" the data, 
such as:

* Hiding some portion of the data from the model during training and using the "hidden" portion as the label. 
  For example, for the sentence completion task, using full sentences found on the internet but hiding 
  the end of the sentence from the model. 
* Similarly, for vision tasks, one can remove portions of an image and ask the model to try and predict the 
  missing pixels. 
* For video data, show the model the first *n* frames and ask it to predict the *n+1*-st frame. 

Let's look at some examples:

1. Suppose we have historical weather data for Austin containing the average daily temperature for each calendar day. 
   We want to train a model to predict the average Austin temperature based on the day using this dataset.
2. Suppose we to train a model to distinguish between healthy and unhealthy crops, and support we have a set of 
   images with some images containing healthy crops and others containing unhealthy crops. We want to train a model 
   to distinguish healthy from unhealthy crops based on the images alone. 
3. We want to train a model to operate the equipment in an industrial engineering laboratory. Operating the 
   equipment involves commands that impact the energy consumption and the throughput of the facility. We will 
   train the model by having it try different commands and using a feedback function that rewards commands that 
   increase to throughput and decrease to energy consumption. 

The first example is a supervised learning because we have data that contain labels (the average daily 
temperatures). The second example is unsupervised, because we want to train the model on images without 
labels. The third example is reinforcement learning because we are using a "rewards" function. 

These examples suggest some important terminology: 

* *Sample* or *observation* --- a single data point in the dataset. For example, a row in the historical weather data that 
  contains the date and the average temperature, or a single crop image. 
* *Independent variables* or *features* --- These are values used to make a prediction. In the case of historical
  weather data, these are the calendar dates. In the case of crops, these are the images (pixel values).
* *Dependent variables* or *target* or *label* --- These are the values we want the model to predict. Again, in 
  the case of historical weather, these are the average daily temperatures. In the crops cases, these are the 
  labels "healthy" and "unhealthy". 

With this terminology, we can define the following basic mathematical notation: 

* :math:`x_i` --- features or independent variables  
* :math:`y_i` --- target or dependent variables 
* :math:`f(x)` --- the model, to be learned during training 
* :math:`y_i = f(x_i)` --- prediction at the value :math:`x_i` using the model 


.. note:: 

    This terminology is most natural in the supervised and unsupervised setting. Reinforcement learning has 
    analogous concepts but some adjustments are needed. Since we won't be focusing on RL this semester, we 
    will not say more about it at this time. 


Continuing with the first set of examples above, we can identify the independent and dependent variables as 
follows:

1. Given a string of text, predict the next word. 

   *The text string is the independent variable and the next word is the dependent variable.*
2. Given an image, determine if it contains a human face. 

   *The image is the independent variable and whether it contains a face is the dependent variable.*
3. Given an image of a home or building from the aftermath of a storm, classify the damage done 
   to the structure as "none", "small", or "large".

   *The image is the independent variable and the dame label ("none", "small", or "large") is the dependent variable.*

As an exercise, think through the remaining three examples. 

.. 
    4. Given a text description of an image, generate an image that "matches" the description. 

  *The text description is the independent variable and the image is the dependent variable.*
    5. Given details about a real estate property, such as address, square footage, number of rooms, 
    etc., predict its market value. 

    *The property details (address, square footage, etc.) are the independent variables and the market value is the dependent variable.*
    6. Given an image of a crop, determine if the crop has a disease; similarly, determine if the crop
    requires irrigation. 

Regression and Classification 
-----------------------------
Now that we understand independent and dependent variables, we can define classification and 
regression models. *Classification models* involve dependent variables that take a finite set of 
values. We call such dependent variables *categorical* or *discrete*, just like with the categorical 
variables we saw in the modules on pandas.

A particular case worth noting is the so-called *boolean classifiers*, which try to
predict dependent variables that contain just two possible values. The name comes from the 
fact that the dependent variable can be modeled with a Boolean data type.

Example 2) above is an example of a boolean classifier. The dependent variable --- whether the image
contains a face --- can be represented by a boolean variable (True or False). 

Similarly, example 3) is a classifier with 3 possible values ("none", "small", or "large").

By contrast, a *regression model* predicts a dependent variable that take infinitely many 
values. Example 5) provides an example of a regression model --- the market values for real estate
properties are dollar amounts that are unbounded (in practice, they are bounded by very large 
values but it can simplify our thinking to consider them unbounded).


Model Parameters and Training: Finding Parameter Values that Reduce Loss
-------------------------------------------------------------------------

Parameters and Loss 
^^^^^^^^^^^^^^^^^^^^
How do we go about finding a model to predict the dependent variables from the independent variables?
The idea with supervised learning is to use a *parameterized function*, that is, a function whose 
formula is defined by *parameters*, and to look for values of the parameters that cause the function to 
make good predictions on the labeled data. 

For example, we could use a linear function with the form: 

.. math:: 

    f(X) = mX + b 

where the :math:`m` and :math:`b` are the parameters of the function and :math:`X` is the independent variable. 
Then we want to choose values for :math:`m` and :math:`b` such that the *loss* or error associated with 
using :math:`f` to predict values of the dependent variable is minimized. 

We can defined the loss in different ways. For example, the mean squared error (MSE) is defined using 

.. math:: 

    MSE = \frac{1}{|D|} \sum_{d\in D} (y_d - f(d))^2

where :math:`D` is the dataset, :math:`d\in D` represents the feature associated with an observation, 
and :math:`y_d` is the actual target associated with the observation. Observe that MSE:

* is always positive, and  
* computes an average of all per-element losses associated with the function. 

*Discussion*: What would happen if we removed the square from the formula above? What about the 
:math:`\frac{1}{D}` term? 

The discussion above makes sense for regression problems where the target is a continuous variable. 
But what about when the target is a categorical (i.e., we have a classification problem)? 
We need a way to "predict" a class label, like "healthy" or "unhealthy", based on the output 
of a function. 

The idea is to use a *decision threshold* to decide a class label from a continuous variable. Conceptually, 
we can think of the function as outputing a probability that the input is in some class. The decision 
threshold is the minimum (predicted) probability that causes the input to be labeled in the class. 
For example, if the decision threshold is 0.8 for deciding a crop is unhealthy, and the model predicts  
a probability of 0.7 that a given crop input is unhealthy, then the input would be labeled healthy since 
it was below the decision threshold. 

Training 
^^^^^^^^
When we say we want to *train the model* (or, in older parlance, *fit the model*), what we mean is 
we want to use an optimization algorithm to find the values of the parameters that minimize the loss. 
The general strategy goes like this: 

.. code-block:: python 

    f = initialize_parameters()    # can use random values, for example 
    repeat:
        predictions = compute_predictions()  # evaluate function on independent variable
        loss = compute_loss()                # compare predictions to actual values
        f = update_parameters()              # update parameters to reduce the loss 
    until loss << 0

An entire semester could be spent on the theoretical underpinnings and numerical methods for implementing 
optimization algorithms just for artificial neural networks. As engineering students, you have likely covered 
some basic algorithms like gradient descent. We're not going to have time to cover that material, but if 
you are interested, I highly recommend COE 311K which treats numerical methods (and is also sometimes taught by a 
fellow TACC-ster :). 

Inference 
^^^^^^^^^
Once a model has been trained, it can be used to predict the targets associated with new data. This is called 
*inference* and it ultimately amounts to evaluating the learned function, :math:`f(X)`, on additional 
input values. Typically, training a model is more computationally expensive than using it for inference, although 
there are some exceptions (e.g., the K-nearest neighbors algorithm).

Hands-on Lab 
------------

We'll reinforce the ideas above with some hands-on demonstrations. We'll use standard Python data science 
libraries like ``pandas`` and ``numpy`` to work with a small CSV synthetic dataset. 

The dataset describes manufactured materials ("polymers") from a fictional industrial engineering lab. 
Each observation (row) corresponds to a single specimen that was produced using their machine. Three different
grades of materials (corresponding to three different polymer formulas) can be produced. 
As the specimens are being produced, sensors in the lab record the average temperature, pressure and "feed rate", 
that is, the rate that the raw material is fed into the machine. After the specimens are produced, 
<<<<<<< HEAD
they go through a testing and quality assurance process where first their tensile strength is measured 
=======
they go through a testing anf quality assurance process where first their tensile strength is measured 
>>>>>>> dev
and finally, the QA test determines if the specimen is defective. 


Step 1: Read data into python
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We'll use the ``pandas`` library to read the raw CSV file into a dataframe object. A dataframe is a 
like a 2d-array that can hold heterogeneous data. Each data frame contains rows and columns, like a 
spreadsheet or database table. 

<<<<<<< HEAD

.. code-block:: python 

    import pandas as pd

    # create a dataframe directly from the raw csv
    url = "https://raw.githubusercontent.com/joestubbs/coe-379l-fa26/refs/heads/main/data/unit01/polymer_samples.csv"
    df = pd.read_csv(url)

    type(df)
    --> pandas.DataFrame



=======
>>>>>>> dev
Step 2: Inspect the dataframe 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The dataframe API has a variety of useful methods for accessing and manipulating the data it contains. 
We'll use the ``info()`` to get a high-level description of the dataframe, and the ``head()`` method 
to inspect the first several rows. 

.. code-block:: python 

<<<<<<< HEAD
    df.info()


Output: 

.. code-block:: console 

    <class 'pandas.DataFrame'>
    RangeIndex: 30 entries, 0 to 29
    Data columns (total 7 columns):
    #   Column                Non-Null Count  Dtype  
    ---  ------                --------------  -----  
    0   sample_id             30 non-null     str    
    1   material_grade        30 non-null     str    
    2   temperature_c         30 non-null     int64  
    3   pressure_mpa          30 non-null     float64
    4   feed_rate_mm_s        30 non-null     int64  
    5   tensile_strength_mpa  30 non-null     float64
    6   defective             30 non-null     bool   
    dtypes: bool(1), float64(2), int64(2), str(2)
    memory usage: 1.6 KB


.. code-block:: python 

    df.head() 

Output: 

.. code-block:: console 


	    sample_id 	material_grade 	temperature_c 	pressure_mpa 	feed_rate_mm_s 	tensile_strength_mpa 	defective
        0 	S001 	Polymer A 	    185 	    2.55 	        21      	32.2 	            True
        1 	S002 	Polymer A 	    192 	    2.75 	        19 	        36.9 	            False
        2 	S003 	Polymer A 	    198 	    2.90 	        17 	        43.4 	            False
        3 	S004 	Polymer A 	    203 	    3.05 	        15 	        45.5 	            False
        4 	S005 	Polymer A 	    208 	    3.20 	        20 	        47.6 	            False
=======
    import pandas as pd

    # create a dataframe directly from the raw csv
    df = pd.read_csv(:"")

>>>>>>> dev


Step 3: Identifying independent and dependent variables 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
The grade of polymer being manufactured is an input to the process. 
<<<<<<< HEAD
The measured variables include the temperature, pressure and tensile strength. 
Finally, the QA test determines whether the sample is defective. 

Which variables are independent and which are dependent? A key point is that these 
are not inherent properties of the data themselves, but rather, it is a question 
about how you are modeling the data to answer a specific question. What are we 
trying to predict and what variables are we using to predict it? 

Can you describe a scenario where tensile strength is an independent variable? 
How about one where it is a dependent variable? 


Step 4: A first model and associated loss
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Let's implement a simple linear parameterized model in Python. For simplicity, 
we'll assume we are trying to predict tactile strength just using temperature, 
pressure and feed rate. The material grade would likely be very useful in the 
prediction, but this simplification allows us to avoid categorical independent
variables for the time being. 
=======
The measured variables include the temperature, pressure and tactile strength. 
Finally, the 

.. code-block:: python 

Step 4: A first (toy) model and associated costs
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
>>>>>>> dev


.. code-block:: python 

<<<<<<< HEAD
    X = [df["temperature_c"], df["pressure_mpa"], df["feed_rate_mm_s"],]
    parameters = [0.12, 3.5, -0.4, 12.0]

    def compute_prediction(parameters: list[float], X: list[float]) -> list[float]:
        prediction = parameters[0]*X[0] + parameters[1]*X[1] + parameters[2]*X[2] + parameters[3]
        return prediction    
    
    def compute_error(Y: list[float], prediction: list[float]): 
        error = (Y - prediction) ** 2 
        return error 

    prediction = compute_prediction(parameters, X)
    error = compute_error(Y, prediction)

    print("First Prediction: ", prediction[0])
    print("First Error: ", squared_error[0])
=======

Step 5: A 
>>>>>>> dev

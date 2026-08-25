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

We can categorize the primary paradigms that have historically been used in ML into three classes based 
on the type of feedback signal used to train the model:

1. *Supervised learning* ---  The dataset is labeled with “correct” values prior to doing the learning.
2. *Unsupervised learning* --– The dataset used for training does not contain no correct labels; 
   the learning algorithm must infer patterns 
3. *Reinforcement learning* --– The model "learns" through trial and error to optimize a “rewards” function.



